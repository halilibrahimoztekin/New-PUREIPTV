import ComposableArchitecture
import Foundation
import zlib

// MARK: - Gzip Decompressor

public enum GzipDecompressor {
    public static func isGzipped(_ data: Data) -> Bool {
        data.count >= 2 && data[0] == 0x1F && data[1] == 0x8B
    }

    public static func decompress(_ data: Data) -> Data {
        guard isGzipped(data) else { return data }

        var stream = z_stream()
        var status: Int32 = inflateInit2_(&stream, 16 + MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { return data }
        defer { inflateEnd(&stream) }

        var decompressed = Data()
        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.bindMemory(to: Bytef.self).baseAddress else { return }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: base)
            stream.avail_in = uInt(data.count)

            repeat {
                stream.next_out = buffer
                stream.avail_out = uInt(bufferSize)

                status = inflate(&stream, Z_NO_FLUSH)
                if status == Z_OK || status == Z_STREAM_END {
                    let bytesRead = bufferSize - Int(stream.avail_out)
                    decompressed.append(buffer, count: bytesRead)
                }
            } while status == Z_OK
        }

        return status == Z_STREAM_END ? decompressed : data
    }
}

// MARK: - Custom EPG Models

public struct CustomEPGSource: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var url: URL
    public var isEnabled: Bool
    public var lastFetched: Date?
    public var channelCount: Int
    public var programmeCount: Int

    public init(
        id: String = UUID().uuidString,
        name: String,
        url: URL,
        isEnabled: Bool = true,
        lastFetched: Date? = nil,
        channelCount: Int = 0,
        programmeCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
        self.lastFetched = lastFetched
        self.channelCount = channelCount
        self.programmeCount = programmeCount
    }
}

public struct ChannelEPGMapping: Codable, Equatable, Identifiable, Sendable {
    public var id: String {
        channelID
    }

    public let channelID: String
    public var channelName: String
    public var customEPGChannelID: String?
    public var customSourceID: String?
    public var timeShiftHours: Int // -12 to +12 hours per-channel override

    public init(
        channelID: String,
        channelName: String,
        customEPGChannelID: String? = nil,
        customSourceID: String? = nil,
        timeShiftHours: Int = 0
    ) {
        self.channelID = channelID
        self.channelName = channelName
        self.customEPGChannelID = customEPGChannelID
        self.customSourceID = customSourceID
        self.timeShiftHours = timeShiftHours
    }
}

public struct CustomEPGChannelOption: Equatable, Identifiable, Sendable {
    public let sourceID: String
    public let sourceName: String
    public let channelID: String
    public let channelName: String

    public var id: String {
        "\(sourceID):\(channelID)"
    }

    public init(sourceID: String, sourceName: String, channelID: String, channelName: String) {
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.channelID = channelID
        self.channelName = channelName
    }
}

public struct CustomEPGRefreshFailure: Equatable, Identifiable, Sendable {
    public let sourceID: String
    public let sourceName: String
    public let message: String

    public var id: String { sourceID }

    public init(sourceID: String, sourceName: String, message: String) {
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.message = message
    }
}

public struct CustomEPGRefreshSummary: Equatable, Sendable {
    public let refreshedSourceIDs: [String]
    public let failures: [CustomEPGRefreshFailure]

    public init(refreshedSourceIDs: [String] = [], failures: [CustomEPGRefreshFailure] = []) {
        self.refreshedSourceIDs = refreshedSourceIDs
        self.failures = failures
    }
}

// MARK: - In-Memory EPG Storage Actor

public actor CustomEPGStore {
    public static let shared = CustomEPGStore()

    private var parsedSources: [String: XMLTVData] = [:]

    private init() {}

    public func setSourceData(sourceID: String, data: XMLTVData) {
        parsedSources[sourceID] = data
    }

    public func removeSourceData(sourceID: String) {
        parsedSources.removeValue(forKey: sourceID)
    }

    public func getSourceData(sourceID: String) -> XMLTVData? {
        parsedSources[sourceID]
    }

    public func getAllSourceData() -> [String: XMLTVData] {
        parsedSources
    }

    public func getAllChannels() -> [XMLTVChannel] {
        parsedSources.values.flatMap(\.channels.values)
    }

    public func getProgrammes(channelID: String) -> [XMLTVProgramme]? {
        for sourceData in parsedSources.values {
            if let progs = sourceData.programmes[channelID], !progs.isEmpty {
                return progs
            }
        }
        return nil
    }
}

// MARK: - CustomEPGMappingClient (TCA)

@DependencyClient
public struct CustomEPGMappingClient: Sendable {
    public var getSources: @Sendable () -> [CustomEPGSource] = { [] }
    public var addSource: @Sendable (_ name: String, _ url: URL) async throws -> CustomEPGSource
    public var removeSource: @Sendable (_ id: String) -> Void
    public var toggleSource: @Sendable (_ id: String, _ enabled: Bool) -> Void
    public var refreshSource: @Sendable (_ id: String) async throws -> CustomEPGSource
    public var refreshAllSources: @Sendable () async -> CustomEPGRefreshSummary = { .init() }

    public var getChannelMapping: @Sendable (_ channelID: String) -> ChannelEPGMapping?
    public var setChannelMapping: @Sendable (_ mapping: ChannelEPGMapping) -> Void
    public var removeChannelMapping: @Sendable (_ channelID: String) -> Void
    public var getAllMappings: @Sendable () -> [String: ChannelEPGMapping] = { [:] }

    public var getChannelTimeShift: @Sendable (_ channelID: String) -> Int = { _ in 0 }
    public var setChannelTimeShift: @Sendable (_ channelID: String, _ hours: Int) -> Void

    /// Catch-up clock correction is separate from EPG display correction.
    /// Positive values move the requested archive start later.
    public var getCatchupTimeShift: @Sendable (_ channelID: String) -> Int = { _ in 0 }
    public var setCatchupTimeShift: @Sendable (_ channelID: String, _ hours: Int) -> Void

    public var getGlobalTimeShift: @Sendable () -> Int = { 0 }
    public var setGlobalTimeShift: @Sendable (_ hours: Int) -> Void

    public var getAvailableEPGChannels: @Sendable () async -> [XMLTVChannel] = { [] }
    public var getAvailableEPGChannelOptions: @Sendable () async -> [CustomEPGChannelOption] = { [] }
    public var searchCachedPrograms: @Sendable (_ query: String, _ channels: [MediaModels.Item], _ limit: Int) async -> [CachedEPGProgramMatch] = { _, _, _ in [] }
    public var fetchProgramsForChannel: @Sendable (_ channelID: String, _ channelName: String, _ fallbackEPGID: String?) async -> [EPGProgram] = { _, _, _ in [] }
    public var applyTimeShift: @Sendable (_ programs: [EPGProgram], _ channelID: String) -> [EPGProgram] = { programs, _ in programs }
}

extension CustomEPGMappingClient: DependencyKey {
    public static let liveValue: CustomEPGMappingClient = {
        let defaults = UserDefaults.standard
        let sourcesKey = "com.pureiptv.customEPGSources"
        let mappingsKey = "com.pureiptv.channelEPGMappings"
        let globalShiftKey = "com.pureiptv.epgTimeShift"
        let catchupShiftsKey = "com.pureiptv.channelCatchupTimeShifts"

        @Sendable func loadSources() -> [CustomEPGSource] {
            guard let data = defaults.data(forKey: sourcesKey) else { return [] }
            return (try? JSONDecoder().decode([CustomEPGSource].self, from: data)) ?? []
        }

        @Sendable func saveSources(_ sources: [CustomEPGSource]) {
            if let data = try? JSONEncoder().encode(sources) {
                defaults.set(data, forKey: sourcesKey)
            }
        }

        @Sendable func loadMappings() -> [String: ChannelEPGMapping] {
            guard let data = defaults.data(forKey: mappingsKey) else { return [:] }
            return (try? JSONDecoder().decode([String: ChannelEPGMapping].self, from: data)) ?? [:]
        }

        @Sendable func saveMappings(_ mappings: [String: ChannelEPGMapping]) {
            if let data = try? JSONEncoder().encode(mappings) {
                defaults.set(data, forKey: mappingsKey)
            }
        }

        @Sendable func loadCatchupShifts() -> [String: Int] {
            guard let data = defaults.data(forKey: catchupShiftsKey) else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        }

        @Sendable func saveCatchupShifts(_ shifts: [String: Int]) {
            if let data = try? JSONEncoder().encode(shifts) {
                defaults.set(data, forKey: catchupShiftsKey)
            }
        }

        @Sendable func parseXMLTVData(from url: URL) async throws -> XMLTVData {
            let (rawBytes, _) = try await URLSession.shared.data(from: url)
            let decompressedBytes = GzipDecompressor.decompress(rawBytes)

            return try await Task.detached(priority: .userInitiated) {
                let parser = XMLParser(data: decompressedBytes)
                let delegate = XMLTVParserDelegate()
                parser.delegate = delegate
                if parser.parse() {
                    return delegate.getParsedData()
                } else {
                    throw NSError(domain: "CustomEPGMappingClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "XMLTV Ayrıştırma Hatası"])
                }
            }.value
        }

        return CustomEPGMappingClient(
            getSources: {
                loadSources()
            },
            addSource: { name, url in
                let parsed = try await parseXMLTVData(from: url)
                let totalChannels = parsed.channels.count
                let totalProgs = parsed.programmes.values.reduce(0) { $0 + $1.count }

                var sources = loadSources()
                let newSource = CustomEPGSource(
                    name: name,
                    url: url,
                    isEnabled: true,
                    lastFetched: .now,
                    channelCount: totalChannels,
                    programmeCount: totalProgs
                )
                sources.append(newSource)
                saveSources(sources)

                await CustomEPGStore.shared.setSourceData(sourceID: newSource.id, data: parsed)
                return newSource
            },
            removeSource: { id in
                var sources = loadSources()
                sources.removeAll(where: { $0.id == id })
                saveSources(sources)
                Task {
                    await CustomEPGStore.shared.removeSourceData(sourceID: id)
                }
            },
            toggleSource: { id, enabled in
                var sources = loadSources()
                if let idx = sources.firstIndex(where: { $0.id == id }) {
                    sources[idx].isEnabled = enabled
                    saveSources(sources)
                }
            },
            refreshSource: { id in
                guard let source = loadSources().first(where: { $0.id == id }) else {
                    throw NSError(domain: "CustomEPGMappingClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "Kaynak bulunamadı"])
                }
                let parsed = try await parseXMLTVData(from: source.url)

                var currentSources = loadSources()
                guard
                    let index = currentSources.firstIndex(where: { $0.id == id }),
                    currentSources[index].url == source.url
                else {
                    throw NSError(domain: "CustomEPGMappingClient", code: 409, userInfo: [NSLocalizedDescriptionKey: "Kaynak yenileme sırasında silindi veya adresi değişti"])
                }

                currentSources[index].lastFetched = .now
                currentSources[index].channelCount = parsed.channels.count
                currentSources[index].programmeCount = parsed.programmes.values.reduce(0) { $0 + $1.count }
                saveSources(currentSources)

                await CustomEPGStore.shared.setSourceData(sourceID: id, data: parsed)
                return currentSources[index]
            },
            refreshAllSources: {
                let sourceSnapshot = loadSources()
                var refreshedSourceIDs: [String] = []
                var failures: [CustomEPGRefreshFailure] = []

                for source in sourceSnapshot where source.isEnabled {
                    do {
                        let parsed = try await parseXMLTVData(from: source.url)
                        var currentSources = loadSources()
                        guard
                            let index = currentSources.firstIndex(where: { $0.id == source.id }),
                            currentSources[index].isEnabled,
                            currentSources[index].url == source.url
                        else { continue }

                        currentSources[index].lastFetched = .now
                        currentSources[index].channelCount = parsed.channels.count
                        currentSources[index].programmeCount = parsed.programmes.values.reduce(0) { $0 + $1.count }
                        saveSources(currentSources)
                        await CustomEPGStore.shared.setSourceData(sourceID: source.id, data: parsed)
                        refreshedSourceIDs.append(source.id)
                    } catch {
                        failures.append(CustomEPGRefreshFailure(
                            sourceID: source.id,
                            sourceName: source.name,
                            message: error.localizedDescription
                        ))
                    }
                }

                return CustomEPGRefreshSummary(
                    refreshedSourceIDs: refreshedSourceIDs,
                    failures: failures
                )
            },
            getChannelMapping: { channelID in
                let mappings = loadMappings()
                return mappings[channelID]
            },
            setChannelMapping: { mapping in
                var mappings = loadMappings()
                mappings[mapping.channelID] = mapping
                saveMappings(mappings)
            },
            removeChannelMapping: { channelID in
                var mappings = loadMappings()
                mappings.removeValue(forKey: channelID)
                saveMappings(mappings)
            },
            getAllMappings: {
                loadMappings()
            },
            getChannelTimeShift: { channelID in
                let mappings = loadMappings()
                if let channelMapping = mappings[channelID], channelMapping.timeShiftHours != 0 {
                    return channelMapping.timeShiftHours
                }
                return defaults.integer(forKey: globalShiftKey)
            },
            setChannelTimeShift: { channelID, hours in
                var mappings = loadMappings()
                if var mapping = mappings[channelID] {
                    mapping.timeShiftHours = hours
                    mappings[channelID] = mapping
                } else {
                    mappings[channelID] = ChannelEPGMapping(channelID: channelID, channelName: channelID, timeShiftHours: hours)
                }
                saveMappings(mappings)
            },
            getCatchupTimeShift: { channelID in
                loadCatchupShifts()[channelID] ?? 0
            },
            setCatchupTimeShift: { channelID, hours in
                var shifts = loadCatchupShifts()
                let boundedHours = min(12, max(-12, hours))
                if boundedHours == 0 {
                    shifts.removeValue(forKey: channelID)
                } else {
                    shifts[channelID] = boundedHours
                }
                saveCatchupShifts(shifts)
            },
            getGlobalTimeShift: {
                defaults.integer(forKey: globalShiftKey)
            },
            setGlobalTimeShift: { hours in
                defaults.set(hours, forKey: globalShiftKey)
            },
            getAvailableEPGChannels: {
                await CustomEPGStore.shared.getAllChannels()
            },
            getAvailableEPGChannelOptions: {
                let sources = loadSources().filter(\.isEnabled)
                let dataBySource = await CustomEPGStore.shared.getAllSourceData()
                var options: [CustomEPGChannelOption] = []
                for source in sources {
                    guard let channels = dataBySource[source.id]?.channels else { continue }
                    options.append(contentsOf: channels.values.map { channel in
                        CustomEPGChannelOption(
                            sourceID: source.id,
                            sourceName: source.name,
                            channelID: channel.id,
                            channelName: channel.name
                        )
                    })
                }
                return options
            },
            searchCachedPrograms: { query, channels, limit in
                guard limit > 0 else { return [] }
                let terms = query
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
                    .split(whereSeparator: \.isWhitespace)
                    .map(String.init)
                guard !terms.isEmpty else { return [] }
                let sources = loadSources().filter(\.isEnabled)
                guard !sources.isEmpty else { return [] }
                let mappings = loadMappings()
                let sourceData = await CustomEPGStore.shared.getAllSourceData()
                let now = Date()
                var results: [CachedEPGProgramMatch] = []
                var scannedProgrammes = 0

                for source in sources {
                    guard !Task.isCancelled, let data = sourceData[source.id] else { continue }
                    let epgIDByNormalizedName = Dictionary(data.channels.values.map { channel in
                        (channel.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR")), channel.id)
                    }, uniquingKeysWith: { first, _ in first })
                    var scannedChannels = 0
                    for channel in channels where channel.type == .live {
                        scannedChannels += 1
                        if scannedChannels.isMultiple(of: 64), Task.isCancelled {
                            return []
                        }
                        if scannedChannels > 20000 {
                            break
                        }
                        let mapping = mappings[channel.id]
                        if let sourceID = mapping?.customSourceID, sourceID != source.id {
                            continue
                        }
                        let names = [channel.title, mapping?.channelName ?? ""]
                            .map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR")) }
                        let preferredID = mapping?.customEPGChannelID ?? channel.epgChannelID ?? channel.id
                        let fallbackID = names.lazy.compactMap { epgIDByNormalizedName[$0] }.first
                        guard let epgID = data.programmes[preferredID] != nil ? preferredID : fallbackID,
                              let programmes = data.programmes[epgID]
                        else { continue }
                        let mappingShift = mapping?.timeShiftHours ?? 0
                        let shiftHours = mappingShift != 0 ? mappingShift : defaults.integer(forKey: globalShiftKey)
                        let shift = TimeInterval(shiftHours * 3600)
                        let shiftedPrograms = programmes.map { programme in
                            let start = programme.start.addingTimeInterval(shift)
                            let end = programme.end.addingTimeInterval(shift)
                            return EPGProgram(
                                id: "\(epgID)_\(Int(start.timeIntervalSince1970))",
                                title: programme.title,
                                description: programme.description,
                                startTime: start,
                                endTime: end,
                                isPlayingNow: start <= now && now <= end,
                                categories: programme.categories
                            )
                        }
                        for program in shiftedPrograms {
                            scannedProgrammes += 1
                            if scannedProgrammes.isMultiple(of: 64), Task.isCancelled {
                                return []
                            }
                            if scannedProgrammes > 50000 {
                                break
                            }
                            let searchable = (program.title + " " + program.description)
                                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
                            guard terms.allSatisfy({ searchable.localizedStandardContains($0) }) else { continue }
                            results.append(CachedEPGProgramMatch(program: program, channel: channel))
                            if results.count >= max(limit * 4, limit) {
                                break
                            }
                        }
                        if results.count >= max(limit * 4, limit) || scannedProgrammes > 50000 {
                            break
                        }
                    }
                    if results.count >= max(limit * 4, limit) || scannedProgrammes > 50000 {
                        break
                    }
                }
                return Array(results.sorted { lhs, rhs in
                    let lhsLive = lhs.program.startTime <= now && lhs.program.endTime >= now
                    let rhsLive = rhs.program.startTime <= now && rhs.program.endTime >= now
                    if lhsLive != rhsLive {
                        return lhsLive
                    }
                    if lhs.program.startTime != rhs.program.startTime {
                        return lhs.program.startTime < rhs.program.startTime
                    }
                    return lhs.program.title.localizedStandardCompare(rhs.program.title) == .orderedAscending
                }.prefix(limit))
            },
            fetchProgramsForChannel: { channelID, _, fallbackEPGID in
                let mappings = loadMappings()
                let targetEPGID = mappings[channelID]?.customEPGChannelID ?? fallbackEPGID ?? channelID

                if let xmltvProgs = await CustomEPGStore.shared.getProgrammes(channelID: targetEPGID) {
                    let now = Date()
                    let shift = mappings[channelID]?.timeShiftHours != 0 ? mappings[channelID]?.timeShiftHours ?? 0 : defaults.integer(forKey: globalShiftKey)
                    let shiftInterval = TimeInterval(shift * 3600)

                    return xmltvProgs.map { prog in
                        let start = prog.start.addingTimeInterval(shiftInterval)
                        let end = prog.end.addingTimeInterval(shiftInterval)
                        return EPGProgram(
                            id: "\(targetEPGID)_\(start.timeIntervalSince1970)",
                            title: prog.title,
                            description: prog.description,
                            startTime: start,
                            endTime: end,
                            isPlayingNow: start <= now && now <= end,
                            categories: prog.categories
                        )
                    }
                }
                return []
            },
            applyTimeShift: { programs, channelID in
                let mappings = loadMappings()
                let shift: Int = if let channelShift = mappings[channelID]?.timeShiftHours, channelShift != 0 {
                    channelShift
                } else {
                    defaults.integer(forKey: globalShiftKey)
                }
                guard shift != 0 else { return programs }

                let shiftInterval = TimeInterval(shift * 3600)
                let now = Date()

                return programs.map { prog in
                    let newStart = prog.startTime.addingTimeInterval(shiftInterval)
                    let newEnd = prog.endTime.addingTimeInterval(shiftInterval)
                    return EPGProgram(
                        id: prog.id,
                        title: prog.title,
                        description: prog.description,
                        startTime: newStart,
                        endTime: newEnd,
                        isPlayingNow: newStart <= now && now <= newEnd,
                        categories: prog.categories
                    )
                }
            }
        )
    }()

    public static let testValue = CustomEPGMappingClient()
}

public extension DependencyValues {
    var customEPGMappingClient: CustomEPGMappingClient {
        get { self[CustomEPGMappingClient.self] }
        set { self[CustomEPGMappingClient.self] = newValue }
    }
}
