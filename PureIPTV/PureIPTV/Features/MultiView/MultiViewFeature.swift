import ComposableArchitecture
import Foundation

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

@Reducer
public struct MultiViewFeature {
    @ObservableState
    public struct State: Equatable {
        public var layoutSize: Int = 4 // 2, 4, or 9

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
        case setAudioActive(slotID: Int)
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

            case let .setAudioActive(slotID):
                state.activeAudioSlotID = slotID
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
                // Adjust slots count
                if state.slots.count < size {
                    let diff = size - state.slots.count
                    let startID = state.slots.count
                    for i in 0 ..< diff {
                        state.slots.append(MultiViewSlot(id: startID + i))
                    }
                } else if state.slots.count > size {
                    // We need to keep only 'size' slots.
                    state.slots = Array(state.slots.prefix(size))
                    // If activeAudioSlotID is removed, set to 0
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
