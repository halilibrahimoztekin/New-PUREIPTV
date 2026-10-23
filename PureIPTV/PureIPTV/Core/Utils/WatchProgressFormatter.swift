import Foundation

public enum WatchProgressFormatter {
    public static func progressRatio(progress: Double, duration: Double) -> Double {
        guard duration > 0 else { return 0.0 }
        return max(0.0, min(1.0, progress / duration))
    }

    public static func percentage(progress: Double, duration: Double) -> Int {
        Int((progressRatio(progress: progress, duration: duration) * 100).rounded())
    }

    public static func formattedRemainingTime(progress: Double, duration: Double) -> String {
        guard duration > 0 else { return "" }
        let remaining = max(0.0, duration - progress)

        if remaining < 60 {
            return "1 dk'dan az"
        } else if remaining < 3600 {
            let mins = Int((remaining / 60).rounded())
            return "\(mins) dk kaldı"
        } else {
            let hours = Int(remaining / 3600)
            let mins = Int((remaining.truncatingRemainder(dividingBy: 3600) / 60).rounded())
            if mins == 0 {
                return "\(hours) sa kaldı"
            }
            return "\(hours) sa \(mins) dk kaldı"
        }
    }

    public static func relativeDateFormatted(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let diff = now.timeIntervalSince(date)
            if diff < 60 {
                return "Az önce"
            } else if diff < 3600 {
                let mins = Int(diff / 60)
                return "\(mins) dk önce"
            } else {
                let hours = Int(diff / 3600)
                return "\(hours) saat önce"
            }
        } else if calendar.isDateInYesterday(date) {
            return "Dün"
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            formatter.locale = Locale(identifier: "tr_TR")
            return formatter.localizedString(for: date, relativeTo: now)
        }
    }

    public static func formatTime(_ seconds: Double) -> String {
        guard seconds > 0 else { return "00:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
