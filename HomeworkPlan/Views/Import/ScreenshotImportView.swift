import PhotosUI
import SwiftUI

struct ScreenshotImportView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var reviewResult: ImportResult?

    var body: some View {
        Group {
            if let reviewResult, let dependencies {
                TaskCandidateReviewView(
                    result: reviewResult,
                    dependencies: dependencies,
                    onFinish: { dismiss() }
                )
            } else {
                formContent
            }
        }
        .navigationTitle("截图导入")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formContent: some View {
        VStack(spacing: 24) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("选择截图", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)
            .accessibilityIdentifier("screenshot-picker")

            if isProcessing {
                ProgressView("正在识别并解析…")
            }

            Spacer()
        }
        .padding()
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await process(item: newItem) }
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
    private func process(item: PhotosPickerItem) async {
        guard let dependencies else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "无法读取所选图片"
                return
            }
            let result = try await dependencies.importService.processImage(image)
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
        ScreenshotImportView()
    }
}
