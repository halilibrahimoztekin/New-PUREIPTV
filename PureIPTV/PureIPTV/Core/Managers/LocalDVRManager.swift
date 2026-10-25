import Foundation

public struct RecordedStreamItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let channelTitle: String
    public let startDate: Date
    public var durationSeconds: Double
    public let relativeFileName: String
    public var fileSizeBytes: Int64

    public var fileURL: URL {
        LocalDVRManager.recordingsDirectory.appendingPathComponent(relativeFileName)
    }

    public var formattedDuration: String {
        let mins = Int(durationSeconds) / 60
        let secs = Int(durationSeconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

public final class LocalDVRManager: @unchecked Sendable {
    public static let shared = LocalDVRManager()

    private let storageKey = "pureiptv_local_dvr_records"
    private let stateLock = NSLock()

    public static var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("LocalDVR", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var storedRecordings: [RecordedStreamItem] = []
    private var storedIsRecording = false
    private var storedActiveChannelTitle: String?

    public var recordings: [RecordedStreamItem] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storedRecordings
    }

    public var isRecording: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storedIsRecording
    }

    public var activeChannelTitle: String? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storedActiveChannelTitle
    }

    private var recordingStartTime: Date?

    private let minimumFreeSpaceBytes: Int64 = 1_073_741_824
    private let maximumLibraryBytes: Int64 = 21_474_836_480
    public let maximumRecordingBytes: Int64 = 4_294_967_296

    private init() {
        loadRecordings()
    }

    public func loadRecordings() {
        stateLock.lock()
        defer { stateLock.unlock() }
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([RecordedStreamItem].self, from: data)
        {
            storedRecordings = saved
        }
    }

    private func saveRecordings() {
        if let data = try? JSONEncoder().encode(storedRecordings) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    public func prepareRecordingDirectory() throws -> URL {
        stateLock.lock()
        defer { stateLock.unlock() }
        let directory = Self.recordingsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileSystem = try FileManager.default.attributesOfFileSystem(forPath: directory.path)
        let freeBytes = (fileSystem[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        let libraryBytes = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]))?
            .reduce(Int64(0)) { total, fileURL in
                total + Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            } ?? 0
        guard freeBytes >= minimumFreeSpaceBytes, libraryBytes < maximumLibraryBytes else {
            throw CocoaError(.fileWriteOutOfSpace)
        }
        return directory
    }

    public func beginRecording(channelTitle: String) {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard recordingStartTime == nil else { return }
        storedActiveChannelTitle = channelTitle
        recordingStartTime = Date()
        storedIsRecording = true
    }

    public func cancelRecordingSession() {
        stateLock.lock()
        defer { stateLock.unlock() }
        storedActiveChannelTitle = nil
        recordingStartTime = nil
        storedIsRecording = false
    }

    @discardableResult
    public func finishRecording(filePath: String?) -> RecordedStreamItem? {
        stateLock.lock()
        defer { stateLock.unlock() }
        defer {
            storedActiveChannelTitle = nil
            recordingStartTime = nil
            storedIsRecording = false
        }
        guard let filePath else { return nil }
        let directory = Self.recordingsDirectory.standardizedFileURL
        let fileURL = URL(fileURLWithPath: filePath).standardizedFileURL
        guard fileURL.path.hasPrefix(directory.path + "/") else { return nil }
        guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize,
              Int64(size) > 16384,
              Int64(size) <= maximumRecordingBytes
        else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
        if let existingRecord = storedRecordings.first(where: { $0.relativeFileName == fileURL.lastPathComponent }) {
            return existingRecord
        }
        guard let startDate = recordingStartTime, let title = storedActiveChannelTitle else { return nil }

        let record = RecordedStreamItem(
            id: UUID().uuidString,
            channelTitle: title,
            startDate: startDate,
            durationSeconds: max(0, Date().timeIntervalSince(startDate)),
            relativeFileName: fileURL.lastPathComponent,
            fileSizeBytes: Int64(size)
        )
        storedRecordings.insert(record, at: 0)
        saveRecordings()
        return record
    }

    public func recordingFileSize(at path: String?) -> Int64 {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let path else { return 0 }
        let fileURL = URL(fileURLWithPath: path).standardizedFileURL
        let directory = Self.recordingsDirectory.standardizedFileURL
        guard fileURL.path.hasPrefix(directory.path + "/"),
              let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        else { return 0 }
        return Int64(size ?? 0)
    }

    public func deleteRecording(id: String) {
        stateLock.lock()
        defer { stateLock.unlock() }
        if let idx = storedRecordings.firstIndex(where: { $0.id == id }) {
            let item = storedRecordings[idx]
            try? FileManager.default.removeItem(at: item.fileURL)
            storedRecordings.remove(at: idx)
            saveRecordings()
        }
    }
}
