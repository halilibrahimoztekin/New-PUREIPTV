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

/// A sort preference scoped to the live favorites for one profile and playlist.
public enum FavoriteChannelSortMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case defaultOrder
    case nameAscending
    case nameDescending
    case manual

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .defaultOrder: AppStrings.Favorites.sortDefault
        case .nameAscending: AppStrings.Favorites.sortNameAscending
        case .nameDescending: AppStrings.Favorites.sortNameDescending
        case .manual: AppStrings.Favorites.sortManual
        }
    }

    public static func orderedItems(
        _ items: [MediaModels.Item],
        mode: Self,
        providerOrder: [MediaModels.Item],
        manualIDs: [String]
    ) -> [MediaModels.Item] {
        let providerIndex = Dictionary(
            providerOrder.enumerated().map { ($0.element.id, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        switch mode {
        case .defaultOrder:
            return items.sorted {
                (providerIndex[$0.id] ?? Int.max) < (providerIndex[$1.id] ?? Int.max)
            }
        case .nameAscending, .nameDescending:
            return items.sorted { lhs, rhs in
                let comparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if comparison == .orderedSame {
                    return (providerIndex[lhs.id] ?? Int.max) < (providerIndex[rhs.id] ?? Int.max)
                }
                return mode == .nameAscending
                    ? comparison == .orderedAscending
                    : comparison == .orderedDescending
            }
        case .manual:
            var rank: [String: Int] = [:]
            for (index, id) in manualIDs.enumerated() where rank[id] == nil {
                rank[id] = index
            }
            return items.sorted { lhs, rhs in
                let left = rank[lhs.id] ?? Int.max
                let right = rank[rhs.id] ?? Int.max
                if left != right {
                    return left < right
                }
                return (providerIndex[lhs.id] ?? Int.max) < (providerIndex[rhs.id] ?? Int.max)
            }
        }
    }

    public static func normalizedManualIDs(
        favoriteIDs: Set<String>,
        providerIDs: [String],
        storedIDs: [String]
    ) -> [String] {
        var seen = Set<String>()
        var result = storedIDs.filter { favoriteIDs.contains($0) && seen.insert($0).inserted }
        result.append(contentsOf: providerIDs.filter { favoriteIDs.contains($0) && seen.insert($0).inserted })
        return result
    }
}
