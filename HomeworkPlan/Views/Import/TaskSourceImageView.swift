import SwiftUI

struct TaskSourceImageView: View {
    let relativePath: String

    @State private var showFullScreen = false

    var body: some View {
        if let image = ImportImageStore.load(relativePath: relativePath) {
            Section {
                Button {
                    showFullScreen = true
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看导入原图")
            } header: {
                Text("导入原图")
            } footer: {
                Text("点击查看大图，核对解析是否准确")
            }
            .sheet(isPresented: $showFullScreen) {
                NavigationStack {
                    ScrollView {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                    .navigationTitle("导入原图")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showFullScreen = false }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    Form {
        TaskSourceImageView(relativePath: "")
    }
}
