import SwiftUI
import SwiftData

struct TaskEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies
    @Query(sort: \Subject.sortOrder) private var subjects: [Subject]

    let task: HomeworkTask

    @State private var selectedSubject: Subject?
    @State private var content: String
    @State private var notes: String
    @State private var dueDate: Date
    @State private var errorMessage: String?
    @State private var expandedSourceImage: UIImage?

    init(task: HomeworkTask) {
        self.task = task
        _selectedSubject = State(initialValue: task.subject)
        _content = State(initialValue: task.content)
        _notes = State(initialValue: task.notes)
        _dueDate = State(initialValue: task.dueDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !task.sourceImagePath.isEmpty {
                    TaskSourceImageView(relativePath: task.sourceImagePath) { image in
                        expandedSourceImage = image
                    }
                }

                Picker("科目", selection: $selectedSubject) {
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

                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                } header: {
                    Text("备注（选填）")
                }
            }
            .navigationTitle("编辑作业")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .accessibilityIdentifier("task-edit-save")
                }
            }
            .alert("无法保存作业", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("重试", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "请检查存储空间后重试。")
            }
            .overlay {
                if let image = expandedSourceImage {
                    ImportImageFullScreenOverlay(image: image) {
                        expandedSourceImage = nil
                    }
                }
            }
        }
    }

    private func save() {
        guard let dependencies else { return }
        do {
            try dependencies.taskRepository.update(
                id: task.id,
                subject: selectedSubject,
                content: content,
                notes: notes,
                dueDate: dueDate
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    TaskEditView(task: HomeworkTask(subject: nil, content: "测试", dueDate: Date()))
}
