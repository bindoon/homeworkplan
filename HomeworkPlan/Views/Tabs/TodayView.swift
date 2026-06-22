import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.appDependencies) private var dependencies
    @Query(sort: \Subject.sortOrder) private var subjects: [Subject]

    @State private var selectedDate = Date()
    @State private var showAddTask = false
    @State private var selectedTask: HomeworkTask?
    @State private var tasks: [HomeworkTask] = []

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "选择日期",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .padding(.horizontal)
                .padding(.top, 8)
                .accessibilityIdentifier("today-date-picker")
                .onChange(of: selectedDate) { _, _ in reloadTasks() }

                if !calendar.isDateInToday(selectedDate) {
                    Text("正在查看 \(formattedDate(selectedDate))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                if groupedTasks.isEmpty {
                    Spacer()
                    ContentUnavailableView {
                        Label("今天还没有作业", systemImage: "book.closed")
                            .accessibilityIdentifier("today-empty-state")
                    } description: {
                        Text("点击右上角「添加作业」，手动录入第一条作业。")
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(groupedTasks, id: \.subject.id) { group in
                            Section(header: Text("\(group.subject.emoji) \(group.subject.name)")) {
                                ForEach(group.tasks) { task in
                                    TaskRowView(
                                        task: task,
                                        showCompletedStyle: false,
                                        onToggleComplete: { toggleComplete(task) },
                                        onTap: { selectedTask = task }
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteTask(task)
                                        } label: {
                                            Text("删除")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("今日")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加作业") {
                        showAddTask = true
                    }
                    .accessibilityIdentifier("today-add-button")
                }
            }
            .onAppear { reloadTasks() }
            .sheet(isPresented: $showAddTask) {
                ManualTaskFormView(defaultDueDate: selectedDate)
                    .onDisappear { reloadTasks() }
            }
            .sheet(item: $selectedTask) { task in
                TaskEditView(task: task)
                    .onDisappear { reloadTasks() }
            }
        }
    }

    private var groupedTasks: [(subject: Subject, tasks: [HomeworkTask])] {
        var groups: [UUID: (Subject, [HomeworkTask])] = [:]
        for task in tasks {
            guard let subject = task.subject else { continue }
            if var existing = groups[subject.id] {
                existing.1.append(task)
                groups[subject.id] = existing
            } else {
                groups[subject.id] = (subject, [task])
            }
        }
        return groups.values
            .sorted { $0.0.sortOrder < $1.0.sortOrder }
            .map { ($0.0, $0.1.sorted { $0.createdAt < $1.createdAt }) }
    }

    private func reloadTasks() {
        guard let dependencies else { return }
        do {
            tasks = try dependencies.taskRepository.fetchTasks(
                dueOn: selectedDate,
                includeCompleted: false
            )
        } catch {
            tasks = []
        }
    }

    private func toggleComplete(_ task: HomeworkTask) {
        guard let dependencies else { return }
        do {
            if task.isCompleted {
                try dependencies.taskRepository.markIncomplete(id: task.id)
            } else {
                try dependencies.taskRepository.markComplete(id: task.id)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            reloadTasks()
        } catch {
            print("Toggle failed: \(error)")
        }
    }

    private func deleteTask(_ task: HomeworkTask) {
        guard let dependencies else { return }
        do {
            try dependencies.taskRepository.delete(id: task.id)
            reloadTasks()
        } catch {
            print("Delete failed: \(error)")
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    TodayView()
}
