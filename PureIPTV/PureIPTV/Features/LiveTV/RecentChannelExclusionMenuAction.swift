import ComposableArchitecture
import SwiftUI

struct RecentChannelExclusionMenuAction: View {
    let store: StoreOf<LiveTVFeature>
    let channelID: String

    var body: some View {
        if let playlistID = store.channelPresentationPlaylistID,
           let profileScope = store.channelPresentationProfileScope
        {
            let isExcluded = store.excludedRecentChannelIDs.contains(channelID)
            let isCurrentScope = store.recentChannelExclusionPlaylistID == playlistID
                && store.recentChannelExclusionProfileScope == profileScope

            Button {
                store.send(.setRecentChannelExcluded(
                    channelID: channelID,
                    isExcluded: !isExcluded,
                    playlistID: playlistID,
                    profileScope: profileScope
                ))
            } label: {
                Label(
                    isExcluded ? AppStrings.LiveTV.showInRecentChannels : AppStrings.LiveTV.excludeFromRecentChannels,
                    systemImage: isExcluded ? "clock.arrow.circlepath" : "clock.badge.xmark"
                )
            }
            .disabled(
                !store.recentChannelExclusionsLoaded
                    || !isCurrentScope
                    || store.pendingRecentChannelExclusionMutations[channelID] != nil
            )
        }
    }
}
