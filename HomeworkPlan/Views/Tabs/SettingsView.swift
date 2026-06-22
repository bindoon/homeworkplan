import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SubjectManagementView()
                    } label: {
                        Text("科目管理")
                    }
                }

                Section("AI 解析") {
                    Text("AI 解析设置将在后续版本提供")
                        .foregroundStyle(.secondary)
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
