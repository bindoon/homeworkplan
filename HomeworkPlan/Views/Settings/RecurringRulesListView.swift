import SwiftUI
import SwiftData

struct RecurringRulesListView: View {
    @Environment(\.appDependencies) private var dependencies
    @Query(sort: \RecurringRule.createdAt, order: .reverse) private var rules: [RecurringRule]

    @State private var showAddForm = false
    @State private var showCalendarImport = false
    @State private var editingRule: RecurringRule?

    private var activeRules: [RecurringRule] {
        rules.filter(\.isEnabled)
    }

    private var pausedRules: [RecurringRule] {
        rules.filter { !$0.isEnabled }
    }

    var body: some View {
        List {
            if !activeRules.isEmpty {
                Section("活跃") {
                    ForEach(activeRules) { rule in
                        ruleRow(rule)
                    }
                }
            }

            if !pausedRules.isEmpty {
                Section("已暂停") {
                    ForEach(pausedRules) { rule in
                        ruleRow(rule)
                    }
                }
            }

            if rules.isEmpty {
                ContentUnavailableView(
                    "暂无重复任务",
                    systemImage: "repeat",
                    description: Text("添加固定作业规则，App 将自动生成每日任务")
                )
            }
        }
        .navigationTitle("重复任务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddForm = true
                    } label: {
                        Label("手动添加", systemImage: "plus")
                    }

                    Button {
                        showCalendarImport = true
                    } label: {
                        Label("从钉钉日历导入", systemImage: "calendar.badge.plus")
                    }
                } label: {
                    Label("添加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddForm) {
            RecurringRuleFormView(mode: .create)
        }
        .sheet(isPresented: $showCalendarImport) {
            NavigationStack {
                DingTalkCalendarImportView()
            }
        }
        .sheet(item: $editingRule) { rule in
            RecurringRuleFormView(mode: .edit(rule))
        }
    }

    @ViewBuilder
    private func ruleRow(_ rule: RecurringRule) -> some View {
        Button {
            editingRule = rule
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let subject = rule.subject {
                        Text("\(subject.emoji) \(subject.name)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !rule.isEnabled {
                        Text("已暂停")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Text(rule.content)
                    .font(.body)
                Text(frequencyLabel(for: rule))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
        .foregroundStyle(.primary)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteRule(rule)
            } label: {
                Text("删除")
            }

            if rule.isEnabled {
                Button {
                    pauseRule(rule)
                } label: {
                    Text("暂停")
                }
                .tint(.orange)
            } else {
                Button {
                    resumeRule(rule)
                } label: {
                    Text("恢复")
                }
                .tint(.green)
            }
        }
    }

    private func frequencyLabel(for rule: RecurringRule) -> String {
        RecurringRule.frequencySummary(
            frequency: rule.frequency,
            weeklyWeekday: rule.weeklyWeekday,
            customWeekdaysMask: rule.customWeekdaysMask
        )
    }

    private func pauseRule(_ rule: RecurringRule) {
        guard let dependencies else { return }
        do {
            try dependencies.recurringRuleRepository.setEnabled(id: rule.id, enabled: false)
        } catch {
            print("Pause rule failed: \(error)")
        }
    }

    private func resumeRule(_ rule: RecurringRule) {
        guard let dependencies else { return }
        do {
            try dependencies.recurringRuleRepository.setEnabled(id: rule.id, enabled: true)
            try dependencies.recurringTaskGenerator.generateIfNeeded()
        } catch {
            print("Resume rule failed: \(error)")
        }
    }

    private func deleteRule(_ rule: RecurringRule) {
        guard let dependencies else { return }
        do {
            try dependencies.recurringRuleRepository.delete(id: rule.id)
        } catch {
            print("Delete rule failed: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        RecurringRulesListView()
    }
}
