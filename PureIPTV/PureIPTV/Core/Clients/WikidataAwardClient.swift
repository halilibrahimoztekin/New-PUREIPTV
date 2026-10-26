import ComposableArchitecture
@preconcurrency import Foundation

public struct WikidataAwardClient: Sendable {
    public enum ContentKind: Equatable, Sendable {
        case movie
        case series
    }

    public enum RecognitionKind: String, Equatable, Sendable {
        case winner
        case nominee
    }

    public struct Recognition: Equatable, Sendable {
        public let tmdbID: Int
        public let recognitionCount: Int
        public let kind: RecognitionKind

        public nonisolated init(tmdbID: Int, recognitionCount: Int, kind: RecognitionKind) {
            self.tmdbID = tmdbID
            self.recognitionCount = recognitionCount
            self.kind = kind
        }
    }

    public var fetchRecognitions: @Sendable (_ tmdbIDs: [Int], _ contentKind: ContentKind) async throws -> [Recognition]
}

extension WikidataAwardClient: DependencyKey {
    public nonisolated static let liveValue: WikidataAwardClient = .init(
        fetchRecognitions: { tmdbIDs, contentKind in
            let ids = Array(Set(tmdbIDs.filter { $0 > 0 }).prefix(40))
            guard !ids.isEmpty else { return [] }

            let idValues = ids.map { "\"\($0)\"" }.joined(separator: " ")
            let tmdbProperty = switch contentKind {
            case .movie: "P4947"
            case .series: "P4983"
            }
            let query = """
            SELECT ?tmdbID ?kind (COUNT(DISTINCT ?award) AS ?awardCount) WHERE {
              VALUES ?tmdbID { \(idValues) }
              ?work wdt:\(tmdbProperty) ?tmdbID.
              {
                ?work wdt:P166 ?award.
                BIND("winner" AS ?kind)
              } UNION {
                ?work wdt:P1411 ?award.
                BIND("nominee" AS ?kind)
              }
            }
            GROUP BY ?tmdbID ?kind
            LIMIT 500
            """

            guard var components = URLComponents(string: "https://query.wikidata.org/sparql") else {
                throw URLError(.badURL)
            }
            components.queryItems = [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "format", value: "json"),
            ]
            guard let url = components.url else { throw URLError(.badURL) }

            var request = URLRequest(url: url, timeoutInterval: 15)
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            request.setValue(
                "PureIPTV/\(appVersion) (https://apps.apple.com/app/id6746409727)",
                forHTTPHeaderField: "User-Agent"
            )
            request.setValue("application/sparql-results+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200 ... 299).contains(response.statusCode)
            else { throw URLError(.badServerResponse) }

            let decoded = try JSONDecoder().decode(SPARQLResponse.self, from: data)
            return decoded.results.bindings.compactMap { binding in
                guard
                    let tmdbID = Int(binding.tmdbID.value),
                    let kind = RecognitionKind(rawValue: binding.kind.value),
                    let recognitionCount = Int(binding.awardCount.value), recognitionCount > 0
                else { return nil }
                return Recognition(
                    tmdbID: tmdbID,
                    recognitionCount: recognitionCount,
                    kind: kind
                )
            }
        }
    )

    private struct SPARQLResponse: Decodable {
        struct Results: Decodable {
            struct Binding: Decodable {
                struct Value: Decodable {
                    let value: String
                }

                let tmdbID: Value
                let kind: Value
                let awardCount: Value

                private enum CodingKeys: String, CodingKey {
                    case tmdbID
                    case kind
                    case awardCount
                }
            }

            let bindings: [Binding]
        }

        let results: Results
    }
}

public extension DependencyValues {
    var wikidataAwardClient: WikidataAwardClient {
        get { self[WikidataAwardClient.self] }
        set { self[WikidataAwardClient.self] = newValue }
    }
}
