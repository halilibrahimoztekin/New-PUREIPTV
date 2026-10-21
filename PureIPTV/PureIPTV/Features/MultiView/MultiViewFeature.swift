import ComposableArchitecture
import Foundation

// MARK: - MultiView Layout Modes

public enum MultiViewLayoutMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case showcase1Plus3 = "1+3" // 1 Large Main + 3 Right Sub-views (Showcase)
    case grid2x2 = "2x2" // 2x2 Equal Quad Grid
    case dual1Plus1 = "1+1" // Side-by-side Dual Split

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .showcase1Plus3: AppStrings.MultiView.layoutShowcase
        case .grid2x2: AppStrings.MultiView.layoutGrid
        case .dual1Plus1: AppStrings.MultiView.layoutDual
        }
    }

    public var iconName: String {
        switch self {
        case .showcase1Plus3: "rectangle.righthalf.inset.filled"
        case .grid2x2: "square.grid.2x2"
        case .dual1Plus1: "rectangle.split.2x1"
        }
    }

    public var requiredSlotCount: Int {
        switch self {
        case .showcase1Plus3, .grid2x2: 4
        case .dual1Plus1: 2
        }
    }
}

// MARK: - MultiView Slot Model

public struct MultiViewSlot: Equatable, Identifiable {
    public let id: Int
    public var item: MediaModels.Item?
    public var isLoading: Bool = false
    public var errorMessage: String?

    /// UUID to differentiate instances even when item changes
    public var instanceID: UUID = .init()

    public init(id: Int, item: MediaModels.Item? = nil) {
        self.id = id
        self.item = item
    }
}

// MARK: - MultiView Reducer

@Reducer
public struct MultiViewFeature {
    @ObservableState
    public struct State: Equatable {
        public var layoutMode: MultiViewLayoutMode = .showcase1Plus3
        public var layoutSize: Int = 4 // 2, 4, or 9 (Compatibility)
        public var primarySlotID: Int = 0

        public var slots: [MultiViewSlot] = [
            MultiViewSlot(id: 0),
            MultiViewSlot(id: 1),
            MultiViewSlot(id: 2),
            MultiViewSlot(id: 3),
        ]

        public var activeAudioSlotID: Int? = 0

        // PiP & Fullscreen
        public var focusedSlotID: Int?
        public var isPiPActive: Bool = false

        // Playlist selection
        public var isSelectingChannelForSlotID: Int?
        public var channels: [MediaModels.Item] = []

        public init(channels: [MediaModels.Item] = []) {
            self.channels = channels
        }
    }

    public enum Action {
        case onAppear
        case setLayoutMode(MultiViewLayoutMode)
        case swapToPrimary(slotID: Int)
        case setAudioActive(slotID: Int)
        case toggleAudioMute
        case selectChannelTapped(slotID: Int)
        case channelSelected(MediaModels.Item)
        case channelSelectionDismissed
        case removeChannelTapped(slotID: Int)
        case changeLayout(Int)
        case toggleFullscreen(slotID: Int)
        case togglePiP

        case delegate(Delegate)
        public enum Delegate: Equatable {
            case close
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case let .setLayoutMode(mode):
                state.layoutMode = mode
                state.layoutSize = mode.requiredSlotCount
                while state.slots.count < mode.requiredSlotCount {
                    state.slots.append(MultiViewSlot(id: state.slots.count))
                }
                return .none

            case let .swapToPrimary(slotID):
                guard slotID != state.primarySlotID else { return .none }
                guard let primaryIndex = state.slots.firstIndex(where: { $0.id == state.primarySlotID }),
                      let targetIndex = state.slots.firstIndex(where: { $0.id == slotID })
                else {
                    return .none
                }

                // Swap items between primary and target slots
                let tempItem = state.slots[primaryIndex].item
                state.slots[primaryIndex].item = state.slots[targetIndex].item
                state.slots[primaryIndex].instanceID = UUID()
                state.slots[targetIndex].item = tempItem
                state.slots[targetIndex].instanceID = UUID()

                // Immediately switch audio focus to primary showcase screen
                state.activeAudioSlotID = state.primarySlotID
                return .none

            case let .setAudioActive(slotID):
                state.activeAudioSlotID = slotID
                return .none

            case .toggleAudioMute:
                if state.activeAudioSlotID != nil {
                    state.activeAudioSlotID = nil
                } else {
                    state.activeAudioSlotID = state.primarySlotID
                }
                return .none

            case let .selectChannelTapped(slotID):
                state.isSelectingChannelForSlotID = slotID
                return .none

            case let .channelSelected(item):
                guard let slotID = state.isSelectingChannelForSlotID else { return .none }
                if let index = state.slots.firstIndex(where: { $0.id == slotID }) {
                    state.slots[index].item = item
                    state.slots[index].instanceID = UUID() // Force new player

                    // If no audio is active, make this one active
                    if state.activeAudioSlotID == nil {
                        state.activeAudioSlotID = slotID
                    }
                }
                state.isSelectingChannelForSlotID = nil
                return .none

            case .channelSelectionDismissed:
                state.isSelectingChannelForSlotID = nil
                return .none

            case let .removeChannelTapped(slotID):
                if let index = state.slots.firstIndex(where: { $0.id == slotID }) {
                    state.slots[index].item = nil
                    state.slots[index].instanceID = UUID()
                }
                if state.activeAudioSlotID == slotID {
                    state.activeAudioSlotID = state.slots.first(where: { $0.item != nil })?.id
                }
                return .none

            case let .changeLayout(size):
                state.layoutSize = size
                if size == 2 {
                    state.layoutMode = .dual1Plus1
                } else if size == 4 {
                    state.layoutMode = .grid2x2
                }
                // Adjust slots count
                if state.slots.count < size {
                    let diff = size - state.slots.count
                    let startID = state.slots.count
                    for i in 0 ..< diff {
                        state.slots.append(MultiViewSlot(id: startID + i))
                    }
                } else if state.slots.count > size {
                    state.slots = Array(state.slots.prefix(size))
                    if let active = state.activeAudioSlotID, active >= size {
                        state.activeAudioSlotID = 0
                    }
                }
                return .none

            case let .toggleFullscreen(slotID):
                if state.focusedSlotID == slotID {
                    state.focusedSlotID = nil // Exit fullscreen
                } else {
                    state.focusedSlotID = slotID // Enter fullscreen
                    state.activeAudioSlotID = slotID
                }
                return .none

            case .togglePiP:
                state.isPiPActive.toggle()
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
