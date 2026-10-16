import SwiftUI

public struct SportsHubView: View {
    public let matches: [SportsMatchItem]
    public let onPlayChannel: (MediaModels.Item) -> Void

    public init(matches: [SportsMatchItem], onPlayChannel: @escaping (MediaModels.Item) -> Void) {
        self.matches = matches
        self.onPlayChannel = onPlayChannel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Günün Maçları & Karşılaşmalar", systemImage: "sportscourt.fill")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("\(matches.count) Maç")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if matches.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "soccerball")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("Bugün için listelenen maç bulunamadı")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(matches) { match in
                            matchCard(match)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func matchCard(_ match: SportsMatchItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Competition & Live Badge
            HStack {
                Text(match.competition.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.orange)
                    .lineLimit(1)

                Spacer()

                if match.isLiveNow {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("CANLI")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.red)
                    }
                } else {
                    Text(match.formattedTime)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }

            // Teams
            VStack(alignment: .leading, spacing: 4) {
                Text(match.homeTeam)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(match.awayTeam)
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Channel & Watch Button
            HStack {
                Text(match.channelName)
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    #if !os(tvOS)
                        HapticManager.shared.trigger(.light)
                    #endif
                    onPlayChannel(match.channelItem)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("İzle")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 240)
        .background(Color(hex: "#1A1A22"), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(match.isLiveNow ? Color.red.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
