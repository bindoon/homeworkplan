import SwiftUI

struct APIKeySettingsView: View {
    @Environment(\.appDependencies) private var dependencies

    @State private var apiKey = ""
    @State private var hasSavedKey = false
    @State private var saveMessage: String?
    @State private var showSaveConfirmation = false

    var body: some View {
        Form {
            Section {
                if hasSavedKey && apiKey.isEmpty {
                    HStack {
                        Text("已保存 API Key")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                SecureField("DashScope API Key", text: $apiKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("api-key-field")
            } footer: {
                if AppSecrets.isConfigured {
                    Text("已使用编译时本地配置（Secrets.env）。此处填写的 Key 会优先覆盖。")
                } else {
                    Text("未检测到编译时配置，请填写 DashScope API Key 或创建 Config/Secrets.env 后重新编译。")
                }
            }

            Section {
                Button("保存") {
                    saveKey()
                }
                .accessibilityIdentifier("api-key-save")

                if hasSavedKey {
                    Button("清除 API Key", role: .destructive) {
                        clearKey()
                    }
                }
            }
        }
        .navigationTitle("API Key")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hasSavedKey = dependencies?.keychainService.hasAPIKey() ?? false
        }
        .alert("已保存", isPresented: $showSaveConfirmation) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(saveMessage ?? "API Key 已安全保存。")
        }
    }

    private func saveKey() {
        guard let dependencies else { return }
        do {
            try dependencies.keychainService.saveAPIKey(apiKey)
            hasSavedKey = dependencies.keychainService.hasAPIKey()
            saveMessage = "API Key 已保存"
            showSaveConfirmation = true
            apiKey = ""
        } catch {
            saveMessage = error.localizedDescription
            showSaveConfirmation = true
        }
    }

    private func clearKey() {
        guard let dependencies else { return }
        try? dependencies.keychainService.deleteAPIKey()
        apiKey = ""
        hasSavedKey = false
    }
}

#Preview {
    NavigationStack {
        APIKeySettingsView()
    }
}
