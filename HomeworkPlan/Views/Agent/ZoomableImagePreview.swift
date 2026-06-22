import SwiftUI

struct ZoomableImagePreview: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1, lastScale * value)
                            }
                            .onEnded { value in
                                lastScale = max(1, lastScale * value)
                                scale = lastScale
                            }
                    )
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

struct TappableMessageImage: View {
    let image: UIImage
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看大图")
    }
}
