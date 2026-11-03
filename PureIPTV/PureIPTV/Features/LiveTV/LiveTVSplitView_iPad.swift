import ComposableArchitecture
import SwiftUI

#if os(iOS)

    // MARK: - Live TV iPad Split View Coordinator

    /// Three-column coordinator view for iPad displaying Category Sidebar,
    /// Channel List, and Detail/EPG viewer.
    public struct LiveTVSplitView_iPad: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        let config: PlaylistConfig

        @State private var categorySearchQuery: String = ""
        @State private var channelSearchQuery: String = ""

        public init(store: StoreOf<LiveTVFeature>, config: PlaylistConfig) {
            self.store = store
            self.config = config
        }

        public var body: some View {
            HStack(spacing: 0) {
                // Column 1: Categories Sidebar
                LiveTVSidebar_iPad(
                    store: store,
                    config: config,
                    categorySearchQuery: $categorySearchQuery
                )

                Divider().background(AppColors.borderSubtle)

                // Column 2: Channel List
                LiveTVChannelList_iPad(
                    store: store,
                    channelSearchQuery: $channelSearchQuery
                )

                Divider().background(AppColors.borderSubtle)

                // Column 3: Detail Preview & EPG
                LiveTVDetail_iPad(store: store)
            }
            .onChange(of: config.playlistID) { _, _ in
                categorySearchQuery = ""
                channelSearchQuery = ""
            }
        }
    }
#endif
