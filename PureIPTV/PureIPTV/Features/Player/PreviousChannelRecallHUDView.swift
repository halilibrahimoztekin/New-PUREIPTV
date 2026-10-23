import SwiftUI

// MARK: - Previous Channel Recall HUD View (Madde #10)

public struct PreviousChannelRecallHUDView: View {
    let item: PlayerFeature.PlayableItem
    let onDismiss: () -> Void

    public init(item: PlayerFeature.PlayableItem, onDismiss: @escaping () -> Void) {
        self.item = item
        self.onDismiss = onDismiss
    }

    public var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 14) {
                // Return Icon & Cover
                ZStack {
                    channelCoverView

                    // Floating Utun Icon Badge
                    Circle()
                        .fill(Color(hex: "#FF9F0A"))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(.black)
                        )
                        .offset(x: 16, y: 16)
                }

                // Channel Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(AppStrings.Player.recalledTitle.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#FF9F0A"))

                        Text("•")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))

                        Text(AppStrings.Player.quickRecallBadge)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color(hex: "#FF9F0A").opacity(0.2))
                            .foregroundStyle(Color(hex: "#FF9F0A"))
                            .clipShape(Capsule())
                    }

                    Text(item.title)
                    #if os(tvOS)
                        .font(.system(size: 20, weight: .bold))
                    #else
                        .font(.subheadline.weight(.bold))
                    #endif
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let cat = item.categoryID, !cat.isEmpty {
                        Text(cat)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                // Return Arrow Indicator
                Image(systemName: "arrow.left.arrow.right")
                #if os(tvOS)
                    .font(.system(size: 18, weight: .bold))
                #else
                    .font(.system(size: 14, weight: .bold))
                #endif
                    .foregroundStyle(.white.opacity(0.6))
            }
            #if os(tvOS)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: 520)
            #else
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: 380)
            #endif
            .background(
                ZStack {
                    #if os(tvOS)
                        Color.black.opacity(0.85)
                    #else
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                        Color.black.opacity(0.55)
                    #endif
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FF9F0A").opacity(0.6),
                                Color.white.opacity(0.15),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color(hex: "#FF9F0A").opacity(0.3), radius: 16, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.6), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Channel Cover

    @ViewBuilder
    private var channelCoverView: some View {
        Group {
            if let coverURL = item.coverURL {
                PlaylistAsyncImage(url: coverURL, userAgentOverride: item.userAgentOverride) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .empty:
                        PureLoadingView(size: .small)
                    case .failure:
                        fallbackIcon
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        #if os(tvOS)
        .frame(width: 48, height: 48)
        #else
        .frame(width: 40, height: 40)
        #endif
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
        )
    }

    private var fallbackIcon: some View {
        Image(systemName: "tv")
            .font(.system(size: 18))
            .foregroundStyle(.white.opacity(0.6))
    }
}
