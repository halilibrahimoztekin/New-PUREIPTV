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

    public static var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("LocalDVR", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public private(set) var recordings: [RecordedStreamItem] = []
    public private(set) var isRecording: Bool = false
    public private(set) var activeChannelTitle: String?

    private var currentTask: Task<Void, Never>?
    private var recordingStartTime: Date?
    private var currentRecordingID: String?

    private init() {
        loadRecordings()
    }

    public func loadRecordings() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([RecordedStreamItem].self, from: data)
        {
            recordings = saved
        }
    }

    private func saveRecordings() {
        if let data = try? JSONEncoder().encode(recordings) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    public func startRecording(channelTitle: String, streamURL: URL) {
        guard !isRecording else { return }

        let recID = UUID().uuidString
        let fileName = "rec_\(recID).ts"
        let destURL = Self.recordingsDirectory.appendingPathComponent(fileName)

        isRecording = true
        activeChannelTitle = channelTitle
        currentRecordingID = recID
        recordingStartTime = Date()

        currentTask = Task(priority: .utility) {
            var request = URLRequest(url: streamURL)
            request.timeoutInterval = 10.0
            UserAgentManager.shared.applyHeaders(to: &request)

            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                    self.stopRecording()
                    return
                }

                FileManager.default.createFile(atPath: destURL.path, contents: nil)
                guard let fileHandle = try? FileHandle(forWritingTo: destURL) else { return }

                var buffer = Data()
                buffer.reserveCapacity(65536)

                for try await byte in bytes {
                    if Task.isCancelled {
                        break
                    }
                    buffer.append(byte)
                    if buffer.count >= 65536 {
                        fileHandle.write(buffer)
                        buffer.removeAll(keepingCapacity: true)
                    }
                }
                if !buffer.isEmpty {
                    fileHandle.write(buffer)
                }
                try? fileHandle.close()
            } catch {
                // Recording stopped or network ended
            }
        }
    }

    public func stopRecording() {
        guard isRecording else { return }
        currentTask?.cancel()
        currentTask = nil

        let elapsed = Date().timeIntervalSince(recordingStartTime ?? Date())
        if let recID = currentRecordingID, let title = activeChannelTitle {
            let fileName = "rec_\(recID).ts"
            let destURL = Self.recordingsDirectory.appendingPathComponent(fileName)
            let size = (try? destURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

            if size > 10000 { // Keep only if at least some stream was recorded
                let record = RecordedStreamItem(
                    id: recID,
                    channelTitle: title,
                    startDate: recordingStartTime ?? Date(),
                    durationSeconds: elapsed,
                    relativeFileName: fileName,
                    fileSizeBytes: Int64(size)
                )
                recordings.insert(record, at: 0)
                saveRecordings()
            }
        }

        isRecording = false
        activeChannelTitle = nil
        currentRecordingID = nil
        recordingStartTime = nil
    }

    public func deleteRecording(id: String) {
        if let idx = recordings.firstIndex(where: { $0.id == id }) {
            let item = recordings[idx]
            try? FileManager.default.removeItem(at: item.fileURL)
            recordings.remove(at: idx)
            saveRecordings()
        }
    }
}
