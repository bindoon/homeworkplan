import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DingTalkCalendarImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies
    @Query(sort: \RecurringRule.createdAt, order: .reverse) private var existingRules: [RecurringRule]
    @Query(sort: \Subject.sortOrder) private var subjects: [Subject]

    @State private var importService = DingTalkCalendarImportService()
    @State private var availableCalendars: [CalendarSelection] = []
    @State private var selectedCalendarIDs: Set<String> = []
    @State private var candidates: [ImportableRecurringCandidate] = []
    @State private var isLoading = false
    @State private var hasRequestedAccess = false
    @State private var accessGranted = false
    @State private var showFileImporter = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        List {
            setupSection

            if accessGranted {
                calendarSection
            }

            if !candidates.isEmpty {
                candidateSection
            }
        }
        .navigationTitle("从钉钉日历导入")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }

            if !candidates.isEmpty {
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") {
                        importSelectedCandidates()
                    }
                    .disabled(selectedImportableCandidates.isEmpty)
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView("正在读取日历…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "ics") ?? .data, .calendarEvent, .data],
            allowsMultipleSelection: false
        ) { result in
            handleICSImport(result)
        }
        .alert("导入失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("导入完成", isPresented: Binding(
            get: { successMessage != nil },
            set: { if !$0 { successMessage = nil } }
        )) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text(successMessage ?? "")
        }
        .task {
            await prepareCalendarAccess()
        }
    }

    private var setupSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("请先在钉钉中开启 CalDAV 同步，并在 iPhone「设置 → 日历 → 账户」中添加钉钉 CalDAV 账户。")
                Text("同步完成后，本页会读取系统日历中的重复日程，并转换为重复任务规则。")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !accessGranted {
                Button("授权访问日历") {
                    Task { await prepareCalendarAccess(forcePrompt: true) }
                }
            }

            Button("导入 ICS 日历文件") {
                showFileImporter = true
            }
        } header: {
            Text("准备工作")
        }
    }

    private var calendarSection: some View {
        Section {
            if availableCalendars.isEmpty {
                Text("未找到可用日历")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(availableCalendars) { calendar in
                    Toggle(isOn: calendarBinding(for: calendar)) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(calendar.title)
                                if calendar.isLikelyDingTalk {
                                    Text("钉钉")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15), in: Capsule())
                                }
                            }
                            Text(calendar.sourceTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button("读取所选日历") {
                    Task { await loadCandidatesFromSelectedCalendars() }
                }
                .disabled(selectedCalendarIDs.isEmpty || isLoading)
            }
        } header: {
            Text("选择日历")
        } footer: {
            Text("默认优先勾选名称包含「钉钉」的日历。")
        }
    }

    private var candidateSection: some View {
        Section {
            ForEach($candidates) { $candidate in
                Toggle(isOn: $candidate.isSelected) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate.title)
                            .font(.body)
                        Text("\(candidate.frequencySummary) · 提醒 \(formattedTime(candidate.reminderTime))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(candidate.calendarName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        if candidate.isDuplicate {
                            Label("已有相同规则", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .disabled(candidate.isDuplicate)
            }
        } header: {
            Text("可导入的重复日程")
        } footer: {
            Text("共 \(candidates.count) 项，已选 \(selectedImportableCandidates.count) 项。")
        }
    }

    private var selectedImportableCandidates: [ImportableRecurringCandidate] {
        candidates.filter { $0.isSelected && !$0.isDuplicate }
    }

    private func calendarBinding(for calendar: CalendarSelection) -> Binding<Bool> {
        Binding(
            get: { selectedCalendarIDs.contains(calendar.id) },
            set: { isSelected in
                if isSelected {
                    selectedCalendarIDs.insert(calendar.id)
                } else {
                    selectedCalendarIDs.remove(calendar.id)
                }
            }
        )
    }

    @MainActor
    private func prepareCalendarAccess(forcePrompt: Bool = false) async {
        if hasRequestedAccess, !forcePrompt, !accessGranted {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            accessGranted = try await importService.requestCalendarAccess()
            hasRequestedAccess = true

            if accessGranted {
                refreshAvailableCalendars()
            } else {
                errorMessage = DingTalkCalendarImportError.calendarAccessDenied.errorDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshAvailableCalendars() {
        let calendars = importService.fetchAvailableCalendars()
        let suggested = importService.suggestedCalendars(from: calendars)

        availableCalendars = calendars.map { calendar in
            CalendarSelection(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                sourceTitle: calendar.source.title,
                isLikelyDingTalk: DingTalkCalendarImportService.isLikelyDingTalkCalendar(calendar.title)
            )
        }

        selectedCalendarIDs = Set(suggested.map(\.calendarIdentifier))
    }

    @MainActor
    private func loadCandidatesFromSelectedCalendars() async {
        guard accessGranted else { return }

        isLoading = true
        defer { isLoading = false }

        let selectedCalendars = importService.fetchAvailableCalendars()
            .filter { selectedCalendarIDs.contains($0.calendarIdentifier) }

        do {
            let loaded = try importService.loadCandidates(
                from: selectedCalendars,
                existingRules: existingRules
            )
            candidates = loaded.map { ImportableRecurringCandidate(candidate: $0, isSelected: !$0.isDuplicate) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleICSImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await importICSFile(url) }
        }
    }

    @MainActor
    private func importICSFile(_ url: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let loaded = try importService.loadCandidates(
                fromICSData: data,
                existingRules: existingRules
            )
            candidates = loaded.map { ImportableRecurringCandidate(candidate: $0, isSelected: !$0.isDuplicate) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importSelectedCandidates() {
        guard let dependencies else { return }

        let selected = selectedImportableCandidates
        guard !selected.isEmpty else { return }

        var importedCount = 0

        do {
            for candidate in selected {
                let subject = DingTalkCalendarImportService.resolveSubject(
                    for: candidate.title,
                    in: subjects
                )

                _ = try dependencies.recurringRuleRepository.create(
                    subject: subject,
                    content: candidate.title,
                    frequency: candidate.schedule.frequency,
                    weeklyWeekday: candidate.schedule.weeklyWeekday,
                    customWeekdaysMask: candidate.schedule.customWeekdaysMask,
                    reminderTime: candidate.reminderTime
                )
                importedCount += 1
            }

            try dependencies.recurringTaskGenerator.generateIfNeeded()
            successMessage = "已成功导入 \(importedCount) 条重复任务规则"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct CalendarSelection: Identifiable {
    let id: String
    let title: String
    let sourceTitle: String
    let isLikelyDingTalk: Bool
}

private struct ImportableRecurringCandidate: Identifiable {
    let candidate: CalendarRecurringCandidate
    var isSelected: Bool

    var id: String { candidate.id }
    var title: String { candidate.title }
    var calendarName: String { candidate.calendarName }
    var frequencySummary: String { candidate.frequencySummary }
    var reminderTime: Date { candidate.reminderTime }
    var isDuplicate: Bool { candidate.isDuplicate }
    var schedule: RecurringRuleSchedule { candidate.schedule }
}

#Preview {
    NavigationStack {
        DingTalkCalendarImportView()
    }
}
