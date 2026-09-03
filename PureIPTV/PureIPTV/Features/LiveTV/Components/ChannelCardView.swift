import Kingfisher
import Shimmer
import SwiftUI

// MARK: - Channel Card View

// 16:9 card with logo, channel.title, and LIVE badge.
// Used across iOS, iPad, and tvOS (scaled appropriately per platform).

public struct ChannelCardView: View {
    let channel: MediaModels.Item
    let isSelected: Bool
    var onTap: (() -> Void)?

    public init(channel: MediaModels.Item, isSelected: Bool = false, onTap: (() -> Void)? = nil) {
        self.channel = channel
        self.isSelected = isSelected
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            HapticManager.shared.trigger(.light)
            onTap?()
        } label: {
            ZStack(alignment: .bottomLeading) {
                // ── Background & Glassmorphism ──────────────────────
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isSelected
                                    ? Color(hex: "#0A84FF").opacity(0.8)
                                    : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                // ── Logo ─────────────────────────────────────────────
                if let logoURL = channel.coverURL {
                    KFImage(logoURL)
                        .placeholder {
                            ChannelLogoPlaceholder()
                        }
                        .downsampling(size: CGSize(width: 300, height: 200))
                        .cacheOriginalImage()
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ChannelLogoPlaceholder()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // ── Bottom gradient overlay ────────────────────────
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.8)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // ── Channel name + LIVE badge ──────────────────────
                HStack(alignment: .center, spacing: 6) {
                    Text(channel.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                    Spacer(minLength: 4)

                    LiveBadge()
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .aspectRatio(16 / 9, contentMode: .fill)
            #if os(tvOS)
                .buttonStyle(TVGridCardButtonStyle())
            #else
                .buttonStyle(.plain)
            #endif
                .scaleEffect(isSelected ? 1.02 : 1.0)
                .shadow(
                    color: isSelected ? Color(hex: "#0A84FF").opacity(0.4) : .black.opacity(0.2),
                    radius: isSelected ? 12 : 8, x: 0, y: 4
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }
}

// MARK: - Channel Logo Placeholder

private struct ChannelLogoPlaceholder: View {
    var body: some View {
        ZStack {
            Color(hex: "#2C2C30")
            Image(systemName: "tv.fill")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shimmeringPlaceholder(isLoading: true)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Category Row View

public struct CategoryRowView: View {
    let category: MediaModels.Category
    let isSelected: Bool
    let action: () -> Void

    public init(category: MediaModels.Category, isSelected: Bool, action: @escaping () -> Void) {
        self.category = category
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button {
            HapticManager.shared.trigger(.light)
            action()
        } label: {
            HStack(spacing: 10) {
                // Selection indicator
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? Color(hex: "#0A84FF") : Color.clear)
                    .frame(width: 3, height: 20)

                Text(category.name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color(hex: "#E4E1E7") : Color(hex: "#C0C6D6").opacity(0.65))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color(hex: "#0A84FF").opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.fluidScale)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
