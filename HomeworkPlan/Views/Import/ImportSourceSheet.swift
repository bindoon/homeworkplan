import SwiftUI

struct ImportSourceSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    ScreenshotImportView()
                } label: {
                    Label("从相册选择截图", systemImage: "photo.on.rectangle")
                }
                .accessibilityIdentifier("import-screenshot-link")

                NavigationLink {
                    PasteImportView()
                } label: {
                    Label("粘贴文字", systemImage: "doc.on.clipboard")
                }
                .accessibilityIdentifier("import-paste-link")
            }
            .navigationTitle("导入作业")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ImportSourceSheet()
}
