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
    private let phoneBedNFCTagRegistrationKey = "ollie.phoneBedNFCTag.registration"
    private let installationIDKey = "ollie.installationID"
    private let nightWatchPreferencesKey = "ollie.nightWatch.preferences"
    private let automaticWindDownScheduleKey = "ollie.nightWatch.automaticSchedule"
    private let windDownRoutinesKey = "ollie.nightWatch.routines"
    private let nextWindDownOverrideKey = "ollie.nightWatch.nextOverride"
    private let offlinePurposeKey = "ollie.offlinePurpose"
    private let screenTimeReportPreferencesKey = "ollie.screenTime.reportPreferences"
    private let morningCheckInsKey = "ollie.morningCheckIns"
    private let nightWatchHistoryKey = "ollie.nightWatch.history"
    private let impactSharingPreferencesKey = "ollie.impactSharing.preferences"
    private let impactUploadRecordsKey = "ollie.impactSharing.records"
    private let sheepSearchStateKey = "ollie.sheepSearch.state"
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

    var phoneBedNFCTagRegistration: PhoneBedTagRegistration? {
        get { load(PhoneBedTagRegistration.self, key: phoneBedNFCTagRegistrationKey) }
        set { save(newValue, key: phoneBedNFCTagRegistrationKey) }
    }

    func resetPhoneBedNFCTag() {
        defaults.removeObject(forKey: phoneBedNFCTagKey)
        defaults.removeObject(forKey: phoneBedNFCTagRegistrationKey)
    }

    var nightWatchPreferences: NightWatchPreferences {
        get { load(NightWatchPreferences.self, key: nightWatchPreferencesKey) ?? .defaults }
        set { save(newValue, key: nightWatchPreferencesKey) }
    }

    var automaticWindDownSchedule: AutomaticWindDownSchedule? {
        get { load(AutomaticWindDownSchedule.self, key: automaticWindDownScheduleKey) }
        set { save(newValue, key: automaticWindDownScheduleKey) }
    }

    /// The plural schedule is additive. Existing installs migrate their saved
    /// primary preferences into one routine without rewriting the legacy key.
    var windDownRoutines: [WindDownRoutine] {
        get {
            if let routines = load([WindDownRoutine].self, key: windDownRoutinesKey) {
                return routines
            }
            guard nightWatchPreferences.isConfigured else { return [] }
            return [WindDownRoutine.primary(from: nightWatchPreferences)]
        }
        set { save(newValue, key: windDownRoutinesKey) }
    }

    var nextWindDownOverride: NextWindDownOverride? {
        get { load(NextWindDownOverride.self, key: nextWindDownOverrideKey) }
        set { save(newValue, key: nextWindDownOverrideKey) }
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

    var nightWatchHistory: NightWatchHistory {
        get { load(NightWatchHistory.self, key: nightWatchHistoryKey) ?? NightWatchHistory() }
        set { save(newValue, key: nightWatchHistoryKey) }
    }

    func upsertNightWatchRecord(_ record: NightWatchRecord, now: Date = Date()) {
        var history = nightWatchHistory
        history.upsert(record, now: now)
        nightWatchHistory = history
    }

    func appendRitualEvent(_ event: RitualEvent, now: Date = Date()) {
        var history = nightWatchHistory
        history.append(event, now: now)
        nightWatchHistory = history
    }

    func deleteNightWatchHistory() {
        defaults.removeObject(forKey: nightWatchHistoryKey)
    }

    /// Clears local ritual progression while leaving the person's setup and physical
    /// phone-bed pairing intact so a fresh trail does not require reconfiguration.
    func resetLocalProgress() {
        [
            progressKey,
            rewardsKey,
            thresholdKey,
            lastRunKey,
            manualAnalyticsKey,
            morningCheckInsKey,
            nightWatchHistoryKey,
            impactUploadRecordsKey,
            sheepSearchStateKey
        ].forEach { defaults.removeObject(forKey: $0) }
    }

    var impactSharingPreferences: ImpactSharingPreferences {
        get {
            load(ImpactSharingPreferences.self, key: impactSharingPreferencesKey)
                ?? ImpactSharingPreferences()
        }
        set { save(newValue, key: impactSharingPreferencesKey) }
    }

    var impactUploadRecords: [ImpactUploadRecord] {
        get { load([ImpactUploadRecord].self, key: impactUploadRecordsKey) ?? [] }
        set { save(newValue, key: impactUploadRecordsKey) }
    }

    var sheepSearchState: SheepSearchState {
        get {
            if let stored = load(SheepSearchState.self, key: sheepSearchStateKey) {
                return stored
            }
            // Existing installs keep their protected-night count. Give the field book a
            // deterministic starting flock without inventing historical run outcomes.
            let legacyProgress = progress
            guard legacyProgress.totalCompletedRuns > 0 else { return .empty }
            var migrated = SheepSearchState.empty
            migrated.foundSheepIDs = Array(
                SheepCatalog.all.prefix(legacyProgress.totalCompletedRuns).map(\.id)
            )
            migrated.totalTrailDistance = Double(legacyProgress.totalFocusMinutes) * 0.08
            save(migrated, key: sheepSearchStateKey)
            return migrated
        }
        set { save(newValue, key: sheepSearchStateKey) }
    }

    func deleteImpactUploadRecords() {
        defaults.removeObject(forKey: impactUploadRecordsKey)
    }

    var installationID: UUID {
        if let stored = defaults.string(forKey: installationIDKey), let identifier = UUID(uuidString: stored) {
            return identifier
        }
        let identifier = UUID()
        defaults.set(identifier.uuidString, forKey: installationIDKey)
        return identifier
    }

    var onboardingVersion: Int {
        get { defaults.integer(forKey: CountingSheepOnboarding.versionKey) }
        set { defaults.set(newValue, forKey: CountingSheepOnboarding.versionKey) }
    }

    var onboardingDraft: OnboardingDraft? {
        get { load(OnboardingDraft.self, key: CountingSheepOnboarding.draftKey) }
        set { save(newValue, key: CountingSheepOnboarding.draftKey) }
    }

    func completeOnboarding() {
        onboardingVersion = CountingSheepOnboarding.currentVersion
        onboardingDraft = nil
    }

    func resetOnboarding() {
        defaults.removeObject(forKey: CountingSheepOnboarding.versionKey)
        onboardingDraft = nil
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
