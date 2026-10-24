import ComposableArchitecture
import Kingfisher
import SwiftUI

// MARK: - Quick Recent Channels Carousel HUD (Quick-Zap Dock)

public struct RecentChannelsHUDView: View {
    @Bindable var store: StoreOf<PlayerFeature>
    let onClose: () -> Void

    @FocusState private var focusedChannelID: String?
    @State private var dismissWorkItem: DispatchWorkItem?

    public init(store: StoreOf<PlayerFeature>, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header bar
            headerBar

            // Horizontal Carousel of Recent Channels
            if store.recentChannels.isEmpty {
                emptyStateView
            } else {
                channelsScrollView
            }
        }
        #if os(tvOS)
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Color(hex: "#0C0C10").opacity(0.88)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.7), radius: 30, x: 0, y: 15)
        .focusSection()
        .onExitCommand {
            cancelDismissTimer()
            onClose()
        }
        #else
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Color(hex: "#0C0C10").opacity(0.92)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 10)
        #endif
        .onAppear {
            setupInitialFocus()
            resetDismissTimer()
        }
        .onDisappear {
            cancelDismissTimer()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#0A84FF").opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#0A84FF"))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(AppStrings.LiveTV.recentChannels)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(store.recentChannels.count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#0A84FF"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#0A84FF").opacity(0.18), in: Capsule())
                }

                #if os(tvOS)
                    Text(AppStrings.LiveTV.quickZapHint)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                #endif
            }

            Spacer()

            Button(action: {
                cancelDismissTimer()
                onClose()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        HStack(spacing: 12) {
            Image(systemName: "tv.slash")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.4))
            Text(AppStrings.LiveTV.noRecentChannels)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
    }

    // MARK: - Channels Scroll View

    private var channelsScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(store.recentChannels, id: \.id) { channel in
                        recentChannelCard(channel: channel)
                            .id(channel.id)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
            .onChange(of: focusedChannelID) { _, newID in
                if let newID {
                    resetDismissTimer()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Single Channel Card

    @ViewBuilder
    private func recentChannelCard(channel: PlayerFeature.PlayableItem) -> some View {
        let isCurrent = channel.id == store.item.id
        let isFocused = focusedChannelID == channel.id
        let isPinned = store.pinnedRecentChannelIDs.contains(channel.id)

        Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.light)
            #endif
            cancelDismissTimer()
            store.send(.selectRecentChannel(channel))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Top area: Logo + Status Badges
                ZStack(alignment: .topTrailing) {
                    // Card background
                    Color(hex: "#000000").opacity(0.85)

                    // Logo presentation
                    if let logoURL = channel.coverURL {
                        KFImage.url(logoURL, cacheKey: PlaylistArtworkRequest.cacheKey(for: logoURL, userAgentOverride: channel.userAgentOverride))
                            .requestModifier { request in
                                UserAgentManager.applyHeaders(to: &request, override: channel.userAgentOverride)
                            }
                            .placeholder {
                                fallbackLogoMonogram(title: channel.title)
                            }
                            .downsampling(size: CGSize(width: 180, height: 110))
                            .cacheOriginalImage()
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        fallbackLogoMonogram(title: channel.title)
                    }

                    // Top Badges Overlay
                    HStack(spacing: 4) {
                        if isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.9), in: Capsule())
                        }
                        if isCurrent {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color(hex: "#0A84FF"))
                                    .frame(width: 6, height: 6)
                                Text(AppStrings.LiveTV.nowPlayingBadge)
                                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(hex: "#0A84FF").opacity(0.85), in: Capsule())
                        } else {
                            LiveBadge()
                        }
                    }
                    .padding(8)
                }
                #if os(tvOS)
                .frame(width: 240, height: 115)
                #else
                .frame(width: 170, height: 86)
                #endif

                // Bottom Title & EPG Progress Bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(channel.cleanTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isCurrent ? Color(hex: "#0A84FF") : .white)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        if channel.tvArchive == 1 {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: "#BF5AF2"))
                        }
                    }

                    if isCurrent, let prog = store.currentEPGProgram {
                        let progress = prog.progress()
                        HStack(spacing: 6) {
                            Text(prog.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#00F5D4"))
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 3)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#0A84FF"), Color(hex: "#00F5D4")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))), height: 3)
                            }
                        }
                        .frame(height: 3)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(hex: "#131317"))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isFocused ? Color.white : (isCurrent ? Color(hex: "#0A84FF") : Color.white.opacity(0.12)),
                        lineWidth: isFocused ? 2.5 : (isCurrent ? 2 : 1)
                    )
            )
            .shadow(
                color: isFocused ? Color(hex: "#0A84FF").opacity(0.4) : .clear,
                radius: 12,
                x: 0,
                y: 4
            )
            #if os(tvOS)
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
            #endif
        }
        .buttonStyle(.plain)
        .contextMenu {
            if store.pinnableRecentChannelIDs.contains(channel.id) {
                Button {
                    cancelDismissTimer()
                    store.send(.togglePinnedRecentChannel(channel.id))
                } label: {
                    Label(
                        isPinned ? AppStrings.LiveTV.unpinRecentChannel : AppStrings.LiveTV.pinRecentChannel,
                        systemImage: isPinned ? "pin.slash" : "pin"
                    )
                }
            }
        }
        #if os(tvOS)
        .focused($focusedChannelID, equals: channel.id)
        #endif
    }

    private func fallbackLogoMonogram(title: String) -> some View {
        ZStack {
            Color.white.opacity(0.06)
            VStack(spacing: 4) {
                Image(systemName: "tv")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                Text(title.prefix(3).uppercased())
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func setupInitialFocus() {
        if let current = store.recentChannels.first(where: { $0.id == store.item.id }) {
            focusedChannelID = current.id
        } else {
            focusedChannelID = store.recentChannels.first?.id
        }
    }

    private func resetDismissTimer() {
        cancelDismissTimer()
        let work = DispatchWorkItem {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                onClose()
            }
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: work)
    }

    private func cancelDismissTimer() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
    }
}
