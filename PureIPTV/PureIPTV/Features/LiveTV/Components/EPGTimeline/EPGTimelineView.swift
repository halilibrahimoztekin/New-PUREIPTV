import ComposableArchitecture
import SwiftUI

public struct EPGTimelineView: View {
    @Bindable var store: StoreOf<EPGTimelineFeature>

    // Config
    let hourWidth: CGFloat = 300
    let rowHeight: CGFloat = 60
    let channelColumnWidth: CGFloat = 100

    public init(store: StoreOf<EPGTimelineFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Color.black.ignoresSafeArea()

                if store.channels.isEmpty {
                    VStack {
                        Spacer()
                        Text(AppStrings.LiveTV.noChannels)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    timelineGrid
                }
            }
            .navigationTitle(AppStrings.Player.timeline)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.close) {
                            store.send(.closeTapped)
                        }
                    }
                }
                .onAppear {
                    store.send(.onAppear)
                    // Trigger initial fetch for visible channels (e.g. first 10)
                    for channel in store.channels.prefix(15) {
                        store.send(.fetchEPG(streamID: channel.id))
                    }
                }
        }
    }

    private var timelineGrid: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row (Times)
                timeHeaderRow
                    .padding(.leading, channelColumnWidth)
                // Pinned to top if we were using sections, but for standard 2D scroll it scrolls with content.

                // Channels and Programs
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(store.channels) { channel in
                        HStack(spacing: 0) {
                            // Sticky-like channel info (Will scroll out horizontally in standard ScrollView,
                            // to make it truly sticky we'd need custom layout or matched geometry,
                            // but for MVP we use a simple grid)
                            channelCell(channel)

                            // Programs row
                            programsRow(for: channel)
                                .frame(height: rowHeight)
                                .onAppear {
                                    store.send(.fetchEPG(streamID: channel.id))
                                }
                        }
                        Divider().background(Color.white.opacity(0.1))
                    }
                }
            }
        }
    }

    private var timeHeaderRow: some View {
        HStack(spacing: 0) {
            // Generate hours from 2 hours ago to 4 hours ahead
            let calendar = Calendar.current
            let now = store.currentTime
            let startOfHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            let start = calendar.date(byAdding: .hour, value: -2, to: startOfHour)!

            ForEach(0 ..< 8) { i in
                let hourDate = calendar.date(byAdding: .hour, value: i, to: start)!
                Text(formatTime(hourDate))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: hourWidth, alignment: .leading)
                    .padding(.leading, 8)
                    .frame(height: 40)
            }
        }
        .background(Color(hex: "#1A1A1D"))
    }

    private func channelCell(_ channel: MediaModels.Item) -> some View {
        Button {
            store.send(.channelTapped(channel))
        } label: {
            VStack(spacing: 4) {
                if let url = channel.coverURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "tv").foregroundColor(.gray)
                        }
                    }
                    .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "tv").foregroundColor(.gray).frame(width: 40, height: 40)
                }
                Text(channel.title)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: channelColumnWidth, height: rowHeight)
            .background(Color(hex: "#121214"))
        }
        .buttonStyle(.plain)
    }

    private func programsRow(for channel: MediaModels.Item) -> some View {
        GeometryReader { _ in
            if store.isLoading[channel.id] == true, store.epgData[channel.id] == nil {
                ProgressView()
                    .frame(width: hourWidth, height: rowHeight)
            } else if let programs = store.epgData[channel.id], !programs.isEmpty {
                // Calculate position relative to timeline start
                let calendar = Calendar.current
                let now = store.currentTime
                let startOfHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
                let timelineStart = calendar.date(byAdding: .hour, value: -2, to: startOfHour)!

                ZStack(alignment: .leading) {
                    ForEach(programs) { program in
                        let startOffset = program.startTime.timeIntervalSince(timelineStart)
                        let duration = program.endTime.timeIntervalSince(program.startTime)

                        // Width: (duration / 3600) * hourWidth
                        let width = max(0, (duration / 3600.0) * Double(hourWidth))
                        let xPos = (startOffset / 3600.0) * Double(hourWidth)

                        if width > 0, xPos > -width, xPos < Double(hourWidth) * 8 {
                            programCell(program: program, channel: channel)
                                .frame(width: CGFloat(width), height: rowHeight - 4)
                                .offset(x: CGFloat(xPos))
                        }
                    }

                    // Current time line indicator
                    let currentOffset = store.currentTime.timeIntervalSince(timelineStart)
                    let currentX = (currentOffset / 3600.0) * Double(hourWidth)

                    if currentX > 0, currentX < Double(hourWidth) * 8 {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2, height: rowHeight)
                            .offset(x: CGFloat(currentX))
                            .zIndex(100)
                    }
                }
            } else {
                Text(AppStrings.Player.noRecord)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
                    .frame(height: rowHeight)
                    .padding(.leading, 16)
            }
        }
        .frame(width: hourWidth * 8) // Total width of 8 hours
    }

    private func programCell(program: EPGProgram, channel: MediaModels.Item) -> some View {
        Button {
            if program.isPlayingNow {
                store.send(.channelTapped(channel))
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(program.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(formatTime(program.startTime)) - \(formatTime(program.endTime))")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(program.isPlayingNow ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .padding(.horizontal, 1)
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
