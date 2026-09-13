import Foundation
import OSLog

final class PersistenceService {
    static let shared = PersistenceService()

    private let defaults: UserDefaults
    let farmSaveStore: FarmSaveStore
    private let progressKey = "ollie.progress"
    private let rewardsKey = "ollie.rewards"
    private let thresholdKey = "ollie.thresholds"
    private let lastRunKey = "ollie.lastRun"
    private let manualAnalyticsKey = "ollie.analytics.manualEntries"
    private let phoneBedQRCodeKey = "ollie.phoneBedQRCode"
    private let phoneBedNFCTagKey = "ollie.phoneBedNFCTag"
    private let phoneBedNFCTagRegistrationKey = "ollie.phoneBedNFCTag.registration"
    private let phoneBedNFCTagLibraryKey = "ollie.phoneBedNFCTags.library"
    private let installationIDKey = "ollie.installationID"
    private let nightWatchPreferencesKey = "ollie.nightWatch.preferences"
    private let automaticWindDownScheduleKey = "ollie.nightWatch.automaticSchedule"
    private let automaticWindDownProtectionRepairKey = "ollie.nightWatch.automaticProtectionRepair"
    private let windDownScheduleKey = "ollie.nightWatch.schedule"
    private let windDownRoutinesKey = "ollie.nightWatch.routines"
    private let nextWindDownOverrideKey = "ollie.nightWatch.nextOverride"
    private let offlinePurposeKey = "ollie.offlinePurpose"
    private let screenTimeReportPreferencesKey = "ollie.screenTime.reportPreferences"
    private let morningCheckInsKey = "ollie.morningCheckIns"
    private let nightWatchHistoryKey = "ollie.nightWatch.history"
    private let impactSharingPreferencesKey = "ollie.impactSharing.preferences"
    private let impactUploadRecordsKey = "ollie.impactSharing.records"
    private let sheepSearchStateKey = "ollie.sheepSearch.state"
    private let farmStateKey = "ollie.farm.state"
    private let farmPastureSceneKey = "ollie.farm.pastureScene"
    private let userProfileKey = "ollie.userProfile"
    private let explicitSocialAvatarSelectionKey = "ollie.userProfile.socialAvatar.isExplicit"
    private let welcomeRewardLedgerKey = WelcomeRewardLedger.storageKey
    private let nightFlockRewardLedgerKey = NightFlockRewardLedger.storageKey
    private let windDownProfileKey = WindDownProfileRecord.storageKey
    private let orientationStateKey = "ollie.orientation.state"
    private let windDownMorningSettlementJournalKey = WindDownMorningSettlementJournal.storageKey
#if DEBUG
    private let energyLogger = Logger(
        subsystem: "com.ngawangchime.countingsheep",
        category: "Energy.Persistence"
    )
    private var debugSaveCounts: [String: Int] = [:]
    private var debugLastSaveAt: [String: Date] = [:]
#endif

    init(defaults: UserDefaults = .standard, farmSaveDirectory: URL? = nil,
         farmSaveFiles: FarmSaveFileAccess = LocalFarmSaveFileAccess()) {
        self.defaults = defaults
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let scope: String
        if defaults === UserDefaults.standard {
            scope = "FarmSave"
        } else {
            let key = "ollie.farm.localStoreID"
            let identifier = defaults.string(forKey: key) ?? UUID().uuidString
            defaults.set(identifier, forKey: key)
            scope = "FarmSave-\(identifier)"
        }
        farmSaveStore = FarmSaveStore(
            directory: farmSaveDirectory ?? root.appendingPathComponent(scope),
            files: farmSaveFiles,
            didCommit: { defaults.set(true, forKey: "ollie.farm.saveMigrated") },
            legacy: {
                guard !defaults.bool(forKey: "ollie.farm.saveMigrated") else {
                    throw FarmSaveError.unavailable
                }
                var values: [String: Data] = [:]
                for key in FarmSaveDocument.keys {
                    if defaults.object(forKey: key) != nil {
                        guard let data = defaults.data(forKey: key) else {
                            throw FarmSaveError.invalidComponent(key)
                        }
                        values[key] = data
                    }
                }
                return values
            }
        )
        do {
            try farmSaveStore.migrateAccountLocalValues {
                var values: [String: Data] = [:]
                for key in AccountFarmLocalKeys.all {
                    if key == "ollie.userProfile.socialAvatar.isExplicit" {
                        if let value = defaults.object(forKey: key) as? Bool {
                            values[key] = try JSONEncoder().encode(value)
                        }
                    } else if defaults.object(forKey: key) != nil {
                        guard let data = defaults.data(forKey: key) else { throw FarmSaveError.invalidComponent(key) }
                        values[key] = data
                    }
                }
                return values
            }
        } catch { farmSaveStore.reject(error) }
    }

    /// Legacy defaults are no longer read after scoped migration. Remove their
    /// redundant copies when deleting account data, after the durable store commit.
    func purgeLegacyFarmDefaultsAfterAccountDeletion() {
        for key in FarmSaveDocument.keys.union(AccountFarmLocalKeys.all) {
            defaults.removeObject(forKey: key)
        }
    }

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

    /// Emergency reasons stay local to this iPhone and are keyed by run. They
    /// are intentionally not part of FocusRun, Watch messages, or any upload.
    func saveEmergencyExitReason(_ reason: String, for runID: UUID) {
        defaults.set(reason, forKey: EmergencyExitReasonStorage.key(for: runID))
    }

    func emergencyExitReason(for runID: UUID) -> String? {
        defaults.string(forKey: EmergencyExitReasonStorage.key(for: runID))
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

    var phoneBedTagLibrary: PhoneBedTagLibrary {
        get {
            if let stored = load(PhoneBedTagLibrary.self, key: phoneBedNFCTagLibraryKey) {
                let normalized = PhoneBedTagLibrary(
                    schemaVersion: stored.schemaVersion,
                    tags: stored.tags,
                    previouslyPairedTokenDigests: stored.previouslyPairedTokenDigests
                )
                if normalized != stored {
                    save(normalized, key: phoneBedNFCTagLibraryKey)
                }
                return normalized
            }

            let migrated = PhoneBedTagLibrary.migrated(
                from: phoneBedNFCTagRegistration,
                legacyDigest: phoneBedNFCTag
            ) ?? PhoneBedTagLibrary()
            save(migrated, key: phoneBedNFCTagLibraryKey)
            defaults.removeObject(forKey: phoneBedNFCTagKey)
            defaults.removeObject(forKey: phoneBedNFCTagRegistrationKey)
            return migrated
        }
        set {
            save(newValue, key: phoneBedNFCTagLibraryKey)
            defaults.removeObject(forKey: phoneBedNFCTagKey)
            defaults.removeObject(forKey: phoneBedNFCTagRegistrationKey)
        }
    }

    func resetPhoneBedNFCTag() {
        defaults.removeObject(forKey: phoneBedNFCTagKey)
        defaults.removeObject(forKey: phoneBedNFCTagRegistrationKey)
        defaults.removeObject(forKey: phoneBedNFCTagLibraryKey)
    }

    var nightWatchPreferences: NightWatchPreferences {
        get { load(NightWatchPreferences.self, key: nightWatchPreferencesKey) ?? .defaults }
        set { save(newValue, key: nightWatchPreferencesKey) }
    }

    var automaticWindDownSchedule: AutomaticWindDownSchedule? {
        get { load(AutomaticWindDownSchedule.self, key: automaticWindDownScheduleKey) }
        set { save(newValue, key: automaticWindDownScheduleKey) }
    }

    /// A scheduled Wind Down that could not safely begin because the current
    /// Screen Time consent or opaque selection needs repair. This is local UI
    /// state only; it is never shield evidence or a fabricated run.
    var automaticWindDownProtectionRepairNeeded: Bool {
        get { defaults.bool(forKey: automaticWindDownProtectionRepairKey) }
        set { defaults.set(newValue, forKey: automaticWindDownProtectionRepairKey) }
    }

    /// The versioned schedule is the source of truth. The two older keys are
    /// read only as a migration path so a saved routine or one-time adjustment
    /// survives the first launch after this schema change.
    var windDownSchedule: WindDownScheduleState {
        get {
            if let stored = load(WindDownScheduleState.self, key: windDownScheduleKey) {
                return stored
            }

            let legacyRoutines = load([WindDownRoutine].self, key: windDownRoutinesKey)
                ?? (nightWatchPreferences.isConfigured
                    ? [WindDownRoutine.primary(from: nightWatchPreferences)]
                    : [])
            let migrated = WindDownScheduleState.migrated(
                routines: legacyRoutines,
                nextOverride: load(NextWindDownOverride.self, key: nextWindDownOverrideKey)
            )
            save(migrated, key: windDownScheduleKey)
            return migrated
        }
        set {
            save(newValue, key: windDownScheduleKey)
            // Keep legacy readers harmlessly in sync for rollback and old
            // extensions. New code reads only the versioned state above.
            save(newValue.routines, key: windDownRoutinesKey)
            if let first = newValue.oneTimePeriods
                .filter(\.isAvailable)
                .sorted(by: { $0.interval.start < $1.interval.start })
                .first {
                let override = NextWindDownOverride(
                    id: first.id,
                    routineID: first.role == .primarySleepBookend
                        ? (newValue.routines.first(where: { $0.role == .primarySleepBookend })?.id ?? first.id)
                        : first.id,
                    role: first.role,
                    interval: first.interval,
                    createdAt: Date(),
                    expiresAt: first.interval.end
                )
                save(override, key: nextWindDownOverrideKey)
            } else {
                defaults.removeObject(forKey: nextWindDownOverrideKey)
            }
        }
    }

    /// The plural schedule is additive. Existing installs migrate their saved
    /// primary preferences into one routine without rewriting the legacy key.
    var windDownRoutines: [WindDownRoutine] {
        get { windDownSchedule.routines }
        set {
            var state = windDownSchedule
            state.routines = newValue
            windDownSchedule = state
        }
    }

    var nextWindDownOverride: NextWindDownOverride? {
        get {
            if let legacy = load(NextWindDownOverride.self, key: nextWindDownOverrideKey) {
                return legacy
            }
            guard let first = windDownSchedule.oneTimePeriods
                .filter(\.isAvailable)
                .sorted(by: { $0.interval.start < $1.interval.start })
                .first else { return nil }
            return NextWindDownOverride(
                id: first.id,
                routineID: first.id,
                role: first.role,
                interval: first.interval,
                expiresAt: first.interval.end
            )
        }
        set {
            var state = windDownSchedule
            state.oneTimePeriods.removeAll()
            if let newValue {
                state.oneTimePeriods = [WindDownOneTimePeriod(
                    id: newValue.id,
                    title: newValue.role == .primarySleepBookend ? "Adjusted Wind Down" : "Phone Away",
                    role: newValue.role,
                    interval: newValue.interval,
                    enabled: newValue.consumedAt == nil
                )]
            }
            windDownSchedule = state
        }
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

    /// Domain authority for hidden Wind Down settlement and independent
    /// Screen-Free Morning/Sunrise replay markers. Farm, history, and search
    /// state remain projections so an overnight result cannot surface early.
    var windDownMorningSettlementJournal: WindDownMorningSettlementJournal {
        get {
            load(WindDownMorningSettlementJournal.self, key: windDownMorningSettlementJournalKey)
                ?? WindDownMorningSettlementJournal()
        }
        set { save(newValue, key: windDownMorningSettlementJournalKey) }
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
        save(Optional<NightWatchHistory>.none, key: nightWatchHistoryKey)
    }

    /// Clears local ritual progression while leaving the person's setup and physical
    /// phone-bed pairing intact so a fresh trail does not require reconfiguration.
    @discardableResult
    func resetLocalProgress() -> Bool {
        do { try farmSaveStore.reset() } catch { farmSaveStore.reject(error); return false }
        [
            progressKey,
            rewardsKey,
            thresholdKey,
            lastRunKey,
            manualAnalyticsKey,
            morningCheckInsKey,
            nightWatchHistoryKey,
            windDownMorningSettlementJournalKey,
            impactUploadRecordsKey,
            sheepSearchStateKey,
            farmStateKey,
            farmPastureSceneKey,
            userProfileKey,
            explicitSocialAvatarSelectionKey,
            welcomeRewardLedgerKey,
            nightFlockRewardLedgerKey,
            windDownProfileKey
        ].forEach { defaults.removeObject(forKey: $0) }
        return true
    }

    /// Removes every user-facing Counting Sheep value stored in the standard
    /// defaults suite. App Group values and runtime side effects are cleared by
    /// their owning services so each boundary remains explicit and testable.
    @discardableResult
    func resetLocalProductData() -> Bool {
        do { try farmSaveStore.reset() } catch { farmSaveStore.reject(error); return false }
        CountingSheepOwnedStorage.clearStandardDefaults(defaults)
        return true
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

    var appearancePreference: AppAppearancePreference {
        get {
            guard let rawValue = defaults.string(forKey: AppAppearancePreference.key) else {
                return .automatic
            }
            return AppAppearancePreference(rawValue: rawValue) ?? .automatic
        }
        set {
            defaults.set(newValue.rawValue, forKey: AppAppearancePreference.key)
        }
    }

    var sheepSearchState: SheepSearchState {
        get {
            if let stored = load(SheepSearchState.self, key: sheepSearchStateKey) {
                return stored
            }
            // Existing installs keep their protected-night count. Give the Trail Board a
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

    var farmState: FarmState {
        get {
            let stored = load(FarmState.self, key: farmStateKey) ?? .empty
            guard farmSaveStore.failure == nil,
                  (try? farmSaveStore.snapshot().effectiveScope) != .signedOut else { return stored }
            let search = sheepSearchState
            let ledger = welcomeRewardLedger
            // Search settlement is persisted before Farm projection. Replaying
            // found outcomes and the one-time starter grant here closes the
            // termination window between those local writes.
            let reconciled = WelcomeRewardEngine.reconcile(
                farm: stored,
                search: search,
                ledger: ledger
            )
            do {
                try farmSaveStore.transaction {
                    if reconciled.search != search { save(reconciled.search, key: sheepSearchStateKey) }
                    if reconciled.ledger != ledger { save(reconciled.ledger, key: welcomeRewardLedgerKey) }
                    if stored != reconciled.farm { save(reconciled.farm, key: farmStateKey) }
                }
            } catch {
                return stored
            }
            return reconciled.farm
        }
        set {
            save(newValue, key: farmStateKey)
            // Profile getters derive from committed Farm state. Do not persist
            // a new appearance while an outer Farm transaction can still fail.
        }
    }

    /// The curated profile remains separate from Farm progression, but its local
    /// appearance follows the current Farm look before any future transport uses it.
    var userProfile: CountingSheepUserProfile {
        get {
            guard farmSaveStore.hasReadableSave,
                  (try? farmSaveStore.snapshot().effectiveScope) != .signedOut else {
                return CountingSheepUserProfile(displayName: "")
            }
            let farm = farmState
            let stored = load(CountingSheepUserProfile.self, key: userProfileKey)
                ?? CountingSheepUserProfile(displayName: "")
            let synchronized = profile(stored, synchronizedWith: farm)
            if stored != synchronized || load(CountingSheepUserProfile.self, key: userProfileKey) == nil {
                save(synchronized, key: userProfileKey)
            }
            return synchronized
        }
        set { save(newValue, key: userProfileKey) }
    }

    /// Keeps a deliberate default-Shepherd choice distinct from a pristine
    /// profile, so a restored account may adopt its server identity once.
    var hasExplicitSocialAvatarSelection: Bool {
        get { load(Bool.self, key: explicitSocialAvatarSelectionKey) ?? false }
        set { save(newValue, key: explicitSocialAvatarSelectionKey) }
    }

    /// Character placement is visual preference, kept separate from Farm
    /// progression so a drag never changes the FarmState schema.
    var farmPastureSceneSnapshot: PastureSceneSnapshot? {
        get { load(PastureSceneSnapshot.self, key: farmPastureSceneKey) }
        set { save(newValue, key: farmPastureSceneKey) }
    }

    private func profile(
        _ profile: CountingSheepUserProfile,
        synchronizedWith farm: FarmState
    ) -> CountingSheepUserProfile {
        var synchronized = profile
        var presentation = CountingSheepPublicPresentation.defaultValue
        presentation.headShapeID = farm.shepherd.headShape.rawValue
        presentation.skinToneID = allowedProfileID(
            farm.shepherd.skinTone.rawValue,
            in: CountingSheepPublicPresentationAllowlist.skinToneIDs,
            fallback: CountingSheepPublicPresentation.defaultValue.skinToneID
        )
        presentation.hairStyleID = allowedProfileID(
            farm.shepherd.hairStyle.rawValue,
            in: CountingSheepPublicPresentationAllowlist.hairStyleIDs,
            fallback: CountingSheepPublicPresentation.defaultValue.hairStyleID
        )
        presentation.shepherdOutfitID = allowedProfileID(
            farm.shepherd.outfitItemID,
            in: CountingSheepPublicPresentationAllowlist.shepherdOutfitIDs,
            fallback: "none"
        )
        presentation.shepherdAccessoryID = allowedProfileID(
            farm.shepherd.accessoryItemID,
            in: CountingSheepPublicPresentationAllowlist.shepherdAccessoryIDs,
            fallback: "none"
        )
        presentation.ollieOrnamentID = allowedProfileID(
            farm.equipment.ollieAccessoryItemID,
            in: CountingSheepPublicPresentationAllowlist.ollieOrnamentIDs,
            fallback: "none"
        )
        let featured = farm.activeSheep.first(where: \.isFavorite) ?? farm.activeSheep.first
        presentation.featuredSheepDefinitionID = allowedProfileID(
            featured?.definitionID,
            in: CountingSheepPublicPresentationAllowlist.featuredSheepDefinitionIDs,
            fallback: "none"
        )
        presentation.pastureThemeID = allowedProfileID(
            profile.presentation.pastureThemeID,
            in: CountingSheepPublicPresentationAllowlist.pastureThemeIDs,
            fallback: CountingSheepPublicPresentation.defaultValue.pastureThemeID
        )
        // A person chooses this social identity explicitly. It must not follow
        // the favorite or active flock when sheep are traded or released.
        presentation.avatarID = profile.presentation.avatarID
        synchronized.presentation = presentation
        return synchronized
    }

    private func allowedProfileID(
        _ value: String?,
        in allowlist: Set<String>,
        fallback: String
    ) -> String {
        guard let value, allowlist.contains(value) else { return fallback }
        return value
    }

    var welcomeRewardLedger: WelcomeRewardLedger {
        get { load(WelcomeRewardLedger.self, key: welcomeRewardLedgerKey) ?? .empty }
        set { save(newValue, key: welcomeRewardLedgerKey) }
    }

    var nightFlockRewardLedger: NightFlockRewardLedger {
        get { load(NightFlockRewardLedger.self, key: nightFlockRewardLedgerKey) ?? .empty }
        set { save(newValue, key: nightFlockRewardLedgerKey) }
    }

    var windDownProfileRecord: WindDownProfileRecord? {
        get { load(WindDownProfileRecord.self, key: windDownProfileKey) }
        set { save(newValue, key: windDownProfileKey) }
    }

    /// Removes only the records held by the current Farm scope. The optional
    /// identity fence keeps an async cloud deletion for one account from
    /// erasing a different account after a local account transition.
    @discardableResult
    func deleteImpactUploadRecords(
        expectedScope: AccountFarmScope? = nil,
        expectedLineageID: UUID? = nil
    ) -> Bool {
        deleteImpactSharingState(
            includePreferences: false,
            expectedScope: expectedScope,
            expectedLineageID: expectedLineageID
        )
    }

    /// The local acknowledgement of a successful remote deletion commits the
    /// preference and its upload ledger together in the active account scope.
    @discardableResult
    func deleteSharedImpactData(
        expectedScope: AccountFarmScope,
        expectedLineageID: UUID
    ) -> Bool {
        deleteImpactSharingState(
            includePreferences: true,
            expectedScope: expectedScope,
            expectedLineageID: expectedLineageID
        )
    }

    private func deleteImpactSharingState(
        includePreferences: Bool,
        expectedScope: AccountFarmScope?,
        expectedLineageID: UUID?
    ) -> Bool {
        do {
            try farmSaveStore.transaction {
                let active = try farmSaveStore.snapshot()
                guard active.effectiveScope != .signedOut,
                      expectedScope.map({ active.effectiveScope == $0 }) ?? true,
                      expectedLineageID.map({ active.lineageID == $0 }) ?? true
                else { throw FarmSaveError.unavailable }
                if includePreferences {
                    try farmSaveStore.setLocalData(nil, for: impactSharingPreferencesKey)
                }
                try farmSaveStore.setLocalData(nil, for: impactUploadRecordsKey)
            }
            return true
        } catch {
            return false
        }
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

    var orientationState: CountingSheepOrientationState {
        get { load(CountingSheepOrientationState.self, key: orientationStateKey) ?? .fresh }
        set { save(newValue, key: orientationStateKey) }
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
        let data = FarmSaveDocument.keys.contains(key)
            ? farmSaveStore.data(for: key) : (AccountFarmLocalKeys.all.contains(key)
                ? farmSaveStore.localData(for: key) : defaults.data(forKey: key))
        guard let data else { return nil }
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
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try value.map { try encoder.encode($0) }
            if FarmSaveDocument.keys.contains(key) {
                try farmSaveStore.set(data, for: key)
            } else if AccountFarmLocalKeys.all.contains(key) {
                try farmSaveStore.setLocalData(data, for: key)
            } else if let data {
                defaults.set(data, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        } catch {
            // Encoding failure is not an intentional deletion. Preserve the
            // previous value and fail the entire surrounding Farm transaction.
            farmSaveStore.reject(error)
        }
    }
}
