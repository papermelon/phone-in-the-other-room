import Foundation

enum FocusRunShortcutStore {
    private static let pendingDurationKey = "shortcut.pendingFocusRunDurationSeconds"
    private static let pendingDateKey = "shortcut.pendingFocusRunPreparedAt"

    static func savePendingDuration(minutes: Int, seconds: Int) {
        let clampedMinutes = min(max(minutes, 0), 180)
        let clampedSeconds = min(max(seconds, 0), 59)
        let duration = max(1, (clampedMinutes * 60) + clampedSeconds)
        UserDefaults.standard.set(duration, forKey: pendingDurationKey)
        UserDefaults.standard.set(Date(), forKey: pendingDateKey)
    }

    static func consumePendingDuration(maxAge: TimeInterval = 10 * 60) -> TimeInterval? {
        guard UserDefaults.standard.object(forKey: pendingDurationKey) != nil else { return nil }
        let preparedAt = UserDefaults.standard.object(forKey: pendingDateKey) as? Date
        defer {
            UserDefaults.standard.removeObject(forKey: pendingDurationKey)
            UserDefaults.standard.removeObject(forKey: pendingDateKey)
        }
        if let preparedAt, Date().timeIntervalSince(preparedAt) > maxAge {
            return nil
        }
        return TimeInterval(UserDefaults.standard.integer(forKey: pendingDurationKey))
    }

    static func clearPendingDuration() {
        UserDefaults.standard.removeObject(forKey: pendingDurationKey)
        UserDefaults.standard.removeObject(forKey: pendingDateKey)
    }
}
