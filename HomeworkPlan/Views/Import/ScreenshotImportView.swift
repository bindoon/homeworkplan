import PhotosUI
import SwiftUI

struct ScreenshotImportView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    var initialImage: UIImage?
    var onImportComplete: (() -> Void)?

    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var reviewResult: ImportResult?
    @State private var didProcessInitialImage = false
    @State private var processingStage = ""

    private var isQuickImport: Bool { initialImage != nil }

    var body: some View {
        Group {
            if let reviewResult, let dependencies {
                TaskCandidateReviewView(
                    result: reviewResult,
                    dependencies: dependencies,
                    onFinish: completeImport
                )
            } else if isProcessing || (isQuickImport && !didProcessInitialImage) {
                VStack(spacing: 16) {
                    ProgressView(processingStage.isEmpty ? "正在处理…" : processingStage)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                formContent
            }
        }
        .navigationTitle(reviewResult == nil ? "截图导入" : "确认作业")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startQuickImportIfNeeded()
        }
        .alert("导入失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {
                if isQuickImport {
                    completeImport()
                }
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func startQuickImportIfNeeded() {
        guard let initialImage, !didProcessInitialImage else { return }
        didProcessInitialImage = true
        Task { await importImage(initialImage) }
    }

    private func completeImport() {
        if let onImportComplete {
            onImportComplete()
        } else {
            dismiss()
        }
    }

    private var formContent: some View {
        VStack(spacing: 24) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images
            ) {
                Label("选择截图", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
            .accessibilityIdentifier("screenshot-picker")

            if isProcessing {
                ProgressView(processingStage.isEmpty ? "正在处理…" : processingStage)
            }

            Spacer()
        }
        .padding()
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await processPickerItem(newItem) }
        }
    }

    @MainActor
    private func processPickerItem(_ item: PhotosPickerItem) async {
        guard let dependencies, !isProcessing else { return }

        isProcessing = true
        processingStage = "正在读取图片…"
        defer {
            isProcessing = false
            processingStage = ""
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "无法读取所选图片"
                return
            }
            processingStage = "正在识别文字…"
            try await runImport(image, using: dependencies)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func importImage(_ image: UIImage) async {
        guard let dependencies, !isProcessing else { return }

        isProcessing = true
        processingStage = "正在识别文字…"
        defer {
            isProcessing = false
            processingStage = ""
        }

        do {
            try await runImport(image, using: dependencies)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func runImport(_ image: UIImage, using dependencies: AppDependencies) async throws {
        let result = try await dependencies.importService.processImage(image)
        if result.isDuplicate && result.candidates.isEmpty {
            errorMessage = ImportServiceError.duplicateContent.localizedDescription
            return
        }
        reviewResult = result
    }
}

#Preview {
    NavigationStack {
        ScreenshotImportView()
    }
}
