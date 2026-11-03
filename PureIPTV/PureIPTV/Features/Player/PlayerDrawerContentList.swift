import ComposableArchitecture
import SwiftUI

// MARK: - Player Drawer Content List

/// Isolated channel list view for the player sidebar drawer.
/// Prevents full drawer re-evaluation during playback time/status updates.
struct PlayerDrawerContentList: View {
    let channels: [PlayerFeature.PlayableItem]
    let currentItemID: String
    let previousChannelID: String?
    let isCleaningEnabled: Bool
    let channelSortOption: ChannelSortOption
    let channelWatchCounts: [String: Int]
    let showTwoLineTitles: Bool
    let preferredFocusID: String?
    @FocusState.Binding var focusedItemID: String?
    let onSelect: (PlayerFeature.PlayableItem) -> Void
    let onHide: (String, String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(channels.enumerated()), id: \.element.id) { index, item in
                        let isCurrent = item.id == currentItemID
                        let isPrevious = item.id == previousChannelID

                        PlayerDrawerChannelRow(
                            item: item,
                            index: index + 1,
                            isCurrent: isCurrent,
                            isPrevious: isPrevious,
                            isCleaningEnabled: isCleaningEnabled,
                            channelSortOption: channelSortOption,
                            watchCount: channelWatchCounts[item.id],
                            showTwoLineTitles: showTwoLineTitles,
                            onSelect: {
                                onSelect(item)
                            },
                            onHide: {
                                onHide(item.id, item.title)
                            }
                        )
                        .focused($focusedItemID, equals: item.id)
                        .id(item.id)
                    }
                }
                #if os(tvOS)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                #else
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                #endif
            }
            .onAppear {
                guard let restorationID = preferredFocusID else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    guard focusedItemID == restorationID,
                          channels.contains(where: { $0.id == restorationID })
                    else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(restorationID, anchor: .center)
                    }
                }
            }
        }
    }
}
