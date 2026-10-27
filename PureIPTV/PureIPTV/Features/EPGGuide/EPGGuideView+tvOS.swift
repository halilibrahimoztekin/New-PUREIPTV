import ComposableArchitecture
import SwiftUI
import SwiftVLC

#if os(tvOS)
    public struct EPGGuideView_tvOS: View {
        @Bindable var store: StoreOf<EPGGuideFeature>
        @Dependency(\.previewPlayerClient) private var previewPlayerClient

        @Environment(\.locale) private var locale
        @FocusState private var focusedChannelID: String?
        @FocusState private var focusedProgramID: String?
        @FocusState private var isScheduleWatchButtonFocused: Bool
        @State private var isLivePulsing: Bool = false

        public init(store: StoreOf<EPGGuideFeature>) {
            self.store = store
        }

        public var body: some View {
            HStack(spacing: 0) {
                // ── Left: Channel List Shelf ────────────────────────────
                channelColumn
                    .frame(width: 440)
                    .focusSection()
                    .focusGuideBoundary()

                // ── Center: Vertical Divider & Focus Bridge ─────────────
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 2)

                    TVFocusGuideBridge()
                        .frame(width: 32)
                }

                // ── Right: EPG Timeline & Schedule ──────────────────────
                epgScheduleArea
                    .focusSection()
                    .focusGuideBoundary()
            }
            .background(
                ZStack {
                    Color(hex: "#0E0E12").ignoresSafeArea()

                    LinearGradient(
                        colors: [
                            Color(hex: "#0A84FF").opacity(0.08),
                            Color.clear,
                            Color(hex: "#5E5CE6").opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
            )
            .onExitCommand {
                store.send(.closeTapped)
            }
            .onAppear {
                isLivePulsing = true
                store.send(.onAppear)
                if let initialID = store.selectedChannel?.id {
                    focusedChannelID = initialID
                }
            }
            .onDisappear {
                store.send(.onDisappear)
            }
        }

        // MARK: - Left: Channel Column

        private var channelColumn: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color(hex: "#0A84FF"))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppStrings.EPG.guide)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)

                        Text("\(store.channels.count) " + "Kanal".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 40)
                .padding(.bottom, 20)

                // Channels List
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(store.channels) { channel in
                            channelRow(channel)
                                .id(channel.id)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
                .onChange(of: focusedChannelID) { _, newID in
                    if let newID, let matchingChannel = store.channels.first(where: { $0.id == newID }) {
                        if store.selectedChannel?.id != matchingChannel.id {
                            store.send(.selectChannel(matchingChannel))
                        }
                    }
                }
            }
        }

        private func channelRow(_ channel: MediaModels.Item) -> some View {
            let isFocused = focusedChannelID == channel.id
            let isSelected = store.selectedChannel?.id == channel.id

            return Button {
                store.send(.selectChannel(channel))
            } label: {
                HStack(spacing: 14) {
                    // Logo
                    Group {
                        if let coverURL = channel.displayLogoURL {
                            PlaylistAsyncImage(url: coverURL, userAgentOverride: channel.userAgentOverride, playlistID: channel.playlistID) { phase in
                                switch phase {
                                case let .success(image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                case .empty:
                                    PureLoadingView(size: .small)
                                case .failure:
                                    fallbackLogo
                                @unknown default:
                                    fallbackLogo
                                }
                            }
                        } else {
                            fallbackLogo
                        }
                    }
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    // Details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(channel.title)
                            .font(.system(size: 17, weight: isFocused || isSelected ? .bold : .medium))
                            .foregroundStyle(isFocused ? .white : (isSelected ? Color(hex: "#0A84FF") : .white.opacity(0.85)))
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if channel.tvArchive == 1 {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("Catch-Up".localized)
                                        .font(.system(size: 9, weight: .heavy))
                                }
                                .foregroundStyle(Color.purple)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                            }

                            qualityBadge(for: channel.title)
                        }
                    }

                    Spacer(minLength: 0)

                    if isSelected {
                        Circle()
                            .fill(Color(hex: "#0A84FF"))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            isFocused
                                ? Color.white.opacity(0.20)
                                : (isSelected ? Color(hex: "#0A84FF").opacity(0.14) : Color.white.opacity(0.04))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isFocused ? Color.white : (isSelected ? Color(hex: "#0A84FF").opacity(0.5) : Color.clear),
                            lineWidth: isFocused ? 2.5 : 1
                        )
                )
                .scaleEffect(isFocused ? 1.04 : 1.0)
                .shadow(color: isFocused ? Color.white.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
            }
            .buttonStyle(.plain)
            .focused($focusedChannelID, equals: channel.id)
            .onMoveCommand { direction in
                if direction == .right {
                    isScheduleWatchButtonFocused = true
                }
            }
        }

        private var fallbackLogo: some View {
            Image(systemName: "tv")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.45))
        }

        private func qualityBadge(for title: String) -> some View {
            let lower = title.lowercased()
            let badgeText: String = {
                if lower.contains("4k") || lower.contains("uhd") {
                    return "4K"
                }
                if lower.contains("fhd") || lower.contains("1080") {
                    return "FHD"
                }
                if lower.contains("hevc") || lower.contains("h.265") {
                    return "HEVC"
                }
                return "HD"
            }()

            return Text(badgeText)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 3))
        }

        // MARK: - Right: EPG Schedule Area

        private var epgScheduleArea: some View {
            VStack(spacing: 0) {
                // Top Channel Info & Actions Bar
                channelDetailHeader

                Divider().background(Color.white.opacity(0.08))

                // Schedule Body
                if store.isLoadingEPG {
                    Spacer()
                    PureLoadingView(size: .large, text: "Yayın akışı yükleniyor...".localized)
                    Spacer()
                } else if let error = store.errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.yellow)
                        Text("\(AppStrings.EPG.error)\(error)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        retryEPGButton
                    }
                    Spacer()
                } else if store.epgListings.isEmpty {
                    Spacer()
                    VStack(spacing: 14) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.25))
                        Text(AppStrings.EPG.noData)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                        retryEPGButton
                    }
                    Spacer()
                } else {
                    programScrollView
                }
            }
        }

        @ViewBuilder
        private var retryEPGButton: some View {
            if let channel = store.selectedChannel {
                Button(AppStrings.Common.retry) {
                    store.send(.selectChannel(channel))
                }
                .buttonStyle(.bordered)
            }
        }

        // MARK: - Channel Detail Header

        private var channelDetailHeader: some View {
            HStack(spacing: 20) {
                if let selected = store.selectedChannel {
                    // Preview Video or Large Logo
                    if store.activePreviewChannel?.id == selected.id, store.isPreviewPlaying,
                       let player = previewPlayerClient.vlcPlayer()
                    {
                        ZStack {
                            Color.black
                            VideoView(player)
                        }
                        .frame(width: 140, height: 79)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hex: "#0A84FF"), lineWidth: 2)
                        )
                        .overlay(alignment: .topLeading) {
                            HStack(spacing: 3) {
                                Circle().fill(Color.red).frame(width: 5, height: 5)
                                Text("CANLI")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.65), in: Capsule())
                            .padding(4)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Button {
                                store.send(.togglePreviewMute)
                            } label: {
                                Image(systemName: store.isPreviewMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.6), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(store.isPreviewMuted ? AppStrings.EPG.unmutePreview : AppStrings.EPG.mutePreview)
                            .padding(4)
                        }
                    } else {
                        // Large Logo
                        Group {
                            if let coverURL = selected.displayLogoURL {
                                PlaylistAsyncImage(url: coverURL, userAgentOverride: selected.userAgentOverride, playlistID: selected.playlistID) { phase in
                                    switch phase {
                                    case let .success(img):
                                        img.resizable().aspectRatio(contentMode: .fit)
                                    case .empty:
                                        PureLoadingView(size: .small)
                                    case .failure:
                                        fallbackHeaderLogo
                                    @unknown default:
                                        fallbackHeaderLogo
                                    }
                                }
                            } else {
                                fallbackHeaderLogo
                            }
                        }
                        .frame(width: 72, height: 72)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }

                    // Title & Badges
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selected.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            if selected.tvArchive == 1 {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("7 Günlük Tekrar İzle / Catch-Up Aktif".localized)
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(Color.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.purple.opacity(0.18), in: Capsule())
                            }

                            Text("Canlı Yayın Akışı".localized)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Text(store.epgFreshnessLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(store.lastEPGRefreshFailureDate.map { $0 >= (store.lastEPGRefreshDate ?? .distantPast) } == true ? .orange : .white.opacity(0.55))
                    }

                    Spacer()

                    // Play Channel Button
                    Button {
                        store.send(.playTapped(selected))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(AppStrings.EPG.watch)
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#0A84FF"), in: Capsule())
                    }
                    .buttonStyle(.card)
                    .focused($isScheduleWatchButtonFocused)

                    // Close Button
                    Button {
                        store.send(.closeTapped)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(12)
                    }
                    .buttonStyle(TVCircleButtonStyle())
                    .accessibilityLabel(AppStrings.Common.close)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
            .background(Color.white.opacity(0.02))
        }

        private var fallbackHeaderLogo: some View {
            Image(systemName: "tv")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.4))
        }

        // MARK: - Program Scroll View

        private var programScrollView: some View {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(store.epgListings) { program in
                            let hasArchive = store.selectedChannel?.tvArchive == 1
                            tvProgramRow(program: program, hasArchive: hasArchive)
                                .id(program.id)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                }
                .onAppear {
                    if let nowPlaying = store.epgListings.first(where: { isCurrent(start: $0.startTime, end: $0.endTime) }) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                proxy.scrollTo(nowPlaying.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }

        // MARK: - TV Program Row

        private func tvProgramRow(program: EPGProgram, hasArchive: Bool) -> some View {
            let isFocused = focusedProgramID == program.id
            let isCurrentProgram = isCurrent(start: program.startTime, end: program.endTime)
            let isPast = program.endTime < Date()

            return Button {
                if hasArchive, isPast, let channel = store.selectedChannel {
                    store.send(.playCatchUp(program, channel))
                } else if let channel = store.selectedChannel {
                    store.send(.playTapped(channel))
                }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 18) {
                        // Time Column
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatTime(program.startTime))
                                .font(.system(size: 18, weight: isCurrentProgram ? .heavy : .bold, design: .monospaced))
                                .foregroundStyle(isCurrentProgram ? Color(hex: "#0A84FF") : .white)

                            Text(formatTime(program.endTime))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .frame(width: 70, alignment: .leading)

                        // Title & Tags
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(program.title)
                                    .font(.system(size: 20, weight: isCurrentProgram ? .bold : .semibold))
                                    .foregroundStyle(isFocused ? .white : (isCurrentProgram ? .white : .white.opacity(0.9)))
                                    .lineLimit(1)

                                // Live Badge
                                if isCurrentProgram {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 7, height: 7)
                                            .scaleEffect(isLivePulsing ? 1.25 : 0.85)
                                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isLivePulsing)

                                        Text(AppStrings.Player.nowPlaying)
                                            .font(.system(size: 10, weight: .heavy))
                                            .foregroundStyle(.red)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red.opacity(0.18), in: Capsule())
                                }

                                // Catch-Up / Replay Pill
                                if hasArchive, isPast {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 10, weight: .bold))
                                        Text(AppStrings.Player.watchCatchUp)
                                            .font(.system(size: 10, weight: .heavy))
                                    }
                                    .foregroundStyle(Color.purple)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.purple.opacity(0.22), in: Capsule())
                                }

                                Spacer(minLength: 0)

                                // Duration pill
                                let durationMins = max(1, Int(program.endTime.timeIntervalSince(program.startTime) / 60))
                                Text("\(durationMins) dk")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                            }

                            // Description if present
                            if !program.description.isEmpty {
                                Text(program.description)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(isFocused ? 3 : 1)
                            }
                        }

                        Spacer(minLength: 0)
                    }

                    // Progress bar for live program
                    if isCurrentProgram {
                        let progress = calculateProgress(start: program.startTime, end: program.endTime)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 4)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#0A84FF"), Color(hex: "#64D2FF")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))), height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            isFocused
                                ? Color.white.opacity(0.20)
                                : (isCurrentProgram ? Color(hex: "#0A84FF").opacity(0.08) : Color.white.opacity(0.03))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isFocused ? Color.white : (isCurrentProgram ? Color(hex: "#0A84FF").opacity(0.4) : Color.clear),
                            lineWidth: isFocused ? 2.5 : 1
                        )
                )
                .scaleEffect(isFocused ? 1.02 : 1.0)
                .shadow(color: isFocused ? Color.white.opacity(0.25) : .clear, radius: 8, x: 0, y: 4)
                .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
            }
            .buttonStyle(.plain)
            .focused($focusedProgramID, equals: program.id)
            .onMoveCommand { direction in
                if direction == .left, let channelID = store.selectedChannel?.id {
                    focusedChannelID = channelID
                }
            }
        }

        // MARK: - Helpers

        private func isCurrent(start: Date, end: Date) -> Bool {
            let now = Date()
            return start <= now && now <= end
        }

        private func calculateProgress(start: Date, end: Date) -> Double {
            let total = end.timeIntervalSince(start)
            guard total > 0 else { return 0.0 }
            let elapsed = Date().timeIntervalSince(start)
            return max(0.0, min(1.0, elapsed / total))
        }

        private func formatTime(_ date: Date) -> String {
            LocalTimePresentation.string(from: date, locale: locale)
        }
    }
#endif
