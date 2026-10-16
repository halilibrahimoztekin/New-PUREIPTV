import SwiftUI

public struct SmartPasteBannerView: View {
    public let detectedURL: String
    public let onApply: (String) -> Void
    public let onDismiss: () -> Void

    public init(
        detectedURL: String,
        onApply: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.detectedURL = detectedURL
        self.onApply = onApply
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.title2)
                .foregroundStyle(.cyan)
                .padding(10)
                .background(Color.cyan.opacity(0.18))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Panoda IPTV Linki Algılandı")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Text(detectedURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                onApply(detectedURL)
            } label: {
                Text("Doldur")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.16).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}
