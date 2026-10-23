import Foundation
import SwiftUI

// MARK: - Smart Channel Sorting Options (Madde #12)

public enum ChannelSortOption: String, CaseIterable, Identifiable, Codable, Sendable {
    case defaultOrder = "default"
    case nameAscending = "name_asc"
    case nameDescending = "name_desc"
    case mostWatched = "most_watched"
    case recentlyWatched = "recently_watched"

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .defaultOrder:
            AppStrings.LiveTV.sortDefault
        case .nameAscending:
            AppStrings.LiveTV.sortNameAZ
        case .nameDescending:
            AppStrings.LiveTV.sortNameZA
        case .mostWatched:
            AppStrings.LiveTV.sortMostWatched
        case .recentlyWatched:
            AppStrings.LiveTV.sortRecentlyWatched
        }
    }

    public var icon: String {
        switch self {
        case .defaultOrder:
            "list.number"
        case .nameAscending:
            "arrow.up.circle.fill"
        case .nameDescending:
            "arrow.down.circle.fill"
        case .mostWatched:
            "flame.fill"
        case .recentlyWatched:
            "clock.arrow.circlepath"
        }
    }

    public var accentColor: Color {
        switch self {
        case .defaultOrder:
            Color(hex: "#0A84FF")
        case .nameAscending, .nameDescending:
            Color(hex: "#30D158")
        case .mostWatched:
            Color(hex: "#FF9F0A")
        case .recentlyWatched:
            Color(hex: "#BF5AF2")
        }
    }

    /// Generic sorting engine for channels
    public func sort<T>(
        items: [T],
        playlist: [T]? = nil,
        idKeyPath: KeyPath<T, String>,
        titleKeyPath: KeyPath<T, String>,
        watchCounts: [String: Int] = [:],
        recentIDs: [String] = []
    ) -> [T] {
        switch self {
        case .defaultOrder:
            guard let playlist else { return items }
            let orderMap: [String: Int] = Dictionary(
                uniqueKeysWithValues: playlist.enumerated().map { ($0.element[keyPath: idKeyPath], $0.offset) }
            )
            return items.sorted {
                let idx1 = orderMap[$0[keyPath: idKeyPath]] ?? Int.max
                let idx2 = orderMap[$1[keyPath: idKeyPath]] ?? Int.max
                return idx1 < idx2
            }

        case .nameAscending:
            return items.sorted {
                $0[keyPath: titleKeyPath].localizedCaseInsensitiveCompare($1[keyPath: titleKeyPath]) == .orderedAscending
            }

        case .nameDescending:
            return items.sorted {
                $0[keyPath: titleKeyPath].localizedCaseInsensitiveCompare($1[keyPath: titleKeyPath]) == .orderedDescending
            }

        case .mostWatched:
            let defaultOrderMap: [String: Int] = {
                guard let playlist else { return [:] }
                return Dictionary(
                    uniqueKeysWithValues: playlist.enumerated().map { ($0.element[keyPath: idKeyPath], $0.offset) }
                )
            }()
            return items.sorted {
                let count1 = watchCounts[$0[keyPath: idKeyPath]] ?? 0
                let count2 = watchCounts[$1[keyPath: idKeyPath]] ?? 0
                if count1 != count2 {
                    return count1 > count2
                }
                let idx1 = defaultOrderMap[$0[keyPath: idKeyPath]] ?? 0
                let idx2 = defaultOrderMap[$1[keyPath: idKeyPath]] ?? 0
                return idx1 < idx2
            }

        case .recentlyWatched:
            let recentOrderMap: [String: Int] = Dictionary(
                uniqueKeysWithValues: recentIDs.enumerated().map { ($0.element, $0.offset) }
            )
            let defaultOrderMap: [String: Int] = {
                guard let playlist else { return [:] }
                return Dictionary(
                    uniqueKeysWithValues: playlist.enumerated().map { ($0.element[keyPath: idKeyPath], $0.offset) }
                )
            }()
            return items.sorted {
                let rec1 = recentOrderMap[$0[keyPath: idKeyPath]]
                let rec2 = recentOrderMap[$1[keyPath: idKeyPath]]
                if let r1 = rec1, let r2 = rec2 {
                    return r1 < r2
                } else if rec1 != nil {
                    return true
                } else if rec2 != nil {
                    return false
                }
                let idx1 = defaultOrderMap[$0[keyPath: idKeyPath]] ?? 0
                let idx2 = defaultOrderMap[$1[keyPath: idKeyPath]] ?? 0
                return idx1 < idx2
            }
        }
    }
}
