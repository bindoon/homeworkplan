import SwiftUI

struct PasteImportView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    var initialText: String = ""
    var onImportComplete: (() -> Void)?

    @State private var pastedText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var reviewResult: ImportResult?

    var body: some View {
        Group {
            if let reviewResult, let dependencies {
                TaskCandidateReviewView(
                    result: reviewResult,
                    dependencies: dependencies,
                    onFinish: completeImport
                )
            } else {
                formContent
            }
        }
        .navigationTitle(reviewResult == nil ? "粘贴导入" : "确认作业")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func completeImport() {
        if let onImportComplete {
            onImportComplete()
        } else {
            dismiss()
        }
    }

    private var formContent: some View {
        VStack(spacing: 16) {
            TextEditor(text: $pastedText)
                .frame(minHeight: 200)
                .overlay(alignment: .topLeading) {
                    if pastedText.isEmpty {
                        Text("粘贴家校群或作业文字…")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityIdentifier("paste-text-editor")

            Button {
                Task { await submit() }
            } label: {
                if isProcessing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("开始解析")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            .accessibilityIdentifier("paste-submit-button")

            Spacer()
        }
        .padding()
        .onAppear {
            if pastedText.isEmpty, !initialText.isEmpty {
                pastedText = initialText
            }
        }
        .alert("导入失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func submit() async {
        guard let dependencies else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await dependencies.importService.processPastedText(pastedText)
            if result.isDuplicate && result.candidates.isEmpty {
                errorMessage = ImportServiceError.duplicateContent.localizedDescription
                return
            }
            reviewResult = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        PasteImportView()
    }
}
