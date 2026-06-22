import SwiftUI
import SwiftData

struct TaskCandidateReviewView: View {
    let result: ImportResult
    let dependencies: AppDependencies
    var onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.sortOrder) private var subjects: [Subject]

    @State private var viewModel: ImportReviewViewModel?
    @State private var editingCandidate: ReviewableCandidate?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    reviewContent(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("确认作业")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        onFinish()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("全部丢弃") {
                        viewModel?.discardAll()
                    }
                    .foregroundStyle(.red)
                    Button("全部确认") {
                        confirmAll()
                    }
                    .disabled(viewModel?.pendingCandidates.isEmpty ?? true)
                }
            }
            .onAppear {
                if viewModel == nil {
                    let vm = ImportReviewViewModel(
                        taskRepository: dependencies.taskRepository,
                        importRepository: dependencies.importRepository,
                        subjectRepository: dependencies.subjectRepository
                    )
                    vm.load(from: result, subjects: subjects)
                    viewModel = vm
                }
            }
            .sheet(item: $editingCandidate) { item in
                CandidateEditSheet(
                    candidate: item,
                    subjects: subjects,
                    onSave: { subject, content, notes, dueDate in
                        viewModel?.updateCandidate(
                            id: item.id,
                            subject: subject,
                            content: content,
                            notes: notes,
                            dueDate: dueDate
                        )
                    }
                )
            }
            .alert("操作失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func reviewContent(_ viewModel: ImportReviewViewModel) -> some View {
        if viewModel.candidates.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ContentUnavailableView {
                        Label("未识别到作业内容", systemImage: "text.magnifyingglass")
                    } description: {
                        Text(viewModel.statusMessage ?? "可查看原文手动录入。")
                    }

                    if viewModel.parseFailed {
                        Section {
                            Text(viewModel.rawText)
                                .font(.body)
                                .textSelection(.enabled)
                        } header: {
                            Text("识别原文")
                        }
                    }
                }
                .padding()
            }
        } else {
            List {
                ForEach(viewModel.candidates) { item in
                    candidateRow(item, viewModel: viewModel)
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private func candidateRow(_ item: ReviewableCandidate, viewModel: ImportReviewViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let subject = item.selectedSubject {
                    Text("\(subject.emoji) \(subject.name)")
                        .font(.subheadline.weight(.medium))
                } else {
                    Text(item.candidate.subjectName)
                        .font(.subheadline.weight(.medium))
                }
                Spacer()
                Text(String(format: "%.0f%%", item.candidate.confidence * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                statusBadge(item.status)
            }

            Text(item.editedContent)
                .font(.body)

            Text("截止：\(formattedDate(item.editedDueDate))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if item.status == .pending {
                HStack {
                    Button("确认") {
                        confirmOne(item.id)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("编辑") {
                        editingCandidate = item
                    }
                    .buttonStyle(.bordered)

                    Button("丢弃", role: .destructive) {
                        viewModel.discard(item.id)
                    }
                    .buttonStyle(.bordered)
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .opacity(item.status == .discarded ? 0.5 : 1)
    }

    @ViewBuilder
    private func statusBadge(_ status: ReviewCandidateStatus) -> some View {
        switch status {
        case .pending:
            EmptyView()
        case .confirmed:
            Label("已确认", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .discarded:
            Label("已丢弃", systemImage: "xmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func confirmOne(_ id: UUID) {
        do {
            try viewModel?.confirm(id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmAll() {
        do {
            try viewModel?.confirmAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct CandidateEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let candidate: ReviewableCandidate
    let subjects: [Subject]
    var onSave: (Subject?, String, String, Date) -> Void

    @State private var selectedSubject: Subject?
    @State private var content: String
    @State private var notes: String
    @State private var dueDate: Date

    init(
        candidate: ReviewableCandidate,
        subjects: [Subject],
        onSave: @escaping (Subject?, String, String, Date) -> Void
    ) {
        self.candidate = candidate
        self.subjects = subjects
        self.onSave = onSave
        _selectedSubject = State(initialValue: candidate.selectedSubject)
        _content = State(initialValue: candidate.editedContent)
        _notes = State(initialValue: candidate.editedNotes)
        _dueDate = State(initialValue: candidate.editedDueDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("科目", selection: $selectedSubject) {
                    Text("请选择").tag(Optional<Subject>.none)
                    ForEach(subjects) { subject in
                        Text("\(subject.emoji) \(subject.name)")
                            .tag(Optional(subject))
                    }
                }

                TextField("作业内容", text: $content, axis: .vertical)
                    .lineLimit(3 ... 6)

                DatePicker(
                    "截止日期",
                    selection: $dueDate,
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "zh_CN"))

                TextField("备注", text: $notes)
            }
            .navigationTitle("编辑作业")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(selectedSubject, content, notes, dueDate)
                        dismiss()
                    }
                }
            }
        }
    }
}

extension ReviewableCandidate: Hashable {
    static func == (lhs: ReviewableCandidate, rhs: ReviewableCandidate) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
