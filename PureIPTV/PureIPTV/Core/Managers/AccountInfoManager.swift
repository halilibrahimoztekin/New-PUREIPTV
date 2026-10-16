import Combine
import Foundation

public struct XtreamAccountInfo: Codable, Sendable, Equatable {
    public let username: String?
    public let expDateTimestamp: TimeInterval?
    public let expDateString: String?
    public let activeConnections: Int?
    public let maxConnections: Int?
    public let isTrial: Bool
    public let status: String?

    public init(
        username: String?,
        expDateTimestamp: TimeInterval?,
        expDateString: String?,
        activeConnections: Int?,
        maxConnections: Int?,
        isTrial: Bool,
        status: String?
    ) {
        self.username = username
        self.expDateTimestamp = expDateTimestamp
        self.expDateString = expDateString
        self.activeConnections = activeConnections
        self.maxConnections = maxConnections
        self.isTrial = isTrial
        self.status = status
    }

    public var daysRemaining: Int? {
        guard let expDateTimestamp else { return nil }
        let now = Date().timeIntervalSince1970
        let diff = expDateTimestamp - now
        return max(0, Int(diff / 86400))
    }

    public var isExpiringSoon: Bool {
        guard let days = daysRemaining else { return false }
        return days <= 7 && days >= 0
    }

    public var formattedExpiration: String {
        guard let expDateTimestamp else {
            return expDateString ?? "Bilinmiyor"
        }
        let date = Date(timeIntervalSince1970: expDateTimestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "tr_TR")

        let dateStr = formatter.string(from: date)
        if let days = daysRemaining {
            if days == 0 {
                return "\(dateStr) (Bugün Bitiyor!)"
            } else if days == 1 {
                return "\(dateStr) (Yarın Bitiyor!)"
            } else {
                return "\(dateStr) (\(days) gün kaldı)"
            }
        }
        return dateStr
    }

    public var connectionsDescription: String {
        let active = activeConnections ?? 1
        let maxCons = maxConnections ?? 1
        return "\(active) / \(maxCons) Cihaz Aktif"
    }

    public var isLimitReached: Bool {
        guard let active = activeConnections, let maxCons = maxConnections else { return false }
        return active >= maxCons && maxCons > 0
    }
}

@MainActor
public final class AccountInfoManager: ObservableObject {
    public static let shared = AccountInfoManager()

    private let storageKey = "pureiptv_xtream_account_info"
    @Published public private(set) var accountInfo: XtreamAccountInfo?

    private init() {
        loadSavedAccountInfo()
    }

    public func update(from dto: XtreamAuthResponseDTO) {
        let userInfo = dto.userInfo

        var timestamp: TimeInterval?
        if let expStr = userInfo.expDate, let rawSec = Double(expStr) {
            timestamp = rawSec
        }

        let active = userInfo.activeCons.flatMap { Int($0) }
        let maxC = userInfo.maxConnections.flatMap { Int($0) }
        let isTrial = (userInfo.isTrial == "1" || userInfo.isTrial?.lowercased() == "true")

        let info = XtreamAccountInfo(
            username: userInfo.username,
            expDateTimestamp: timestamp,
            expDateString: userInfo.expDate,
            activeConnections: active,
            maxConnections: maxC,
            isTrial: isTrial,
            status: userInfo.status
        )

        accountInfo = info
        saveAccountInfo(info)
    }

    public func clear() {
        accountInfo = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func saveAccountInfo(_ info: XtreamAccountInfo) {
        if let data = try? JSONEncoder().encode(info) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadSavedAccountInfo() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let info = try? JSONDecoder().decode(XtreamAccountInfo.self, from: data)
        else {
            return
        }
        accountInfo = info
    }
}
