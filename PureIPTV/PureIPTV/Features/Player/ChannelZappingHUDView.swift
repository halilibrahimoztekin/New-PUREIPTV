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
    public let currentProgram: EPGProgram?
    public let nextProgram: EPGProgram?
    public let isCleaningEnabled: Bool

    @State private var pulseChevron: Bool = false

    public init(
        item: PlayerFeature.PlayableItem,
        direction: ZappingDirection,
        currentIndex: Int? = nil,
        totalChannels: Int? = nil,
        isCommitted: Bool = false,
        currentProgram: EPGProgram? = nil,
        nextProgram: EPGProgram? = nil,
        isCleaningEnabled: Bool = true
    ) {
        self.item = item
        self.direction = direction
        self.currentIndex = currentIndex
        self.totalChannels = totalChannels
        self.isCommitted = isCommitted
        self.currentProgram = currentProgram
        self.nextProgram = nextProgram
        self.isCleaningEnabled = isCleaningEnabled
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Animated Direction Indicator
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: direction.systemImage)
                    .font(AppFonts.displaySmall.weight(.bold))
                    .foregroundStyle(AppColors.primary)
                    .scaleEffect(pulseChevron ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: pulseChevron
                    )
            }

            // Channel Metadata
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(direction.title.uppercased())
                        .font(AppFonts.captionBold)
                        .tracking(1.0)
                        .foregroundStyle(AppColors.primary)

                    if let current = currentIndex, let total = totalChannels {
                        Text("\(current + 1) / \(total)")
                            .font(AppFonts.captionMedium.monospacedDigit())
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.surfaceSecondary, in: Capsule())
                    }

                    if let q = item.cleanedMetadata.detectedQuality {
                        Text(q.rawValue)
                            .font(AppFonts.captionSmall.weight(.heavy))
                            .foregroundStyle(q.badgeColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(q.badgeColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                    }

                    if let country = item.cleanedMetadata.detectedCountry {
                        Text(country)
                            .font(AppFonts.captionSmall.weight(.heavy))
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 4))
                    }

                    if isCommitted {
                        Text("YÜKLENİYOR")
                            .font(AppFonts.captionSmall.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.success.opacity(0.8), in: Capsule())
                    }
                }

                Text(isCleaningEnabled ? item.cleanTitle : item.title)
                    .font(AppFonts.titleSmall.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                if let current = currentProgram {
                    NowNextEPGPeekView(
                        currentProgram: current,
                        nextProgram: nextProgram,
                        isCompact: true,
                        showProgressRing: true
                    )
                    .padding(.top, 2)
                } else if let subtitle = item.seriesTitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                } else if item.isLive {
                    Text(AppStrings.Player.liveBroadcast)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.textSecondary)
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
                                    AppColors.borderSubtle.opacity(0.8),
                                    AppColors.borderSubtle.opacity(0.2),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: AppColors.background.opacity(0.4), radius: 24, x: 0, y: 12)
        )
        #if os(tvOS)
        .frame(maxWidth: 580)
        #else
        .frame(maxWidth: 440)
        #endif
        .onAppear {
            pulseChevron = true
        }
    }
}
