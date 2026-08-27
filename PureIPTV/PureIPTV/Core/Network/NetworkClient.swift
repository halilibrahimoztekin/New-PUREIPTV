import Foundation

public struct NetworkClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        decoder = JSONDecoder()
        // Some APIs return empty arrays instead of objects on failure or empty results
        // Also might need date decoding strategies depending on API format.
    }

    public func fetch<T: Decodable>(url: URL) async throws -> T {
        #if DEBUG
            print("🌐 [NETWORK REQUEST] -> \(url.absoluteString)")
            let startTime = CFAbsoluteTimeGetCurrent()
        #endif

        let (data, response) = try await session.data(from: url)

        #if DEBUG
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        #endif

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        #if DEBUG
            let statusCode = httpResponse.statusCode
            let icon = (200 ... 299).contains(statusCode) ? "✅" : "❌"
            print("\(icon) [NETWORK RESPONSE] <- [\(statusCode)] \(url.absoluteString) (⏱ \(String(format: "%.2f", timeElapsed))s)")

            // IPTV responses can be massive (e.g., 50MB). To prevent Xcode from freezing, we truncate the log output.
            if let jsonString = String(data: data, encoding: .utf8) {
                let maxLogLength = 1000
                if jsonString.count > maxLogLength {
                    let preview = String(jsonString.prefix(maxLogLength))
                    print("📦 [DATA PREVIEW]:\n\(preview)\n... [Truncated, total \(data.count) bytes]")
                } else {
                    print("📦 [DATA]:\n\(jsonString)")
                }
            }
        #endif

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            // Xtream usually returns 200 even for auth errors, but just in case
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw NetworkError.unauthorized
            }
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }

        do {
            return try await Task.detached(priority: .userInitiated) {
                try decoder.decode(T.self, from: data)
            }.value
        } catch let DecodingError.dataCorrupted(context) {
            throw NetworkError.decodingFailed(description: "Data corrupted: \(context.debugDescription)")
        } catch let DecodingError.keyNotFound(key, context) {
            throw NetworkError.decodingFailed(description: "Key '\(key.stringValue)' not found: \(context.debugDescription)")
        } catch let DecodingError.valueNotFound(value, context) {
            throw NetworkError.decodingFailed(description: "Value '\(value)' not found: \(context.debugDescription)")
        } catch let DecodingError.typeMismatch(type, context) {
            throw NetworkError.decodingFailed(description: "Type '\(type)' mismatch: \(context.debugDescription)")
        } catch {
            throw NetworkError.decodingFailed(description: error.localizedDescription)
        }
    }
}
