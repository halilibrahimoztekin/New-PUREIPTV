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
    public let categories: [String]
    public let artworkURL: URL?

    public init(
        channelID: String,
        title: String,
        description: String,
        start: Date,
        end: Date,
        categories: [String] = [],
        artworkURL: URL? = nil
    ) {
        self.channelID = channelID
        self.title = title
        self.description = description
        self.start = start
        self.end = end
        self.categories = categories
        self.artworkURL = artworkURL
    }
}

public struct XMLTVData: Sendable {
    public let channels: [String: XMLTVChannel]
    public let programmes: [String: [XMLTVProgramme]] // Grouped by channel ID
}

enum XMLTVParserError: LocalizedError {
    case resourceLimitExceeded

    var errorDescription: String? {
        AppStrings.Errors.invalidXMLTVSource
    }
}

final nonisolated class XMLTVParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {
    private static let maximumChannelCount = 20000
    private static let maximumProgrammeCount = 200_000
    private static let maximumProgrammesPerChannel = 8000
    private static let maximumElementDepth = 64
    private static let maximumElementCount = 2_000_000
    private static let maximumRetainedTextBytes = 48 * 1024 * 1024
    private static let maximumChannelIDBytes = 512
    private static let maximumChannelNameBytes = 4 * 1024
    private static let maximumTitleBytes = 4 * 1024
    private static let maximumDescriptionBytes = 16 * 1024
    private static let maximumCategoryBytes = 512
    private static let maximumCategoryCount = 16
    private static let maximumArtworkURLBytes = 4 * 1024
    private static let maximumProgrammeDateBytes = 128

    private var channels: [String: XMLTVChannel] = [:]
    private var programmes: [String: [XMLTVProgramme]] = [:]
    private var parsedProgrammeCount = 0
    private var parsedElementCount = 0
    private var retainedTextBytes = 0
    private var didExceedResourceLimits = false

    private var currentElement: String = ""
    private var elementStack: [String] = []
    private var currentChannelID: String?
    private var currentChannelName: String = ""
    private var currentChannelIcon: String?

    private var currentProgrammeChannelID: String?
    private var currentProgrammeStart: Date?
    private var currentProgrammeEnd: Date?
    private var currentProgrammeTitle: String = ""
    private var currentProgrammeDesc: String = ""
    private var currentProgrammeCategories: [String] = []
    private var currentProgrammeCategoryText: String = ""
    private var currentProgrammeArtworkURL: URL?
    private var currentProgrammeImageText: String = ""
    private var isReadingProgrammeImage = false
    private var hasSeenRootElement = false
    private var hasValidXMLTVRoot = false

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

    nonisolated func containsValidXMLTVRoot() -> Bool {
        hasSeenRootElement && hasValidXMLTVRoot
    }

    nonisolated func exceededResourceLimits() -> Bool {
        didExceedResourceLimits
    }

    private func reserveText(_ text: String, maximumBytes: Int, parser: XMLParser) -> Bool {
        let byteCount = text.utf8.count
        guard byteCount <= maximumBytes,
              byteCount <= Self.maximumRetainedTextBytes - retainedTextBytes
        else {
            abortForResourceLimit(parser)
            return false
        }
        retainedTextBytes += byteCount
        return true
    }

    private func appendBoundedText(
        _ text: String,
        to destination: inout String,
        maximumBytes: Int,
        parser: XMLParser
    ) {
        let currentByteCount = destination.utf8.count
        let appendedByteCount = text.utf8.count
        guard appendedByteCount <= maximumBytes - currentByteCount,
              appendedByteCount <= Self.maximumRetainedTextBytes - retainedTextBytes
        else {
            abortForResourceLimit(parser)
            return
        }
        destination.append(text)
        retainedTextBytes += appendedByteCount
    }

    private func abortForResourceLimit(_ parser: XMLParser) {
        didExceedResourceLimits = true
        parser.abortParsing()
    }

    private func abortIfCancelled(_ parser: XMLParser) -> Bool {
        guard Task.isCancelled else { return false }
        parser.abortParsing()
        return true
    }

    nonisolated func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI _: String?, qualifiedName _: String?, attributes attributeDict: [String: String] = [:]) {
        guard !abortIfCancelled(parser) else { return }
        guard elementStack.count < Self.maximumElementDepth,
              parsedElementCount < Self.maximumElementCount
        else {
            abortForResourceLimit(parser)
            return
        }
        parsedElementCount += 1

        let parentElement = elementStack.last
        if !hasSeenRootElement {
            hasSeenRootElement = true
            hasValidXMLTVRoot = elementName == "tv"
        }
        currentElement = elementName

        if elementName == "channel" {
            if let channelID = attributeDict["id"] {
                guard reserveText(channelID, maximumBytes: Self.maximumChannelIDBytes, parser: parser) else { return }
                currentChannelID = channelID
            } else {
                currentChannelID = nil
            }
            currentChannelName = ""
            currentChannelIcon = nil
        } else if elementName == "icon", parentElement == "channel", currentChannelID != nil {
            if let source = attributeDict["src"] {
                guard reserveText(source, maximumBytes: Self.maximumArtworkURLBytes, parser: parser) else { return }
                currentChannelIcon = source
            }
        } else if elementName == "programme" {
            currentProgrammeChannelID = attributeDict["channel"]
            currentProgrammeStart = nil
            currentProgrammeEnd = nil
            if let channelID = currentProgrammeChannelID {
                guard reserveText(channelID, maximumBytes: Self.maximumChannelIDBytes, parser: parser) else { return }
            }
            if let startStr = attributeDict["start"] {
                guard reserveText(startStr, maximumBytes: Self.maximumProgrammeDateBytes, parser: parser) else { return }
                currentProgrammeStart = parseDate(startStr)
            }
            if let stopStr = attributeDict["stop"] {
                guard reserveText(stopStr, maximumBytes: Self.maximumProgrammeDateBytes, parser: parser) else { return }
                currentProgrammeEnd = parseDate(stopStr)
            }
            currentProgrammeTitle = ""
            currentProgrammeDesc = ""
            currentProgrammeCategories = []
            currentProgrammeCategoryText = ""
            currentProgrammeArtworkURL = nil
            currentProgrammeImageText = ""
            isReadingProgrammeImage = false
        } else if elementName == "icon", parentElement == "programme", currentProgrammeArtworkURL == nil {
            if let source = attributeDict["src"] {
                guard reserveText(source, maximumBytes: Self.maximumArtworkURLBytes, parser: parser) else { return }
            }
            currentProgrammeArtworkURL = EPGArtworkURL.parse(attributeDict["src"])
        } else if elementName == "image" {
            currentProgrammeImageText = ""
            isReadingProgrammeImage = parentElement == "programme" && currentProgrammeChannelID != nil
        } else if elementName == "category", currentProgrammeChannelID != nil {
            currentProgrammeCategoryText = ""
        }
        elementStack.append(elementName)
    }

    nonisolated func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !abortIfCancelled(parser) else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "display-name":
            if currentChannelID != nil {
                appendBoundedText(string, to: &currentChannelName, maximumBytes: Self.maximumChannelNameBytes, parser: parser)
            }
        case "title":
            if currentProgrammeChannelID != nil {
                appendBoundedText(string, to: &currentProgrammeTitle, maximumBytes: Self.maximumTitleBytes, parser: parser)
            }
        case "desc":
            if currentProgrammeChannelID != nil {
                appendBoundedText(string, to: &currentProgrammeDesc, maximumBytes: Self.maximumDescriptionBytes, parser: parser)
            }
        case "category":
            if currentProgrammeChannelID != nil {
                appendBoundedText(string, to: &currentProgrammeCategoryText, maximumBytes: Self.maximumCategoryBytes, parser: parser)
            }
        case "image":
            if isReadingProgrammeImage {
                appendBoundedText(string, to: &currentProgrammeImageText, maximumBytes: Self.maximumArtworkURLBytes, parser: parser)
            }
        default:
            break
        }
    }

    nonisolated func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI _: String?, qualifiedName _: String?) {
        guard !abortIfCancelled(parser) else { return }
        if elementName == "channel" {
            if let id = currentChannelID {
                guard channels[id] != nil || channels.count < Self.maximumChannelCount else {
                    abortForResourceLimit(parser)
                    return
                }
                let name = currentChannelName.trimmingCharacters(in: .whitespacesAndNewlines)
                channels[id] = XMLTVChannel(id: id, name: name, iconURL: currentChannelIcon)
            }
            currentChannelID = nil
        } else if elementName == "programme" {
            if let channelID = currentProgrammeChannelID, let start = currentProgrammeStart, let end = currentProgrammeEnd {
                guard parsedProgrammeCount < Self.maximumProgrammeCount,
                      (programmes[channelID]?.count ?? 0) < Self.maximumProgrammesPerChannel
                else {
                    abortForResourceLimit(parser)
                    return
                }
                let title = currentProgrammeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let desc = currentProgrammeDesc.trimmingCharacters(in: .whitespacesAndNewlines)
                let programme = XMLTVProgramme(
                    channelID: channelID,
                    title: title,
                    description: desc,
                    start: start,
                    end: end,
                    categories: currentProgrammeCategories,
                    artworkURL: currentProgrammeArtworkURL
                )
                programmes[channelID, default: []].append(programme)
                parsedProgrammeCount += 1
            }
            currentProgrammeChannelID = nil
        } else if elementName == "category", currentProgrammeChannelID != nil {
            let category = currentProgrammeCategoryText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !category.isEmpty,
               !currentProgrammeCategories.contains(where: { $0.localizedCaseInsensitiveCompare(category) == .orderedSame })
            {
                guard currentProgrammeCategories.count < Self.maximumCategoryCount else {
                    abortForResourceLimit(parser)
                    return
                }
                currentProgrammeCategories.append(category)
            }
            currentProgrammeCategoryText = ""
        } else if elementName == "image" {
            if isReadingProgrammeImage, currentProgrammeArtworkURL == nil {
                currentProgrammeArtworkURL = EPGArtworkURL.parse(currentProgrammeImageText)
            }
            isReadingProgrammeImage = false
        }
        if !elementStack.isEmpty {
            elementStack.removeLast()
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
            let parsingTask = Task.detached(priority: .utility) {
                try Task.checkCancellation()
                let document = try XMLTVArchiveDecoder.decode(data)
                try Task.checkCancellation()
                let parser = XMLParser(data: document.data)
                let delegate = XMLTVParserDelegate()
                parser.delegate = delegate
                let didParse = parser.parse()
                try Task.checkCancellation()
                guard didParse else {
                    if delegate.exceededResourceLimits() {
                        throw XMLTVParserError.resourceLimitExceeded
                    }
                    if document.wasArchived {
                        throw XMLTVArchiveError.invalidOrUnsupported
                    }
                    throw NSError(domain: "XMLTVParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "XML parsing failed"])
                }
                guard delegate.containsValidXMLTVRoot() else {
                    if document.wasArchived {
                        throw XMLTVArchiveError.invalidOrUnsupported
                    }
                    throw NSError(
                        domain: "XMLTVParser",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "XMLTV document root must be <tv>."]
                    )
                }
                return delegate.getParsedData()
            }
            return try await withTaskCancellationHandler {
                try await parsingTask.value
            } onCancel: {
                parsingTask.cancel()
            }
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
