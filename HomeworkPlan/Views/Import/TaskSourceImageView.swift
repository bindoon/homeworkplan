import SwiftUI

struct TaskSourceImageView: View {
    let relativePath: String
    var onImageTap: ((UIImage) -> Void)?

    var body: some View {
        if let image = ImportImageStore.load(relativePath: relativePath) {
            Section {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onImageTap?(image)
                    }
                    .accessibilityLabel("查看导入原图")
                    .accessibilityAddTraits(.isButton)
            } header: {
                Text("导入原图")
            } footer: {
                Text("点击查看大图，核对解析是否准确")
            }
        }
    }
}

struct ImportImageFullScreenOverlay: View {
    let image: UIImage
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.94)
                .ignoresSafeArea()

            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }

            VStack {
                HStack {
                    Spacer()
                    Button("完成", action: onDismiss)
                        .buttonStyle(.borderedProminent)
                        .padding()
                }
                Spacer()
            }
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("import-image-fullscreen-overlay")
    }
}

#Preview {
    Form {
        TaskSourceImageView(relativePath: "")
    }
}
