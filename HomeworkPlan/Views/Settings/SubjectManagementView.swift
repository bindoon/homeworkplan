import SwiftUI
import SwiftData

struct SubjectManagementView: View {
    @Environment(\.appDependencies) private var dependencies
    @Query(sort: \Subject.sortOrder) private var subjects: [Subject]

    @State private var showAddForm = false
    @State private var editingSubject: Subject?

    var body: some View {
        List {
            ForEach(subjects) { subject in
                Button {
                    if !subject.isDefault {
                        editingSubject = subject
                    }
                } label: {
                    HStack {
                        Text("\(subject.emoji) \(subject.name)")
                        Spacer()
                        if subject.isDefault {
                            Text("默认")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
                .foregroundStyle(.primary)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !subject.isDefault {
                        Button(role: .destructive) {
                            deleteSubject(subject)
                        } label: {
                            Text("删除")
                        }
                    }
                }
            }
        }
        .navigationTitle("科目管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("添加科目") {
                    showAddForm = true
                }
            }
        }
        .sheet(isPresented: $showAddForm) {
            SubjectFormView(mode: .create)
        }
        .sheet(item: $editingSubject) { subject in
            SubjectFormView(mode: .edit(subject))
        }
    }

    private func deleteSubject(_ subject: Subject) {
        guard let dependencies else { return }
        do {
            try dependencies.subjectRepository.delete(id: subject.id)
        } catch {
            print("Delete subject failed: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        SubjectManagementView()
    }
}
