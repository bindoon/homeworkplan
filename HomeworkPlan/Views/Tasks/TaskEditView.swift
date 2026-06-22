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
                Picker("科目", selection: $selectedSubject) {
                    ForEach(subjects) { subject in
                        Text("\(subject.emoji) \(subject.name)")
                            .tag(Optional(subject))
                    }
                }

                TextField("作业内容", text: $content)

                DatePicker(
                    "截止日期",
                    selection: $dueDate,
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "zh_CN"))

                TextField("备注（选填）", text: $notes)
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
                Text(errorMessage ?? "请检查存储空间或 iCloud 连接后重试。")
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
