import SwiftUI

public struct SeasonPickerPillsView: View {
    public let seasons: [DetailModels.Season]
    public let selectedSeasonNumber: Int?
    public let allEpisodes: [String: [DetailModels.Episode]]
    public let onSelectSeason: (Int) -> Void

    public init(
        seasons: [DetailModels.Season],
        selectedSeasonNumber: Int?,
        allEpisodes: [String: [DetailModels.Episode]],
        onSelectSeason: @escaping (Int) -> Void
    ) {
        self.seasons = seasons
        self.selectedSeasonNumber = selectedSeasonNumber
        self.allEpisodes = allEpisodes
        self.onSelectSeason = onSelectSeason
    }

    public var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(seasons) { season in
                        let isSelected = selectedSeasonNumber == season.seasonNumber
                        let count = allEpisodes[String(season.seasonNumber)]?.count ?? season.episodeCount ?? 0

                        Button {
                            #if os(iOS)
                                HapticManager.shared.trigger(.light)
                            #endif
                            onSelectSeason(season.seasonNumber)
                        } label: {
                            HStack(spacing: 6) {
                                Text(season.name)
                                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))

                                if count > 0 {
                                    Text("(\(count))")
                                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                        .opacity(isSelected ? 0.95 : 0.6)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                isSelected
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "#0A84FF"), Color(hex: "#0066CC")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    : AnyShapeStyle(Color(hex: "#1A1A24"))
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color(hex: "#00F5D4").opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .shadow(color: isSelected ? Color(hex: "#0A84FF").opacity(0.3) : .clear, radius: 4, y: 2)
                        }
                        #if os(tvOS)
                        .tvFocusEffect(shape: .capsule)
                        #else
                        .buttonStyle(.plain)
                        #endif
                    }
                }
            }

            // Quick Season Menu Dropdown if multiple seasons
            if seasons.count > 2 {
                Menu {
                    ForEach(seasons) { season in
                        let count = allEpisodes[String(season.seasonNumber)]?.count ?? season.episodeCount ?? 0
                        Button {
                            onSelectSeason(season.seasonNumber)
                        } label: {
                            HStack {
                                Text("\(season.name) (\(count) Bölüm)")
                                if selectedSeasonNumber == season.seasonNumber {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(9)
                        .background(Color(hex: "#1A1A24"), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
            }
        }
    }
}
