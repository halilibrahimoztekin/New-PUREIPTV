#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - tvOS Dashboard Sports Hub Shelf

    /// Sports Hub shelf for live matches, fixture cards, and team follow filtering on Apple TV.
    public struct DashboardSportsHubShelf_tvOS: View {
        public let store: StoreOf<DashboardFeature>
        @Binding public var isShowingFollowedSportsEvents: Bool

        public init(
            store: StoreOf<DashboardFeature>,
            isShowingFollowedSportsEvents: Binding<Bool>
        ) {
            self.store = store
            _isShowingFollowedSportsEvents = isShowingFollowedSportsEvents
        }

        private var sportsHubEventGroupsForDisplay: [DashboardFeature.SportsHubEventGroup] {
            isShowingFollowedSportsEvents ? store.followedSportsHubEventGroups : store.sportsHubEventGroups
        }

        public var body: some View {
            let eventGroups = sportsHubEventGroupsForDisplay

            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    Text(AppStrings.Dashboard.epgPrograms)
                        .font(AppFonts.displayMedium)
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
                        .font(AppFonts.button)
                        .frame(minHeight: 52)
                        .tvFocusEffect(shape: .capsule)
                    }
                }
                .padding(.horizontal, 60)

                if eventGroups.isEmpty {
                    Text(AppStrings.Dashboard.noFollowedSportsEvents)
                        .font(AppFonts.titleSmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 60)
                        .padding(.vertical, 24)
                } else {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(eventGroups) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(group.title ?? AppStrings.Dashboard.otherSportsMatches)
                                    .font(AppFonts.title)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .accessibilityAddTraits(.isHeader)
                                    .padding(.horizontal, 60)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 40) {
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
                                            .frame(width: 380)
                                        }
                                    }
                                    .padding(.horizontal, 60)
                                    .padding(.vertical, 24)
                                }
                                .focusSection()
                            }
                        }
                    }
                }
            }
        }
    }
#endif
