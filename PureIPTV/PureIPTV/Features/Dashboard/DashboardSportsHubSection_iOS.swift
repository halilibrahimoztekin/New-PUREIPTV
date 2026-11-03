#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Dashboard Sports Hub Section (iOS)

    public struct DashboardSportsHubSection_iOS: View {
        @Bindable var store: StoreOf<DashboardFeature>
        @State private var isShowingFollowedSportsEvents = false

        public init(store: StoreOf<DashboardFeature>) {
            self.store = store
        }

        private var sportsHubEventGroupsForDisplay: [DashboardFeature.SportsHubEventGroup] {
            isShowingFollowedSportsEvents ? store.followedSportsHubEventGroups : store.sportsHubEventGroups
        }

        public var body: some View {
            let eventGroups = sportsHubEventGroupsForDisplay

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(AppStrings.Dashboard.epgPrograms)
                        .font(AppFonts.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    if !store.followedSportsIDs.isEmpty || isShowingFollowedSportsEvents {
                        Button {
                            isShowingFollowedSportsEvents.toggle()
                        } label: {
                            Label(
                                isShowingFollowedSportsEvents
                                    ? AppStrings.Dashboard.showAllSportsEvents
                                    : AppStrings.Dashboard.showFollowedSportsEvents,
                                systemImage: isShowingFollowedSportsEvents ? "line.3.horizontal.decrease.circle.fill" : "star"
                            )
                        }
                        .buttonStyle(.bordered)
                        .tint(isShowingFollowedSportsEvents ? AppColors.warningGold : AppColors.textPrimary)
                        .padding(.trailing, 16)
                    }
                }
                .padding(.leading, 16)

                if eventGroups.isEmpty {
                    Text(AppStrings.Dashboard.noFollowedSportsEvents)
                        .font(AppFonts.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(eventGroups) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.title ?? AppStrings.Dashboard.otherSportsMatches)
                                    .font(AppFonts.captionSemibold)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .accessibilityAddTraits(.isHeader)
                                    .padding(.horizontal, 16)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 16) {
                                        ForEach(group.events) { event in
                                            DashboardEPGEventCard(
                                                event: event,
                                                followedSportsIDs: store.followedSportsIDs,
                                                pendingSportsFollowIDs: Set(store.pendingSportsFollowIDs.keys),
                                                onToggleSportsFollow: { kind, name in
                                                    store.send(.toggleSportsFollow(kind: kind, displayName: name))
                                                },
                                                onSelectChannel: { store.send(.channelSelected($0)) },
                                                onChooseChannel: {
                                                    guard let playlistID = store.activePlaylistID else { return }
                                                    store.send(.delegate(.presentEPGChannelPicker(playlistID: playlistID, event: event)))
                                                }
                                            )
                                            .frame(width: 260)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
#endif
