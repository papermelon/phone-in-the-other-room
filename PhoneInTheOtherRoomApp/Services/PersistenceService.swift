import Foundation
import OSLog

final class PersistenceService {
    static let shared = PersistenceService()

    private let defaults = UserDefaults.standard
    private let progressKey = "ollie.progress"
    private let rewardsKey = "ollie.rewards"
    private let thresholdKey = "ollie.thresholds"
    private let lastRunKey = "ollie.lastRun"
    private let manualAnalyticsKey = "ollie.analytics.manualEntries"
    private let phoneBedQRCodeKey = "ollie.phoneBedQRCode"
    private let phoneBedNFCTagKey = "ollie.phoneBedNFCTag"
    private let installationIDKey = "ollie.installationID"
    private let nightWatchPreferencesKey = "ollie.nightWatch.preferences"
    private let offlinePurposeKey = "ollie.offlinePurpose"
    private let screenTimeReportPreferencesKey = "ollie.screenTime.reportPreferences"
    private let morningCheckInsKey = "ollie.morningCheckIns"
#if DEBUG
    private let energyLogger = Logger(
        subsystem: "com.ngawangchime.countingsheep",
        category: "Energy.Persistence"
    )
    private var debugSaveCounts: [String: Int] = [:]
    private var debugLastSaveAt: [String: Date] = [:]
#endif

    var progress: UserProgress {
        get { load(UserProgress.self, key: progressKey) ?? .empty }
        set { save(newValue, key: progressKey) }
    }

    var rewards: [RewardItem] {
        get { load([RewardItem].self, key: rewardsKey) ?? [] }
        set { save(newValue, key: rewardsKey) }
    }

    var thresholds: ThresholdProfile {
        get { load(ThresholdProfile.self, key: thresholdKey) ?? .defaults }
        set { save(newValue, key: thresholdKey) }
    }

    var lastRun: FocusRun? {
        get { load(FocusRun.self, key: lastRunKey) }
        set { save(newValue, key: lastRunKey) }
    }

    var manualAnalyticsEntries: [ManualAnalyticsEntry] {
        get { load([ManualAnalyticsEntry].self, key: manualAnalyticsKey) ?? [] }
        set { save(newValue, key: manualAnalyticsKey) }
    }

    var phoneBedQRCode: String? {
        get { defaults.string(forKey: phoneBedQRCodeKey) }
        set { defaults.set(newValue, forKey: phoneBedQRCodeKey) }
    }

    var phoneBedNFCTag: String? {
        get { defaults.string(forKey: phoneBedNFCTagKey) }
        set { defaults.set(newValue, forKey: phoneBedNFCTagKey) }
    }

    var nightWatchPreferences: NightWatchPreferences {
        get { load(NightWatchPreferences.self, key: nightWatchPreferencesKey) ?? .defaults }
        set { save(newValue, key: nightWatchPreferencesKey) }
    }

    var offlinePurpose: OfflinePurposeProfile {
        get { load(OfflinePurposeProfile.self, key: offlinePurposeKey) ?? .defaultProfile }
        set { save(newValue, key: offlinePurposeKey) }
    }

    var screenTimeReportPreferences: ScreenTimeReportPreferences? {
        get { load(ScreenTimeReportPreferences.self, key: screenTimeReportPreferencesKey) }
        set { save(newValue, key: screenTimeReportPreferencesKey) }
    }

    var morningCheckIns: MorningCheckInHistory {
        get { load(MorningCheckInHistory.self, key: morningCheckInsKey) ?? MorningCheckInHistory() }
        set { save(newValue, key: morningCheckInsKey) }
    }

    var installationID: UUID {
        if let stored = defaults.string(forKey: installationIDKey), let identifier = UUID(uuidString: stored) {
            return identifier
        }
        let identifier = UUID()
        defaults.set(identifier.uuidString, forKey: installationIDKey)
        return identifier
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T?, key: String) {
#if DEBUG
        debugSaveCounts[key, default: 0] += 1
        let now = Date()
        let interval = debugLastSaveAt[key].map { now.timeIntervalSince($0) } ?? 0
        debugLastSaveAt[key] = now
        energyLogger.debug(
            "write key=\(key, privacy: .public) count=\(self.debugSaveCounts[key, default: 0]) secondsSincePrevious=\(interval, format: .fixed(precision: 3))"
        )
#endif
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
