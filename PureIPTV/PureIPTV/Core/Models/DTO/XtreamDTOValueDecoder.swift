import Foundation

enum XtreamDTOValueDecoder {
    static func categoryID<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> String {
        if let value = try? container.decode(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return String(value)
        }
        // Providers sometimes omit category_id or return null. Keep the item
        // in unfiltered catalog results instead of failing the entire payload.
        return ""
    }
}
