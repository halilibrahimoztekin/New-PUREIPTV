import ComposableArchitecture
import SwiftUI

// MARK: - Trakt Synced Watchlist & In-Progress Hub View

public struct TraktWatchlistView: View {
    @Bindable var store: StoreOf<TraktFeature>
    @State private var selectedTab: TraktHubTab = .watchlist

    public enum TraktHubTab: String, CaseIterable, Identifiable {
        case watchlist = "İzleme Listesi"
        case inProgress = "Devam Edenler"

        public var id: String {
            rawValue
        }
    }

    public init(store: StoreOf<TraktFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Color(hex: "#0B0E14").ignoresSafeArea()

            VStack(spacing: 20) {
                // Top Tab Selector
                Picker("Sekme", selection: $selectedTab) {
                    ForEach(TraktHubTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if store.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#ED1C24")))
                        .scaleEffect(1.2)
                    Spacer()
                } else {
                    switch selectedTab {
                    case .watchlist:
                        watchlistSection
                    case .inProgress:
                        inProgressSection
                    }
                }
            }
        }
        .navigationTitle("Trakt.tv")
        #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .onAppear {
                store.send(.onAppear)
            }
    }

    // MARK: - Watchlist Section

    @ViewBuilder
    private var watchlistSection: some View {
        if store.watchlist.isEmpty {
            emptyStateView(
                icon: "bookmark.slash",
                title: "İzleme Listeniz Boş",
                subtitle: "Trakt.tv'de izleme listenize eklediğiniz içerikler burada listelenir."
            )
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)],
                    spacing: 20
                ) {
                    ForEach(store.watchlist) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                                    .aspectRatio(2 / 3, contentMode: .fit)
                                    .overlay(
                                        Image(systemName: item.type == "movie" ? "film" : "tv")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.white.opacity(0.2))
                                    )

                                Text(item.type == "movie" ? "Film" : "Dizi")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: "#ED1C24").opacity(0.85))
                                    .clipShape(Capsule())
                                    .padding(8)
                            }

                            Text(item.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            if let year = item.year {
                                Text("\(year)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - In Progress Section

    @ViewBuilder
    private var inProgressSection: some View {
        if store.playbackItems.isEmpty {
            emptyStateView(
                icon: "play.slash",
                title: "Devam Eden İçerik Yok",
                subtitle: "Diğer cihazlarınızda duraklattığınız VOD film ve diziler burada görünür."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.playbackItems) { item in
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 60, height: 60)

                                Image(systemName: item.type == "movie" ? "film" : "tv")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color(hex: "#ED1C24"))
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                if item.type == "episode", let s = item.season, let e = item.episode {
                                    Text("Sezon \(s), Bölüm \(e)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color(hex: "#0A84FF"))
                                }

                                // Progress bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.12))
                                            .frame(height: 5)

                                        Capsule()
                                            .fill(Color(hex: "#ED1C24"))
                                            .frame(width: max(geo.size.width * CGFloat(item.progress / 100.0), 4), height: 5)
                                    }
                                }
                                .frame(height: 5)
                            }

                            Spacer(minLength: 8)

                            Text("%\(Int(item.progress))")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(Color(hex: "#ED1C24"))
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .background(.ultraThinMaterial)
                        )
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Empty State

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.white.opacity(0.3))

            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}
