import SwiftUI

struct ClipboardHintBanner: View {
    let onImport: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(.orange)

            Text("检测到剪贴板内容，是否导入？")
                .font(.subheadline)

            Spacer()

            Button("导入", action: onImport)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12))
        .accessibilityIdentifier("clipboard-hint-banner")
    }
}

#Preview {
    ClipboardHintBanner(onImport: {}, onDismiss: {})
}
