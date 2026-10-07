import ComposableArchitecture
import SwiftUI

#if os(iOS)
    public struct EPGGuideView_iOS: View {
        @Bindable var store: StoreOf<EPGGuideFeature>

        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @Environment(\.verticalSizeClass) private var verticalSizeClass

        public init(store: StoreOf<EPGGuideFeature>) {
            self.store = store
        }

        public var body: some View {
            NavigationStack {
                Group {
                    if horizontalSizeClass == .regular {
                        // iPad / Landscape: Split view
                        HStack(spacing: 0) {
                            channelsList
                                .frame(width: 300)
                                .background(Color(hex: "#1F1F23"))

                            Divider().background(Color.white.opacity(0.1))

                            epgList
                                .frame(maxWidth: .infinity)
                                .background(Color.black)
                        }
                    } else {
                        // iPhone Portrait
                        VStack(spacing: 0) {
                            channelsHorizontalList
                                .frame(height: 100)
                                .background(Color(hex: "#1F1F23"))

                            Divider().background(Color.white.opacity(0.1))

                            epgList
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black)
                        }
                    }
                }
                .navigationTitle("TV Guide")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Kapat") {
                            store.send(.closeTapped)
                        }
                    }
                }
                .onAppear {
                    store.send(.onAppear)
                }
            }
        }

        // MARK: - Channels View

        private var channelsList: some View {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(store.channels) { channel in
                        channelRow(channel)
                    }
                }
                .padding(.vertical, 8)
            }
        }

        private var channelsHorizontalList: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    LazyHStack(spacing: 12) {
                        ForEach(store.channels) { channel in
                            channelCard(channel)
                                .id(channel.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .onAppear {
                        if let selected = store.selectedChannel {
                            proxy.scrollTo(selected.id, anchor: .center)
                        }
                    }
                }
            }
        }

        private func channelRow(_ channel: MediaModels.Item) -> some View {
            let isSelected = store.selectedChannel?.id == channel.id
            return Button {
                store.send(.selectChannel(channel))
            } label: {
                HStack(spacing: 12) {
                    if let coverURL = channel.coverURL {
                        AsyncImage(url: coverURL) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "tv").foregroundColor(.gray)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                    } else {
                        Image(systemName: "tv")
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                            .foregroundColor(.gray)
                    }

                    Text(channel.title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(8)
                .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)
        }

        private func channelCard(_ channel: MediaModels.Item) -> some View {
            let isSelected = store.selectedChannel?.id == channel.id
            return Button {
                store.send(.selectChannel(channel))
            } label: {
                VStack(spacing: 8) {
                    if let coverURL = channel.coverURL {
                        AsyncImage(url: coverURL) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "tv").foregroundColor(.gray)
                            }
                        }
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(10)
                    } else {
                        Image(systemName: "tv")
                            .font(.system(size: 20))
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(10)
                            .foregroundColor(.gray)
                    }

                    Text(channel.title)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                        .lineLimit(1)
                        .frame(width: 70)
                }
                .padding(8)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }

        // MARK: - EPG List

        private var epgList: some View {
            VStack(spacing: 0) {
                // Selected Channel Header
                if let selected = store.selectedChannel {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selected.title)
                                .font(.headline)
                            Text(AppStrings.EPG.guide)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Button {
                            store.send(.playTapped(selected))
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(AppStrings.EPG.watch)
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(16)
                    .background(Color(hex: "#121214"))

                    Divider().background(Color.white.opacity(0.1))
                }

                if store.isLoadingEPG {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = store.errorMessage {
                    Spacer()
                    Text("\(AppStrings.EPG.error)\(error)")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                } else if store.epgListings.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.3))
                        Text(AppStrings.EPG.noData)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        ScrollViewReader { proxy in
                            LazyVStack(spacing: 0) {
                                ForEach(store.epgListings) { program in
                                    EPGGuideRow(program: program)
                                        .id(program.id)
                                    Divider().background(Color.white.opacity(0.05))
                                }
                            }
                            .padding(.vertical, 8)
                            .onAppear {
                                if let nowPlaying = store.epgListings.first(where: { $0.isPlayingNow }) {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation {
                                            proxy.scrollTo(nowPlaying.id, anchor: .center)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    public struct EPGGuideRow: View {
        let program: EPGProgram

        public init(program: EPGProgram) {
            self.program = program
        }

        public var body: some View {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatTime(program.startTime))
                        .font(.system(size: 15, weight: program.isPlayingNow ? .bold : .medium))
                        .foregroundColor(program.isPlayingNow ? .accentColor : .white.opacity(0.8))
                    Text(formatTime(program.endTime))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(width: 50, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(program.title)
                            .font(.system(size: 15, weight: program.isPlayingNow ? .semibold : .regular))
                            .foregroundColor(program.isPlayingNow ? .white : .white.opacity(0.9))

                        if program.isPlayingNow {
                            Spacer()
                            Text(AppStrings.Player.nowPlaying)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                    }

                    if !program.description.isEmpty {
                        Text(program.description)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(program.isPlayingNow ? Color.accentColor.opacity(0.05) : Color.clear)
        }

        private func formatTime(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
    }
#endif
