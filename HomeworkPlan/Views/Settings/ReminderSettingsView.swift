import SwiftUI
import UserNotifications

struct ReminderSettingsView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var morningTime = Date()
    @State private var afternoonTime = Date()
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let reminderSettings = ReminderSettings()

    var body: some View {
        Form {
            Section {
                DatePicker(
                    "早上提醒",
                    selection: $morningTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: morningTime) { _, newValue in
                    reminderSettings.setMorningReminder(from: newValue)
                }

                DatePicker(
                    "下午提醒",
                    selection: $afternoonTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: afternoonTime) { _, newValue in
                    reminderSettings.setAfternoonReminder(from: newValue)
                }

                Text("有截止日期的作业将在截止日当天按上述时间提醒；下午提醒用于未完成时再提醒一次。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("默认提醒时间")
            }

            Section {
                permissionStatusRow

                if authorizationStatus == .denied {
                    Text("通知权限已关闭，无法在截止日提醒作业。请在系统设置中为本 App 开启通知。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("打开系统设置") {
                        openSystemSettings()
                    }
                    .accessibilityIdentifier("reminder-open-settings-button")
                }
            } header: {
                Text("通知权限")
            }
        }
        .navigationTitle("提醒设置")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            morningTime = reminderSettings.morningReminderDate
            afternoonTime = reminderSettings.afternoonReminderDate
            await refreshAuthorizationStatus()
        }
    }

    @ViewBuilder
    private var permissionStatusRow: some View {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            Label("已授权", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .denied:
            Label("未授权", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .notDetermined:
            Label("尚未请求", systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
            Button("允许通知") {
                Task { await requestPermission() }
            }
        @unknown default:
            Label("未知状态", systemImage: "questionmark.circle")
        }
    }

    private func refreshAuthorizationStatus() async {
        guard let dependencies else { return }
        authorizationStatus = await dependencies.reminderService.authorizationStatus()
    }

    private func requestPermission() async {
        guard let dependencies else { return }
        _ = await dependencies.reminderService.requestAuthorizationIfNeeded()
        await refreshAuthorizationStatus()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        ReminderSettingsView()
    }
}
