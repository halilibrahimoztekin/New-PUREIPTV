import SwiftUI

struct DashboardEPGEventCard: View {
    @Environment(\.locale) private var locale
    let event: DashboardFeature.EPGEvent
    let followedSportsIDs: Set<String>
    let pendingSportsFollowIDs: Set<String>
    let onToggleSportsFollow: (SportsFollowKind, String) -> Void
    let onSelectChannel: (MediaModels.Item) -> Void
    let onChooseChannel: () -> Void

    private var accessibilitySummary: String {
        let status = event.program.isPlayingNow
            ? AppStrings.Dashboard.nowAiring
            : event.program.formattedStartTime(locale: locale)
        return "\(event.program.title), \(status), \(event.channel.title), \(event.program.formattedTimeRange(locale: locale))"
    }

    private var isFollowedSportsMatch: Bool {
        guard let fixture = SportsHubManager.fixtureIdentity(
            program: event.program,
            channelTitle: event.channel.title
        ) else { return false }
        return followedSportsIDs.contains(SportsFollowSyncRecord.identity(kind: .team, displayName: fixture.homeTeam))
            || followedSportsIDs.contains(SportsFollowSyncRecord.identity(kind: .team, displayName: fixture.awayTeam))
            || fixture.competition.map {
                followedSportsIDs.contains(SportsFollowSyncRecord.identity(kind: .competition, displayName: $0))
            } == true
    }

    private var sportsFollowAccessibilityHint: String {
        #if os(tvOS)
            AppStrings.Dashboard.sportsFollowHintTV
        #else
            AppStrings.Dashboard.sportsFollowHint
        #endif
    }

    var body: some View {
        Button { onSelectChannel(event.channel) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    if event.isSportsFixture {
                        Image(systemName: "sportscourt.fill")
                            .font(.caption2)
                    }
                    Circle()
                        .fill(event.program.isPlayingNow ? AppColors.live : AppColors.primary)
                        .frame(width: 8, height: 8)
                    Text(event.program.isPlayingNow ? AppStrings.Dashboard.nowAiring : event.program.formattedStartTime(locale: locale))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                    Spacer(minLength: 8)
                    if event.isSportsFixture {
                        Image(systemName: isFollowedSportsMatch ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(isFollowedSportsMatch ? AppColors.warningGold : AppColors.textPrimary.opacity(0.78))
                            .accessibilityHidden(true)
                    }
                    Image(systemName: "play.fill")
                        .font(.caption2)
                }
                .foregroundStyle(AppColors.textPrimary.opacity(0.78))

                Text(event.program.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)

                Text(event.channel.title)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)

                Text(event.program.formattedTimeRange(locale: locale))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppColors.textSecondary.opacity(0.8))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 154, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.surfaceSecondary, AppColors.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(AppColors.borderSubtle, lineWidth: 1)
                    }
            }
        }
        #if os(tvOS)
        .tvFocusEffect(shape: .roundedRectangle(cornerRadius: 18))
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(event.isSportsFixture ? sportsFollowAccessibilityHint : AppStrings.Common.watchNow)
        .contextMenu {
            if event.isSportsFixture {
                Button("Kanala elle eşle", systemImage: "magnifyingglass", action: onChooseChannel)
                if let fixture = SportsHubManager.fixtureIdentity(
                    program: event.program,
                    channelTitle: event.channel.title
                ) {
                    let homeID = SportsFollowSyncRecord.identity(kind: .team, displayName: fixture.homeTeam)
                    Button {
                        onToggleSportsFollow(.team, fixture.homeTeam)
                    } label: {
                        Label(
                            followedSportsIDs.contains(homeID)
                                ? AppStrings.Dashboard.unfollowSportsTeam(fixture.homeTeam)
                                : AppStrings.Dashboard.followSportsTeam(fixture.homeTeam),
                            systemImage: followedSportsIDs.contains(homeID) ? "star.slash" : "star"
                        )
                    }
                    .disabled(pendingSportsFollowIDs.contains(homeID))

                    let awayID = SportsFollowSyncRecord.identity(kind: .team, displayName: fixture.awayTeam)
                    Button {
                        onToggleSportsFollow(.team, fixture.awayTeam)
                    } label: {
                        Label(
                            followedSportsIDs.contains(awayID)
                                ? AppStrings.Dashboard.unfollowSportsTeam(fixture.awayTeam)
                                : AppStrings.Dashboard.followSportsTeam(fixture.awayTeam),
                            systemImage: followedSportsIDs.contains(awayID) ? "star.slash" : "star"
                        )
                    }
                    .disabled(pendingSportsFollowIDs.contains(awayID))

                    if let competition = fixture.competition {
                        let competitionID = SportsFollowSyncRecord.identity(
                            kind: .competition,
                            displayName: competition
                        )
                        Button {
                            onToggleSportsFollow(.competition, competition)
                        } label: {
                            Label(
                                followedSportsIDs.contains(competitionID)
                                    ? AppStrings.Dashboard.unfollowSportsCompetition(competition)
                                    : AppStrings.Dashboard.followSportsCompetition(competition),
                                systemImage: followedSportsIDs.contains(competitionID) ? "star.slash" : "star"
                            )
                        }
                        .disabled(pendingSportsFollowIDs.contains(competitionID))
                    }
                }
            }
            if !event.alternateChannels.isEmpty {
                ForEach(event.alternateChannels) { channel in
                    Button {
                        onSelectChannel(channel)
                    } label: {
                        Label(channel.title, systemImage: "play.tv")
                    }
                }
            }
        }
    }
}

struct DashboardEPGChannelPicker: View {
    @State private var searchText = ""
    let channels: [MediaModels.Item]
    let onSelect: (MediaModels.Item) -> Void
    let onCancel: () -> Void

    private var filteredChannels: [MediaModels.Item] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return channels }
        return channels.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(filteredChannels) { channel in
                Button {
                    onSelect(channel)
                } label: {
                    Label(channel.title, systemImage: "play.tv")
                }
            }
            .searchable(text: $searchText, prompt: "Kanal ara")
            .navigationTitle("Spor yayını için kanal seç")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.Common.cancel, action: onCancel)
                }
            }
        }
    }
}
