import ComposableArchitecture
import Foundation
#if os(iOS)
    import UserNotifications
#endif

public enum EPGReminderIdentifier {
    public nonisolated static func playlistIdentity(for config: PlaylistConfig) -> String {
        if let playlistID = config.playlistID {
            return "playlist:\(playlistID.uuidString.lowercased())"
        }
        let host = config.serverURL?.host?.lowercased() ?? config.m3uURL?.host?.lowercased() ?? "unknown-host"
        if let username = config.username, !username.isEmpty {
            return "account:\(host):\(username)"
        }
        return "source:\(host)"
    }

    public nonisolated static func make(playlistIdentity: String, channelID: String, programID: String) -> String {
        let components = [playlistIdentity, channelID, programID]
        return "epg-reminder-v2|" + components.map { "\($0.utf8.count):\($0)" }.joined()
    }

    public nonisolated static func make(config: PlaylistConfig, channelID: String, programID: String) -> String {
        make(playlistIdentity: playlistIdentity(for: config), channelID: channelID, programID: programID)
    }
}

public struct EPGReminder: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let programTitle: String
    public let channelTitle: String
    public let channelID: String
    public let playlistIdentity: String
    public let startTime: Date
    public let endTime: Date
    public let triggerTime: Date
    public var autoSwitchHandled: Bool
    public var isNotificationPresent: Bool

    public init(
        id: String,
        programTitle: String,
        channelTitle: String,
        channelID: String,
        playlistIdentity: String,
        startTime: Date,
        endTime: Date,
        triggerTime: Date,
        autoSwitchHandled: Bool = false,
        isNotificationPresent: Bool = true
    ) {
        self.id = id
        self.programTitle = programTitle
        self.channelTitle = channelTitle
        self.channelID = channelID
        self.playlistIdentity = playlistIdentity
        self.startTime = startTime
        self.endTime = endTime
        self.triggerTime = triggerTime
        self.autoSwitchHandled = autoSwitchHandled
        self.isNotificationPresent = isNotificationPresent
    }

    private enum CodingKeys: String, CodingKey {
        case id, programTitle, channelTitle, channelID, playlistIdentity, startTime, endTime, triggerTime, autoSwitchHandled, isNotificationPresent
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        programTitle = try values.decode(String.self, forKey: .programTitle)
        channelTitle = try values.decode(String.self, forKey: .channelTitle)
        channelID = try values.decode(String.self, forKey: .channelID)
        playlistIdentity = try values.decodeIfPresent(String.self, forKey: .playlistIdentity) ?? ""
        startTime = try values.decode(Date.self, forKey: .startTime)
        endTime = try values.decodeIfPresent(Date.self, forKey: .endTime) ?? startTime.addingTimeInterval(6 * 3600)
        triggerTime = try values.decode(Date.self, forKey: .triggerTime)
        autoSwitchHandled = try values.decodeIfPresent(Bool.self, forKey: .autoSwitchHandled) ?? false
        isNotificationPresent = try values.decodeIfPresent(Bool.self, forKey: .isNotificationPresent) ?? true
    }
}

private actor EPGReminderStore {
    static let shared = EPGReminderStore()
    private let key = "pureiptv_epg_reminders"

    func all() -> [EPGReminder] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let reminders = try? JSONDecoder().decode([EPGReminder].self, from: data) else { return [] }
        return reminders
    }

    func save(_ reminders: [EPGReminder]) {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func upsert(_ reminder: EPGReminder) {
        var reminders = all()
        reminders.removeAll { $0.id == reminder.id }
        reminders.append(reminder)
        save(reminders)
    }

    func remove(_ id: String) {
        var reminders = all()
        reminders.removeAll { $0.id == id }
        save(reminders)
    }

    func markAutoSwitchHandled(_ id: String) {
        var reminders = all()
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[index].autoSwitchHandled = true
        save(reminders)
    }

    func removeLegacyEntries() -> Set<String> {
        var reminders = all()
        let legacy = reminders.filter {
            $0.id.hasPrefix("epg-reminder-v1|") || $0.playlistIdentity.isEmpty
        }
        reminders.removeAll {
            $0.id.hasPrefix("epg-reminder-v1|") || $0.playlistIdentity.isEmpty
        }
        save(reminders)
        return Set(legacy.map(\.id))
    }

    func reconcile(validNotificationIDs: Set<String>, now: Date) -> [EPGReminder] {
        // Keep valid reminder metadata until the program ends even if the user
        // dismisses the notification. Auto-switch is an app foreground action,
        // independent of whether Notification Center still retains its banner.
        var active = all().filter { $0.endTime > now }
        for index in active.indices {
            active[index].isNotificationPresent = validNotificationIDs.contains(active[index].id)
        }
        save(active)
        return active
    }
}

public struct ReminderClient: Sendable {
    public var requestAuthorization: @Sendable () async throws -> Bool
    public var scheduleReminder: @Sendable (_ program: EPGProgram, _ channel: MediaModels.Item, _ advanceMinutes: Int, _ playlistIdentity: String) async throws -> Void
    public var removeReminder: @Sendable (_ programID: String) async -> Void
    public var getScheduledReminderIDs: @Sendable () async -> Set<String>
    public var reconcileScheduledReminders: @Sendable () async -> [EPGReminder]
    public var markAutoSwitchHandled: @Sendable (_ reminderID: String) async -> Void

    public init(
        requestAuthorization: @escaping @Sendable () async throws -> Bool,
        scheduleReminder: @escaping @Sendable (EPGProgram, MediaModels.Item, Int, String) async throws -> Void,
        removeReminder: @escaping @Sendable (String) async -> Void,
        getScheduledReminderIDs: @escaping @Sendable () async -> Set<String>,
        reconcileScheduledReminders: @escaping @Sendable () async -> [EPGReminder],
        markAutoSwitchHandled: @escaping @Sendable (String) async -> Void
    ) {
        self.requestAuthorization = requestAuthorization
        self.scheduleReminder = scheduleReminder
        self.removeReminder = removeReminder
        self.getScheduledReminderIDs = getScheduledReminderIDs
        self.reconcileScheduledReminders = reconcileScheduledReminders
        self.markAutoSwitchHandled = markAutoSwitchHandled
    }
}

public extension ReminderClient {
    static let liveValue: ReminderClient = .init(
        requestAuthorization: {
            #if os(iOS)
                let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                if status == .authorized || status == .provisional || status == .ephemeral {
                    return true
                }
                return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            #else
                return false
            #endif
        },
        scheduleReminder: { program, channel, advanceMinutes, playlistIdentity in
            #if os(iOS)
                let now = Date()
                guard program.startTime > now else { throw ReminderSchedulingError.programAlreadyStarted }
                let requestedTrigger = program.startTime.addingTimeInterval(-Double(max(0, advanceMinutes) * 60))
                let triggerDate = max(requestedTrigger, now.addingTimeInterval(1))
                let effectiveMinutes = max(0, Int(program.startTime.timeIntervalSince(triggerDate) / 60))
                let center = UNUserNotificationCenter.current()
                let content = UNMutableNotificationContent()
                content.title = AppStrings.Player.reminderNotificationTitle
                content.body = effectiveMinutes == 0
                    ? AppStrings.Player.reminderStartsSoonBody(program.title, channel.title)
                    : AppStrings.Player.reminderNotificationBody(program.title, channel.title, effectiveMinutes)
                content.sound = .default
                content.userInfo = ["channelID": channel.id, "programID": program.id, "playlistIdentity": playlistIdentity]
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
                let request = UNNotificationRequest(
                    identifier: program.id,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
                try await center.add(request)
                await EPGReminderStore.shared.upsert(EPGReminder(
                    id: program.id,
                    programTitle: program.title,
                    channelTitle: channel.title,
                    channelID: channel.id,
                    playlistIdentity: playlistIdentity,
                    startTime: program.startTime,
                    endTime: program.endTime,
                    triggerTime: triggerDate
                ))
            #else
                throw ReminderSchedulingError.unsupportedPlatform
            #endif
        },
        removeReminder: { programID in
            #if os(iOS)
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: [programID])
                center.removeDeliveredNotifications(withIdentifiers: [programID])
            #endif
            await EPGReminderStore.shared.remove(programID)
        },
        getScheduledReminderIDs: {
            #if os(iOS)
                return await Set(reconcileReminders().map(\.id))
            #else
                return []
            #endif
        },
        reconcileScheduledReminders: {
            #if os(iOS)
                return await reconcileReminders()
            #else
                return []
            #endif
        },
        markAutoSwitchHandled: { reminderID in
            await EPGReminderStore.shared.markAutoSwitchHandled(reminderID)
        }
    )
}

#if os(iOS)
    private func reconcileReminders() async -> [EPGReminder] {
        let center = UNUserNotificationCenter.current()
        let legacyCacheIDs = await EPGReminderStore.shared.removeLegacyEntries()
        async let legacyPending = center.pendingNotificationRequests()
        async let legacyDelivered = center.deliveredNotifications()
        let legacyNotificationIDs = await Set(
            legacyPending.map(\.identifier).filter { $0.hasPrefix("epg-reminder-v1|") }
                + legacyDelivered.map(\.request.identifier).filter { $0.hasPrefix("epg-reminder-v1|") }
        ).union(legacyCacheIDs)
        if !legacyNotificationIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(legacyNotificationIDs))
            center.removeDeliveredNotifications(withIdentifiers: Array(legacyNotificationIDs))
        }
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
        guard authorized else {
            await EPGReminderStore.shared.save([])
            return []
        }
        async let pendingRequests = center.pendingNotificationRequests()
        async let deliveredNotifications = center.deliveredNotifications()
        let validIDs = await Set(pendingRequests.map(\.identifier) + deliveredNotifications.map(\.request.identifier))
        return await EPGReminderStore.shared.reconcile(validNotificationIDs: validIDs, now: Date())
    }

    @MainActor
    public final class EPGReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
        public static let shared = EPGReminderNotificationDelegate()

        public static func install() {
            UNUserNotificationCenter.current().delegate = shared
        }

        public func userNotificationCenter(
            _: UNUserNotificationCenter,
            willPresent _: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            completionHandler([.banner, .sound, .list])
        }
    }
#endif

private enum ReminderSchedulingError: Error {
    case programAlreadyStarted
    case unsupportedPlatform
}

public extension DependencyValues {
    var reminderClient: ReminderClient {
        get { self[ReminderClientKey.self] }
        set { self[ReminderClientKey.self] = newValue }
    }
}

private enum ReminderClientKey: DependencyKey {
    static let liveValue = ReminderClient.liveValue
    static let testValue = ReminderClient(
        requestAuthorization: { false },
        scheduleReminder: { _, _, _, _ in },
        removeReminder: { _ in },
        getScheduledReminderIDs: { [] },
        reconcileScheduledReminders: { [] },
        markAutoSwitchHandled: { _ in }
    )
}
