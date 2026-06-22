import SwiftUI
import SwiftData

struct ManualTaskFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.sortOrder) private var subjects: [Subject]

    let defaultDueDate: Date

    @State private var selectedSubject: Subject?
    @State private var content = ""
    @State private var notes = ""
    @State private var dueDate: Date
    @State private var errorMessage: String?

    init(defaultDueDate: Date) {
        self.defaultDueDate = defaultDueDate
        _dueDate = State(initialValue: defaultDueDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("科目", selection: $selectedSubject) {
                    Text("请选择").tag(Optional<Subject>.none)
                    ForEach(subjects) { subject in
                        Text("\(subject.emoji) \(subject.name)")
                            .tag(Optional(subject))
                            .accessibilityIdentifier("subject-option-\(subject.name)")
                    }
                }

                TextField("作业内容", text: $content)
                    .accessibilityIdentifier("task-content-field")

                DatePicker(
                    "截止日期",
                    selection: $dueDate,
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "zh_CN"))

                TextField("备注（选填）", text: $notes)
            }
            .navigationTitle("添加作业")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .accessibilityIdentifier("task-create-save")
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
            .onAppear {
                if selectedSubject == nil {
                    selectedSubject = subjects.first
                }
            }
        }
    }

    private func save() {
        guard let dependencies else { return }
        do {
            _ = try dependencies.taskRepository.create(
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
    ManualTaskFormView(defaultDueDate: Date())
}
