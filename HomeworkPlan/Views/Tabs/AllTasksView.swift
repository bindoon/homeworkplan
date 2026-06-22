import SwiftUI

struct AllTasksView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var viewModel = AllTasksViewModel()
    @State private var selectedTask: HomeworkTask?
    @State private var showAddTask = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sections.isEmpty {
                    ContentUnavailableView {
                        Label("暂无作业记录", systemImage: "tray")
                    } description: {
                        Text("切换到其他日期查看，或添加新作业。")
                    }
                } else {
                    List {
                        ForEach(viewModel.sections) { section in
                            Section(header: Text(section.title)) {
                                ForEach(section.tasks) { task in
                                    TaskRowView(
                                        task: task,
                                        showCompletedStyle: task.isCompleted,
                                        onToggleComplete: { toggleComplete(task) },
                                        onTap: { selectedTask = task }
                                    )
                                }
                                .onDelete { offsets in
                                    deleteTasks(at: offsets, in: section)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("全部")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加作业") {
                        showAddTask = true
                    }
                }
            }
            .onAppear { reload() }
            .refreshable { reload() }
            .sheet(isPresented: $showAddTask) {
                ManualTaskFormView(defaultDueDate: Date())
            }
            .sheet(item: $selectedTask) { task in
                TaskEditView(task: task)
            }
        }
    }

    private func reload() {
        guard let dependencies else { return }
        viewModel.reload(using: dependencies.taskRepository)
    }

    private func toggleComplete(_ task: HomeworkTask) {
        guard let dependencies else { return }
        do {
            if task.isCompleted {
                try dependencies.taskRepository.markIncomplete(id: task.id)
            } else {
                try dependencies.taskRepository.markComplete(id: task.id)
            }
            reload()
        } catch {
            print("Toggle complete failed: \(error)")
        }
    }

    private func deleteTasks(at offsets: IndexSet, in section: AllTasksSection) {
        guard let dependencies else { return }
        for index in offsets {
            let task = section.tasks[index]
            do {
                try dependencies.taskRepository.delete(id: task.id)
            } catch {
                print("Delete failed: \(error)")
            }
        }
        reload()
    }
}

#Preview {
    AllTasksView()
}
