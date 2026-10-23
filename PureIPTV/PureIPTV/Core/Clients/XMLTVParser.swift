import Foundation

public struct XMLTVChannel: Sendable {
    public let id: String
    public let name: String
    public let iconURL: String?
}

public struct XMLTVProgramme: Sendable {
    public let channelID: String
    public let title: String
    public let description: String
    public let start: Date
    public let end: Date
}

public struct XMLTVData: Sendable {
    public let channels: [String: XMLTVChannel]
    public let programmes: [String: [XMLTVProgramme]] // Grouped by channel ID
}

final nonisolated class XMLTVParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {
    private var channels: [String: XMLTVChannel] = [:]
    private var programmes: [String: [XMLTVProgramme]] = [:]

    private var currentElement: String = ""
    private var currentChannelID: String?
    private var currentChannelName: String = ""
    private var currentChannelIcon: String?

    private var currentProgrammeChannelID: String?
    private var currentProgrammeStart: Date?
    private var currentProgrammeEnd: Date?
    private var currentProgrammeTitle: String = ""
    private var currentProgrammeDesc: String = ""

    private static let formatters: [DateFormatter] = {
        let formats = [
            "yyyyMMddHHmmss Z",
            "yyyyMMddHHmmss zzz",
            "yyyyMMddHHmmss",
            "yyyyMMddHHmm Z",
            "yyyyMMddHHmm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        ]
        return formats.map { fmt in
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            return f
        }
    }()

    private func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let ts = Double(trimmed), ts > 1_000_000_000, ts < 2_500_000_000 {
            return Date(timeIntervalSince1970: ts)
        }
        for formatter in Self.formatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    override nonisolated init() {
        super.init()
    }

    nonisolated func getParsedData() -> XMLTVData {
        XMLTVData(channels: channels, programmes: programmes)
    }

    nonisolated func parser(_: XMLParser, didStartElement elementName: String, namespaceURI _: String?, qualifiedName _: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName

        if elementName == "channel" {
            currentChannelID = attributeDict["id"]
            currentChannelName = ""
            currentChannelIcon = nil
        } else if elementName == "icon", currentChannelID != nil {
            currentChannelIcon = attributeDict["src"]
        } else if elementName == "programme" {
            currentProgrammeChannelID = attributeDict["channel"]
            if let startStr = attributeDict["start"] {
                currentProgrammeStart = parseDate(startStr)
            }
            if let stopStr = attributeDict["stop"] {
                currentProgrammeEnd = parseDate(stopStr)
            }
            currentProgrammeTitle = ""
            currentProgrammeDesc = ""
        }
    }

    nonisolated func parser(_: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "display-name":
            if currentChannelID != nil {
                currentChannelName += string
            }
        case "title":
            if currentProgrammeChannelID != nil {
                currentProgrammeTitle += string
            }
        case "desc":
            if currentProgrammeChannelID != nil {
                currentProgrammeDesc += string
            }
        default:
            break
        }
    }

    nonisolated func parser(_: XMLParser, didEndElement elementName: String, namespaceURI _: String?, qualifiedName _: String?) {
        if elementName == "channel" {
            if let id = currentChannelID {
                let name = currentChannelName.trimmingCharacters(in: .whitespacesAndNewlines)
                channels[id] = XMLTVChannel(id: id, name: name, iconURL: currentChannelIcon)
            }
            currentChannelID = nil
        } else if elementName == "programme" {
            if let channelID = currentProgrammeChannelID, let start = currentProgrammeStart, let end = currentProgrammeEnd {
                let title = currentProgrammeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let desc = currentProgrammeDesc.trimmingCharacters(in: .whitespacesAndNewlines)
                let programme = XMLTVProgramme(channelID: channelID, title: title, description: desc, start: start, end: end)
                programmes[channelID, default: []].append(programme)
            }
            currentProgrammeChannelID = nil
        }
    }
}

public struct XMLTVParserClient: Sendable {
    public var parse: @Sendable (_ data: Data) async throws -> XMLTVData
}

import ComposableArchitecture

extension XMLTVParserClient: DependencyKey {
    public static let liveValue = XMLTVParserClient(
        parse: { data in
            try await Task.detached(priority: .userInitiated) {
                let parser = XMLParser(data: data)
                let delegate = XMLTVParserDelegate()
                parser.delegate = delegate
                if parser.parse() {
                    return delegate.getParsedData()
                } else {
                    throw NSError(domain: "XMLTVParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "XML parsing failed"])
                }
            }.value
        }
    )

    public static let testValue = XMLTVParserClient(
        parse: { _ in XMLTVData(channels: [:], programmes: [:]) }
    )
}

public extension DependencyValues {
    var xmltvParser: XMLTVParserClient {
        get { self[XMLTVParserClient.self] }
        set { self[XMLTVParserClient.self] = newValue }
    }
}
