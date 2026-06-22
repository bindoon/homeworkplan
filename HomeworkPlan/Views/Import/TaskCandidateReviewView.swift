import SwiftUI
import SwiftData

struct TaskCandidateReviewView: View {
    let result: ImportResult
    let dependencies: AppDependencies
    var onFinish: () -> Void

    @Query(sort: \Subject.sortOrder) private var subjects: [Subject]

    @State private var viewModel: ImportReviewViewModel?
    @State private var editingCandidate: ReviewableCandidate?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let viewModel {
                reviewContent(viewModel)
            } else {
                ProgressView()
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let viewModel, !viewModel.pendingCandidates.isEmpty {
                batchActionBar(viewModel)
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

    @ViewBuilder
    private func reviewContent(_ viewModel: ImportReviewViewModel) -> some View {
        if viewModel.candidates.isEmpty {
            List {
                if !viewModel.sourceImagePath.isEmpty {
                    TaskSourceImageView(relativePath: viewModel.sourceImagePath)
                }

                Section {
                    ContentUnavailableView {
                        Label("未识别到作业内容", systemImage: "text.magnifyingglass")
                    } description: {
                        Text(viewModel.statusMessage ?? "可查看原文手动录入。")
                    }
                    .frame(maxWidth: .infinity)
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

                Section {
                    Button("关闭") {
                        onFinish()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("review-close-button")
                }
            }
            .listStyle(.insetGrouped)
        } else {
            List {
                if !viewModel.sourceImagePath.isEmpty {
                    TaskSourceImageView(relativePath: viewModel.sourceImagePath)
                }

                if viewModel.pendingCandidates.isEmpty {
                    Section {
                        Label("已全部处理", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                ForEach(viewModel.candidates) { item in
                    candidateRow(item, viewModel: viewModel)
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func batchActionBar(_ viewModel: ImportReviewViewModel) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button("全部丢弃", role: .destructive) {
                    viewModel.discardAll()
                    onFinish()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("review-discard-all-button")

                Button("全部确认（\(viewModel.pendingCandidates.count)）") {
                    confirmAllAndFinish()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("review-confirm-all-button")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
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
                        finishIfAllProcessed(viewModel)
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
        guard let viewModel else { return }
        do {
            try viewModel.confirm(id)
            finishIfAllProcessed(viewModel)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmAllAndFinish() {
        guard let viewModel else { return }
        do {
            try viewModel.confirmAll()
            onFinish()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishIfAllProcessed(_ viewModel: ImportReviewViewModel) {
        if viewModel.pendingCandidates.isEmpty {
            onFinish()
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

                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 160)
                } header: {
                    Text("作业内容")
                }

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
