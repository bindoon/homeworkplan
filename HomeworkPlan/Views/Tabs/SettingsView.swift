import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ReminderSettingsView()
                    } label: {
                        Text("提醒设置")
                    }
                    .accessibilityIdentifier("settings-reminder-link")
                }

                Section("AI 解析") {
                    NavigationLink {
                        APIKeySettingsView()
                    } label: {
                        Text("API Key（可选覆盖）")
                    }
                    .accessibilityIdentifier("settings-api-key-link")
                }

                Section("关于") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HomeworkPlan")
                            .font(.headline)
                        Text("版本 1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    SettingsView()
}
