import Foundation

enum SortableMediaLibrary: String {
    case movies
    case series
}

@MainActor
enum CategoryContentSortPreference {
    static func load(
        profileID: UUID?,
        playlistID: UUID?,
        library: SortableMediaLibrary,
        categoryID: String
    ) -> SortMethod? {
        guard !categoryID.isEmpty,
              let value = UserDefaults.standard.string(forKey: key(
                  profileID: profileID,
                  playlistID: playlistID,
                  library: library,
                  categoryID: categoryID
              ))
        else { return nil }

        return SortMethod(rawValue: value)
    }

    static func save(
        _ method: SortMethod,
        profileID: UUID?,
        playlistID: UUID?,
        library: SortableMediaLibrary,
        categoryID: String
    ) {
        guard !categoryID.isEmpty else { return }
        UserDefaults.standard.set(
            method.rawValue,
            forKey: key(profileID: profileID, playlistID: playlistID, library: library, categoryID: categoryID)
        )
    }

    static func reset(
        profileID: UUID?,
        playlistID: UUID?,
        library: SortableMediaLibrary,
        categoryID: String
    ) {
        guard !categoryID.isEmpty else { return }
        UserDefaults.standard.removeObject(
            forKey: key(profileID: profileID, playlistID: playlistID, library: library, categoryID: categoryID)
        )
    }

    private static func key(
        profileID: UUID?,
        playlistID: UUID?,
        library: SortableMediaLibrary,
        categoryID: String
    ) -> String {
        let profileScope = profileID?.uuidString ?? "legacy"
        let playlistScope = playlistID?.uuidString ?? "default"
        return "com.pureiptv.categoryContentSort.v1.\(library.rawValue).\(profileScope).\(playlistScope).\(categoryID.utf8.count):\(categoryID)"
    }
}
