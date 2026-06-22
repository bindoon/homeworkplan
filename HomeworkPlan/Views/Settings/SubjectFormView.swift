import SwiftUI

struct SubjectFormView: View {
    enum Mode: Identifiable {
        case create
        case edit(Subject)

        var id: String {
            switch self {
            case .create:
                return "create"
            case .edit(let subject):
                return subject.id.uuidString
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies

    let mode: Mode

    @State private var name = ""
    @State private var emoji = "📚"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("科目名称", text: $name)
                TextField("图标 emoji", text: $emoji)
            }
            .navigationTitle(modeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .alert("保存失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                if case .edit(let subject) = mode {
                    name = subject.name
                    emoji = subject.emoji
                }
            }
        }
    }

    private var modeTitle: String {
        switch mode {
        case .create:
            return "添加科目"
        case .edit:
            return "编辑科目"
        }
    }

    private func save() {
        guard let dependencies else { return }
        do {
            switch mode {
            case .create:
                _ = try dependencies.subjectRepository.create(name: name, emoji: emoji)
            case .edit(let subject):
                try dependencies.subjectRepository.update(id: subject.id, name: name, emoji: emoji)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SubjectFormView(mode: .create)
}
