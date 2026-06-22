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

                SecureField("DeepSeek API Key", text: $apiKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("api-key-field")
            } footer: {
                Text("API Key 仅保存在本机 Keychain，不会上传到其他服务器。")
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
        .navigationTitle("DeepSeek API Key")
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
