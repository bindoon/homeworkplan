import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct HomeQueryView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = HomeQueryViewModel()
    @State private var showAddTask = false
    @State private var showImport = false
    @State private var showPasteFromClipboard = false
    @State private var clipboardPrefill = ""
    @State private var showClipboardBanner = false
    @State private var selectedTask: HomeworkTask?

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showClipboardBanner {
                    ClipboardHintBanner(
                        onImport: {
                            showClipboardBanner = false
                            #if canImport(UIKit)
                            clipboardPrefill = UIPasteboard.general.string ?? ""
                            #endif
                            showPasteFromClipboard = true
                        },
                        onDismiss: {
                            showClipboardBanner = false
                        }
                    )
                }

                List {
                    Section {
                        DatePicker(
                            "选择日期",
                            selection: Binding(
                                get: { viewModel.selectedDate },
                                set: { newDate in
                                    guard let dependencies else { return }
                                    viewModel.setSelectedDate(newDate, using: dependencies.taskRepository)
                                }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .accessibilityIdentifier("home-date-picker")

                        if !calendar.isDateInToday(viewModel.selectedDate) {
                            Text("正在查看 \(formattedDate(viewModel.selectedDate))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if viewModel.subjectGroups.isEmpty && viewModel.historySections.isEmpty {
                        Section {
                            ContentUnavailableView {
                                Label("还没有作业", systemImage: "book.closed")
                                    .accessibilityIdentifier("home-empty-state")
                            } description: {
                                Text("点击右上角「添加作业」，或切换到「操作」Tab 用自然语言录入。")
                            }
                        }
                    } else {
                        if !viewModel.subjectGroups.isEmpty {
                            Section(header: Text(selectedDayHeader)) {
                                ForEach(viewModel.subjectGroups) { group in
                                    DisclosureGroup(
                                        isExpanded: Binding(
                                            get: { viewModel.isSubjectExpanded(group.id) },
                                            set: { _ in viewModel.toggleSubject(group.id) }
                                        )
                                    ) {
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
                                    } label: {
                                        Text("\(group.subject.emoji) \(group.subject.name)")
                                            .font(.headline)
                                    }
                                }
                            }
                        } else {
                            Section(header: Text(selectedDayHeader)) {
                                Text("该日期暂无未完成作业")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !viewModel.historySections.isEmpty {
                            Section(header: Text("其他日期")) {
                                ForEach(viewModel.historySections) { section in
                                    DisclosureGroup(
                                        isExpanded: Binding(
                                            get: { viewModel.isHistoryExpanded(section.id) },
                                            set: { _ in viewModel.toggleHistorySection(section.id) }
                                        )
                                    ) {
                                        ForEach(section.tasks) { task in
                                            TaskRowView(
                                                task: task,
                                                showCompletedStyle: task.isCompleted,
                                                onToggleComplete: { toggleComplete(task) },
                                                onTap: { selectedTask = task }
                                            )
                                        }
                                    } label: {
                                        HStack {
                                            Text(section.title)
                                            Spacer()
                                            Text("\(section.tasks.count) 项")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("首页")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("导入") {
                        showImport = true
                    }
                    .accessibilityIdentifier("home-import-button")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加作业") {
                        showAddTask = true
                    }
                    .accessibilityIdentifier("home-add-button")
                }
            }
            .onAppear {
                reload()
                checkClipboardHint()
            }
            .refreshable { reload() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    checkClipboardHint()
                }
            }
            .sheet(isPresented: $showAddTask) {
                ManualTaskFormView(defaultDueDate: viewModel.selectedDate)
                    .onDisappear { reload() }
            }
            .sheet(isPresented: $showImport) {
                ImportSourceSheet()
                    .onDisappear { reload() }
            }
            .sheet(isPresented: $showPasteFromClipboard) {
                NavigationStack {
                    PasteImportView(
                        initialText: clipboardPrefill,
                        onImportComplete: { showPasteFromClipboard = false }
                    )
                }
                .onDisappear {
                    clipboardPrefill = ""
                    reload()
                }
            }
            .sheet(item: $selectedTask) { task in
                TaskEditView(task: task)
                    .onDisappear { reload() }
            }
        }
    }

    private var selectedDayHeader: String {
        if calendar.isDateInToday(viewModel.selectedDate) {
            return "今日作业"
        }
        return formattedDate(viewModel.selectedDate)
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
                #if canImport(UIKit)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
            }
            reload()
        } catch {
            print("Toggle failed: \(error)")
        }
    }

    private func deleteTask(_ task: HomeworkTask) {
        guard let dependencies else { return }
        do {
            try dependencies.taskRepository.delete(id: task.id)
            reload()
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

    private func checkClipboardHint() {
        #if canImport(UIKit)
        showClipboardBanner = UIPasteboard.general.hasStrings
        #endif
    }
}

#Preview {
    HomeQueryView()
}
