import Combine
import ComposableArchitecture
import SwiftUI

public struct PlayerEPGTimelineView: View {
    #if os(tvOS)
        private enum FocusTarget: Hashable {
            case close
            case watch
            case currentChannel
            case channel(String)
        }

        @FocusState private var focusedTarget: FocusTarget?
    #endif
    let programs: [EPGProgram]
    let currentPosition: Double
    let hasArchive: Bool
    let channels: [PlayerFeature.PlayableItem]
    let selectedChannel: PlayerFeature.PlayableItem?
    let playingChannelID: String
    let isLoading: Bool
    let canSelectPrograms: Bool
    let onClose: () -> Void
    let onBrowseChannel: (PlayerFeature.PlayableItem) -> Void
    let onReturnToPlayingChannel: () -> Void
    let onWatchChannel: () -> Void
    let onSelect: (EPGProgram) -> Void

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var headerSubtitle: String {
        guard let selectedChannel else { return AppStrings.Player.timeline }
        let status = selectedChannel.id == playingChannelID
            ? "Şu An Oynuyor".localized
            : "Yayın devam ediyor".localized
        return "\(selectedChannel.title) • \(status)"
    }

    public init(
        programs: [EPGProgram],
        currentPosition: Double,
        hasArchive: Bool = false,
        channels: [PlayerFeature.PlayableItem] = [],
        selectedChannel: PlayerFeature.PlayableItem? = nil,
        playingChannelID: String = "",
        isLoading: Bool = false,
        canSelectPrograms: Bool = true,
        onClose: @escaping () -> Void,
        onBrowseChannel: @escaping (PlayerFeature.PlayableItem) -> Void = { _ in },
        onReturnToPlayingChannel: @escaping () -> Void = {},
        onWatchChannel: @escaping () -> Void = {},
        onSelect: @escaping (EPGProgram) -> Void
    ) {
        self.programs = programs
        self.currentPosition = currentPosition
        self.hasArchive = hasArchive
        self.channels = channels
        self.selectedChannel = selectedChannel
        self.playingChannelID = playingChannelID
        self.isLoading = isLoading
        self.canSelectPrograms = canSelectPrograms
        self.onClose = onClose
        self.onBrowseChannel = onBrowseChannel
        self.onReturnToPlayingChannel = onReturnToPlayingChannel
        self.onWatchChannel = onWatchChannel
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStrings.Player.epg)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }
                Spacer()
                if let selectedChannel, selectedChannel.id != playingChannelID {
                    Button(action: onReturnToPlayingChannel) {
                        #if os(tvOS)
                            Label(AppStrings.Player.returnToPlayingChannel, systemImage: "arrow.uturn.backward")
                                .font(.subheadline.weight(.semibold))
                        #else
                            Image(systemName: "arrow.uturn.backward")
                                .accessibilityLabel(AppStrings.Player.returnToPlayingChannel)
                        #endif
                    }
                    #if os(tvOS)
                    .buttonStyle(.bordered)
                    .focused($focusedTarget, equals: .currentChannel)
                    #else
                    .buttonStyle(.bordered)
                    #endif
                    Button(action: onWatchChannel) {
                        Label("Bu Kanalı İzle".localized, systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    #if os(tvOS)
                    .buttonStyle(.borderedProminent)
                    .focused($focusedTarget, equals: .watch)
                    #else
                    .buttonStyle(.bordered)
                    #endif
                }
                Button(action: {
                    onClose()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                }
                #if os(tvOS)
                .buttonStyle(TVCircleButtonStyle())
                .focused($focusedTarget, equals: .close)
                #else
                .buttonStyle(.plain)
                #endif
            }
            .padding(16)
            .background(Color.black.opacity(0.4))

            if !channels.isEmpty {
                channelPicker
            }

            Divider().background(Color.white.opacity(0.2))

            // Timeline
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    if programs.isEmpty {
                        Text(AppStrings.Player.epgNotFound)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 40)
                    } else {
                        ForEach(programs) { program in
                            Button(action: {
                                onSelect(program)
                            }) {
                                PlayerEPGTimelineCard(program: program, currentTime: currentTime, hasArchive: hasArchive)
                            }
                            #if os(tvOS)
                            .tvFocusEffect()
                            #else
                            .buttonStyle(.plain)
                            #endif
                            .disabled(!canSelectPrograms)
                        }
                    }
                }
                .padding(16)
            }
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(.bottom, 12)
            }
        }
        .background(AnyShapeStyle(.ultraThinMaterial))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .onReceive(timer) { time in
            currentTime = time
        }
        #if os(tvOS)
        .focusSection()
        .defaultFocus($focusedTarget, .close)
        .onAppear {
            focusedTarget = .close
        }
        #endif
    }

    private var channelPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(channels, id: \.id) { channel in
                    let isSelected = selectedChannel?.id == channel.id
                    Button {
                        onBrowseChannel(channel)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(channel.title)
                                .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                                .lineLimit(1)
                            Text(channel.id == playingChannelID ? "Şu An Oynuyor".localized : (isSelected ? "Rehberi Açık".localized : "Yayına Dokunmaz".localized))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.white.opacity(0.55))
                        }
                        .foregroundStyle(.white)
                        .frame(width: 220, alignment: .leading)
                        .padding(12)
                        .background(isSelected ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.accentColor : Color.white.opacity(0.12), lineWidth: 1))
                    }
                    #if os(tvOS)
                    .tvFocusEffect()
                    .focused($focusedTarget, equals: .channel(channel.id))
                    #else
                    .buttonStyle(.plain)
                    #endif
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

public struct PlayerEPGTimelineCard: View {
    let program: EPGProgram
    let currentTime: Date
    let hasArchive: Bool

    public init(program: EPGProgram, currentTime: Date, hasArchive: Bool = false) {
        self.program = program
        self.currentTime = currentTime
        self.hasArchive = hasArchive
    }

    private var progress: Double {
        let total = program.endTime.timeIntervalSince(program.startTime)
        let elapsed = currentTime.timeIntervalSince(program.startTime)
        if total > 0 {
            return max(0, min(1, elapsed / total))
        }
        return 0
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(formatTime(program.startTime)) - \(formatTime(program.endTime))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(program.isPlayingNow ? .white : .white.opacity(0.7))

                Spacer()

                if program.isPlayingNow {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .symbolEffect(.pulse)
                        Text(AppStrings.Player.liveLabelNormal)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.2))
                    .clipShape(Capsule())
                } else if hasArchive, program.endTime < currentTime {
                    CatchUpBadge(isCompact: true)
                }
            }

            Text(program.title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if !program.description.isEmpty {
                Text(program.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            if program.isPlayingNow {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)

                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * CGFloat(progress), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(width: 240, height: 130)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(program.isPlayingNow ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(program.isPlayingNow ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
