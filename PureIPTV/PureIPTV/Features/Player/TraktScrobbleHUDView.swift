import SwiftUI

// MARK: - Trakt Scrobble HUD Toast

public struct TraktScrobbleHUDView: View {
    public let message: String
    public let isSuccess: Bool
    public let progressPercent: Double?

    public init(message: String, isSuccess: Bool = true, progressPercent: Double? = nil) {
        self.message = message
        self.isSuccess = isSuccess
        self.progressPercent = progressPercent
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Trakt Badge Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "#ED1C24").opacity(0.2))
                    .frame(width: 34, height: 34)

                Image(systemName: isSuccess ? "checkmark.circle.fill" : "tv.badge.wifi")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#ED1C24"))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("TRAKT.TV")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color(hex: "#ED1C24"))
                        .tracking(1.0)

                    if let progress = progressPercent {
                        Text("%\(Int(progress))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                }

                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        #if os(tvOS)
            .frame(minWidth: 360, maxWidth: 440)
        #else
            .frame(minWidth: 260, maxWidth: 340)
        #endif
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#161922").opacity(0.88))
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(hex: "#ED1C24").opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "#ED1C24").opacity(0.25), radius: 16, x: 0, y: 6)
            )
    }
}
