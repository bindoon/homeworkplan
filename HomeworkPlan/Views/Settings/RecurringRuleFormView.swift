import SwiftUI
import SwiftData

struct RecurringRuleFormView: View {
    enum Mode: Identifiable {
        case create
        case edit(RecurringRule)

        var id: String {
            switch self {
            case .create:
                return "create"
            case .edit(let rule):
                return rule.id.uuidString
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies
    @Query(sort: \Subject.sortOrder) private var subjects: [Subject]

    let mode: Mode

    @State private var selectedSubject: Subject?
    @State private var content = ""
    @State private var frequency: RecurringFrequency = .daily
    @State private var weeklyWeekday = 2
    @State private var customWeekdaysMask = 0
    @State private var reminderTime = Calendar.current.date(
        bySettingHour: 18,
        minute: 0,
        second: 0,
        of: Date()
    ) ?? Date()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    Picker("科目", selection: $selectedSubject) {
                        Text("无").tag(Optional<Subject>.none)
                        ForEach(subjects) { subject in
                            Text("\(subject.emoji) \(subject.name)").tag(Optional(subject))
                        }
                    }

                    TextField("作业内容", text: $content, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("重复频率") {
                    Picker("频率", selection: $frequency) {
                        ForEach(RecurringFrequency.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    if frequency == .weekly {
                        Picker("每周", selection: $weeklyWeekday) {
                            ForEach(1...7, id: \.self) { weekday in
                                Text(RecurringRule.weekdayDisplayName(weekday)).tag(weekday)
                            }
                        }
                    }

                    if frequency == .custom {
                        customWeekdayPicker
                    }
                }

                Section("提醒时间") {
                    DatePicker(
                        "提醒时间",
                        selection: $reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    Text("重复作业将在每天的此时间发送本地通知")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
            .onAppear(perform: loadExistingValues)
        }
    }

    private var customWeekdayPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择重复日期")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(1...7, id: \.self) { weekday in
                Toggle(
                    RecurringRule.weekdayDisplayName(weekday),
                    isOn: Binding(
                        get: { (customWeekdaysMask & (1 << weekday)) != 0 },
                        set: { selected in
                            if selected {
                                customWeekdaysMask |= (1 << weekday)
                            } else {
                                customWeekdaysMask &= ~(1 << weekday)
                            }
                        }
                    )
                )
            }
        }
    }

    private var modeTitle: String {
        switch mode {
        case .create:
            return "添加重复任务"
        case .edit:
            return "编辑重复任务"
        }
    }

    private func loadExistingValues() {
        switch mode {
        case .create:
            selectedSubject = subjects.first
            if frequency == .custom, customWeekdaysMask == 0 {
                customWeekdaysMask = (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5) | (1 << 6)
            }
        case .edit(let rule):
            selectedSubject = rule.subject
            content = rule.content
            frequency = rule.frequency
            weeklyWeekday = rule.weeklyWeekday
            customWeekdaysMask = rule.customWeekdaysMask
            reminderTime = rule.reminderTime
        }
    }

    private func save() {
        guard let dependencies else { return }
        do {
            switch mode {
            case .create:
                _ = try dependencies.recurringRuleRepository.create(
                    subject: selectedSubject,
                    content: content,
                    frequency: frequency,
                    weeklyWeekday: weeklyWeekday,
                    customWeekdaysMask: customWeekdaysMask,
                    reminderTime: reminderTime
                )
                try dependencies.recurringTaskGenerator.generateIfNeeded()
            case .edit(let rule):
                try dependencies.recurringRuleRepository.update(
                    id: rule.id,
                    subject: selectedSubject,
                    content: content,
                    frequency: frequency,
                    weeklyWeekday: weeklyWeekday,
                    customWeekdaysMask: customWeekdaysMask,
                    reminderTime: reminderTime
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    RecurringRuleFormView(mode: .create)
}
