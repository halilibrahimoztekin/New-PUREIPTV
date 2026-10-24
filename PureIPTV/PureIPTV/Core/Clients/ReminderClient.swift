import ComposableArchitecture
import Foundation
#if os(iOS)
    import UserNotifications
#endif

public enum EPGReminderIdentifier {
    public nonisolated static func playlistIdentity(for config: PlaylistConfig) -> String {
        config.serverURL?.absoluteString
            ?? config.m3uURL?.absoluteString
            ?? config.playlistID?.uuidString
            ?? "default"
    }

    public nonisolated static func make(
        playlistIdentity: String,
        channelID: String,
        programID: String
    ) -> String {
        let components = [playlistIdentity, channelID, programID]
        return "epg-reminder-v1|" + components.map { "\($0.utf8.count):\($0)" }.joined()
    }

    public nonisolated static func make(
        config: PlaylistConfig,
        channelID: String,
        programID: String
    ) -> String {
        make(
            playlistIdentity: playlistIdentity(for: config),
            channelID: channelID,
            programID: programID
        )
    }
}

public struct EPGReminder: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let programTitle: String
    public let channelTitle: String
    public let channelID: String
    public let startTime: Date
    public let triggerTime: Date

    public init(id: String, programTitle: String, channelTitle: String, channelID: String, startTime: Date, triggerTime: Date) {
        self.id = id
        self.programTitle = programTitle
        self.channelTitle = channelTitle
        self.channelID = channelID
        self.startTime = startTime
        self.triggerTime = triggerTime
    }
}

@DependencyClient
public struct ReminderClient: Sendable {
    public var requestAuthorization: @Sendable () async throws -> Bool = { false }
    public var scheduleReminder: @Sendable (_ program: EPGProgram, _ channel: MediaModels.Item, _ advanceMinutes: Int) async throws -> Void
    public var removeReminder: @Sendable (_ programID: String) async -> Void
    public var getScheduledReminderIDs: @Sendable () async -> Set<String> = { [] }
}

extension ReminderClient: DependencyKey {
    private static let remindersKey = "pureiptv_epg_reminders"

    public static let liveValue: ReminderClient = .init(
        requestAuthorization: {
            #if os(iOS)
                let center = UNUserNotificationCenter.current()
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            #else
                return true
            #endif
        },
        scheduleReminder: { program, channel, advanceMinutes in
            let triggerDate = program.startTime.addingTimeInterval(-Double(advanceMinutes * 60))
            guard triggerDate > Date() else {
                return
            }

            #if os(iOS)
                let center = UNUserNotificationCenter.current()
                let content = UNMutableNotificationContent()
                content.title = AppStrings.Player.reminderNotificationTitle
                content.body = AppStrings.Player.reminderNotificationBody(program.title, channel.title, advanceMinutes)
                content.sound = .default
                content.userInfo = [
                    "channelID": channel.id,
                    "programID": program.id,
                ]

                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: program.id, content: content, trigger: trigger)

                try await center.add(request)
            #endif

            // Cache in UserDefaults for quick UI badge lookup
            let reminder = EPGReminder(
                id: program.id,
                programTitle: program.title,
                channelTitle: channel.title,
                channelID: channel.id,
                startTime: program.startTime,
                triggerTime: triggerDate
            )

            var existing = loadCachedReminders()
            existing.removeAll { $0.id == program.id }
            existing.append(reminder)
            saveCachedReminders(existing)
        },
        removeReminder: { programID in
            #if os(iOS)
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: [programID])
            #endif

            var existing = loadCachedReminders()
            existing.removeAll { $0.id == programID }
            saveCachedReminders(existing)
        },
        getScheduledReminderIDs: {
            let existing = loadCachedReminders()
            // Filter out past reminders
            let active = existing.filter { $0.triggerTime > Date() }
            if active.count != existing.count {
                saveCachedReminders(active)
            }
            return Set(active.map(\.id))
        }
    )

    private static func loadCachedReminders() -> [EPGReminder] {
        guard let data = UserDefaults.standard.data(forKey: remindersKey),
              let list = try? JSONDecoder().decode([EPGReminder].self, from: data)
        else {
            return []
        }
        return list
    }

    private static func saveCachedReminders(_ list: [EPGReminder]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: remindersKey)
        }
    }
}

public extension DependencyValues {
    var reminderClient: ReminderClient {
        get { self[ReminderClient.self] }
        set { self[ReminderClient.self] = newValue }
    }
}
