import SwiftUI

public enum ZappingDirection: Sendable, Equatable {
    case next
    case previous

    public var systemImage: String {
        switch self {
        case .next:
            "chevron.up.circle.fill"
        case .previous:
            "chevron.down.circle.fill"
        }
    }

    public var title: String {
        switch self {
        case .next:
            AppStrings.Player.nextChannel
        case .previous:
            AppStrings.Player.previousChannel
        }
    }
}

public struct ChannelZappingHUDView: View {
    public let item: PlayerFeature.PlayableItem
    public let direction: ZappingDirection
    public let currentIndex: Int?
    public let totalChannels: Int?
    public let isCommitted: Bool

    @State private var pulseChevron: Bool = false

    public init(
        item: PlayerFeature.PlayableItem,
        direction: ZappingDirection,
        currentIndex: Int? = nil,
        totalChannels: Int? = nil,
        isCommitted: Bool = false
    ) {
        self.item = item
        self.direction = direction
        self.currentIndex = currentIndex
        self.totalChannels = totalChannels
        self.isCommitted = isCommitted
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Animated Direction Indicator
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: direction.systemImage)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.accentColor)
                    .scaleEffect(pulseChevron ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: pulseChevron
                    )
            }

            // Channel Metadata
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(direction.title.uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.0)
                        .foregroundColor(.accentColor)

                    if let current = currentIndex, let total = totalChannels {
                        Text("\(current + 1) / \(total)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }

                    if isCommitted {
                        Text("YÜKLENİYOR")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.8), in: Capsule())
                    }
                }

                Text(item.title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let subtitle = item.seriesTitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                } else if item.isLive {
                    Text(AppStrings.Player.liveBroadcast)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
        )
        .frame(maxWidth: 420)
        .onAppear {
            pulseChevron = true
        }
    }
}
