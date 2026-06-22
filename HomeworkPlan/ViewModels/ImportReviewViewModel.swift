import Foundation
import SwiftData

enum ReviewCandidateStatus {
    case pending
    case confirmed
    case discarded
}

struct ReviewableCandidate: Identifiable {
    let id: UUID
    var candidate: TaskCandidate
    var status: ReviewCandidateStatus
    var selectedSubject: Subject?
    var editedContent: String
    var editedNotes: String
    var editedDueDate: Date
    var resolvedAction: ImportTaskAction
    var matchedTaskId: UUID?
    var matchedTaskPreview: String?

    init(
        candidate: TaskCandidate,
        defaultSubject: Subject?,
        dueDate: Date,
        resolvedAction: ImportTaskAction,
        matchedTaskId: UUID?,
        matchedTaskPreview: String?,
        status: ReviewCandidateStatus = .pending
    ) {
        self.id = candidate.id
        self.candidate = candidate
        self.status = status
        self.selectedSubject = defaultSubject
        self.editedContent = candidate.content
        self.editedNotes = candidate.notes ?? ""
        self.editedDueDate = dueDate
        self.resolvedAction = resolvedAction
        self.matchedTaskId = matchedTaskId
        self.matchedTaskPreview = matchedTaskPreview
    }
}

@MainActor
@Observable
final class ImportReviewViewModel {
    var candidates: [ReviewableCandidate] = []
    var rawText: String = ""
    var sourceType: ImportSourceType = .pasted
    var importRecordID: UUID?
    var parseFailed: Bool = false
    var statusMessage: String?
    var sourceImagePath: String = ""

    private let taskRepository: TaskRepository
    private let importRepository: ImportRepository
    private let subjectRepository: SubjectRepository

    init(
        taskRepository: TaskRepository,
        importRepository: ImportRepository,
        subjectRepository: SubjectRepository
    ) {
        self.taskRepository = taskRepository
        self.importRepository = importRepository
        self.subjectRepository = subjectRepository
    }

    func load(from result: ImportResult, subjects: [Subject]) {
        rawText = result.rawText
        sourceType = result.sourceType
        importRecordID = result.importRecord?.id
        parseFailed = result.parseFailed
        statusMessage = result.message
        sourceImagePath = result.sourceImagePath

        let referenceDate = result.importRecord?.createdAt ?? Date()
        candidates = result.candidates.map { candidate in
            buildReviewableCandidate(
                candidate: candidate,
                subjects: subjects,
                referenceDate: referenceDate
            )
        }
    }

    var pendingCandidates: [ReviewableCandidate] {
        candidates.filter { $0.status == .pending }
    }

    func confirm(_ id: UUID) throws {
        guard let index = candidates.firstIndex(where: { $0.id == id }) else { return }
        guard candidates[index].status == .pending else { return }

        let item = candidates[index]

        switch item.resolvedAction {
        case .skip:
            candidates[index].status = .discarded
            return
        case .update:
            if let taskId = item.matchedTaskId,
               try taskRepository.fetchTask(id: taskId) != nil {
                try taskRepository.update(
                    id: taskId,
                    subject: item.selectedSubject,
                    content: item.editedContent,
                    notes: item.editedNotes,
                    dueDate: item.editedDueDate
                )
                if let recordID = importRecordID {
                    try importRepository.linkTask(recordID: recordID, taskID: taskId)
                }
                candidates[index].status = .confirmed
                return
            }
        case .create:
            break
        }

        let sourceDetail = buildSourceDetail(for: item.candidate)
        let task = try taskRepository.create(
            subject: item.selectedSubject,
            content: item.editedContent,
            notes: item.editedNotes,
            dueDate: item.editedDueDate,
            sourceType: sourceType.rawValue,
            sourceDetail: sourceDetail,
            sourceImagePath: sourceImagePath
        )

        if let recordID = importRecordID {
            try importRepository.linkTask(recordID: recordID, taskID: task.id)
        }

        candidates[index].status = .confirmed
    }

    func discard(_ id: UUID) {
        guard let index = candidates.firstIndex(where: { $0.id == id }) else { return }
        candidates[index].status = .discarded
    }

    func confirmAll() throws {
        for item in pendingCandidates {
            try confirm(item.id)
        }
    }

    func discardAll() {
        for index in candidates.indices where candidates[index].status == .pending {
            candidates[index].status = .discarded
        }
    }

    func updateCandidate(
        id: UUID,
        subject: Subject?,
        content: String,
        notes: String,
        dueDate: Date
    ) {
        guard let index = candidates.firstIndex(where: { $0.id == id }) else { return }
        candidates[index].selectedSubject = subject
        candidates[index].editedContent = content
        candidates[index].editedNotes = notes
        candidates[index].editedDueDate = dueDate
    }

    private func buildReviewableCandidate(
        candidate: TaskCandidate,
        subjects: [Subject],
        referenceDate: Date
    ) -> ReviewableCandidate {
        let subject = resolveSubject(named: candidate.subjectName, in: subjects)
        let resolvedDue = DueDateResolver.resolve(for: candidate, importedAt: referenceDate)
        let resolution = resolveImportAction(for: candidate)

        return ReviewableCandidate(
            candidate: candidate,
            defaultSubject: subject,
            dueDate: resolvedDue,
            resolvedAction: resolution.action,
            matchedTaskId: resolution.matchedTaskId,
            matchedTaskPreview: resolution.matchedTaskPreview,
            status: resolution.action == .skip ? .discarded : .pending
        )
    }

    private func resolveImportAction(for candidate: TaskCandidate) -> (
        action: ImportTaskAction,
        matchedTaskId: UUID?,
        matchedTaskPreview: String?
    ) {
        switch candidate.action {
        case .skip:
            return (.skip, nil, nil)
        case .update:
            guard
                let matchedTaskId = candidate.matchedTaskId,
                let matchedTask = try? taskRepository.fetchTask(id: matchedTaskId)
            else {
                return (.create, nil, nil)
            }
            return (
                .update,
                matchedTaskId,
                previewText(for: matchedTask)
            )
        case .create:
            return (.create, nil, nil)
        }
    }

    private func previewText(for task: HomeworkTask) -> String {
        let subject = task.subject?.name ?? "其他"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(subject) · \(task.content) · 截止 \(formatter.string(from: task.dueDate))"
    }

    private func resolveSubject(named name: String, in subjects: [Subject]) -> Subject? {
        let normalized = Subject.normalizeName(name)
        if let exact = subjects.first(where: { $0.normalizedName == normalized }) {
            return exact
        }
        if normalized.contains("语") {
            return subjects.first { $0.name.contains("语") }
        }
        if normalized.contains("数") {
            return subjects.first { $0.name.contains("数") }
        }
        if normalized.contains("英") {
            return subjects.first { $0.name.contains("英") }
        }
        return subjects.first
    }

    private func buildSourceDetail(for candidate: TaskCandidate) -> String {
        var parts: [String] = []
        if let assigner = candidate.assigner, !assigner.isEmpty {
            parts.append("布置人:\(assigner)")
        }
        parts.append(String(format: "置信度:%.0f%%", candidate.confidence * 100))
        return parts.joined(separator: " · ")
    }
}
