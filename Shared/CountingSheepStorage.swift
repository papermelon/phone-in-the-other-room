import Foundation

/// Explicitly scoped local storage owned by Counting Sheep. Keeping this list
/// centralized makes a full reset auditable and prevents unrelated defaults from
/// being removed by a broad suite wipe.
enum CountingSheepOwnedStorage {
    static let standardKeys: [String] = [
        "ollie.progress",
        "ollie.rewards",
        "ollie.thresholds",
        "ollie.lastRun",
        "ollie.analytics.manualEntries",
        "ollie.phoneBedQRCode",
        "ollie.phoneBedNFCTag",
        "ollie.phoneBedNFCTag.registration",
        "ollie.phoneBedNFCTags.library",
        "ollie.nightWatch.preferences",
        "ollie.nightWatch.automaticSchedule",
        "ollie.nightWatch.schedule",
        "ollie.nightWatch.routines",
        "ollie.nightWatch.nextOverride",
        "ollie.offlinePurpose",
        "ollie.screenTime.reportPreferences",
        "ollie.morningCheckIns",
        "ollie.nightWatch.history",
        "ollie.windDownMorning.settlementJournal",
        "ollie.impactSharing.preferences",
        "ollie.impactSharing.records",
        "ollie.sheepSearch.state",
        "ollie.farm.state",
        "ollie.farm.pastureScene",
        "ollie.userProfile",
        "ollie.welcome.rewards",
        "ollie.windDown.profile",
        "ollie.nightFlock.outbox",
        "ollie.nightFlock.commitmentOutbox",
        "ollie.nightFlock.metricsOutbox",
        "ollie.nightFlock.v4SourceOutbox",
        "ollie.nightFlock.v4StatusOutbox",
        "ollie.nightFlock.rewards",
        "ollie.nightFlock.runContexts",
        "ollie.nightFlock.stagedDestructiveEffect",
        "ollie.nightFlock.acceptedAccountDeletion",
        "ollie.nightFlock.pendingDestructiveIntent",
        "ollie.nightFlock.pendingAccountDeletionIntent",
        "ollie.nightFlock.orientation",
        "ollie.nightFlock.expectedLinkedUserID",
        "ollie.orientation.state",
        "ollie.onboarding.version",
        "ollie.onboarding.draft",
        "ollie.notifications.preferences",
        "ollie.notifications.remindersEnabled",
        "ollie.notifications.pendingDestination",
        "ollie.health.sleep.requested",
        "ollie.liveActivity.enabled",
        "ollie.quietAppearance.enabled",
        "ollie.screenTime.shielding.enabled",
        AppAppearancePreference.key,
        "shortcut.pendingFocusRunDurationSeconds",
        "shortcut.pendingFocusRunPreparedAt"
    ] + ScreenTimeSelectionScope.allCases.map {
        ScreenTimeSharedStorage.legacySelectionKey(for: $0)
    }

    static let appGroupKeys: [String] = [
        QuietNoteText.storageKey,
        QuietTimeShieldSharedStorage.scheduleKey,
        QuietTimeShieldSharedStorage.registryKey,
        QuietTimeShieldSharedStorage.statusKey,
        QuietTimeShieldSharedStorage.statusHistoryKey,
        QuietTimeShieldSharedStorage.briefAccessStateKey,
        QuietTimeShieldPresentationStorage.purposeCueKey
    ] + ScreenTimeSelectionScope.allCases.map {
        ScreenTimeSharedStorage.selectionKey(for: $0)
    }

    static let dynamicStandardKeyPrefixes = [
        "ollie.emergencyExit.reason."
    ]

    /// This identity is transport metadata rather than user product state. It
    /// remains stable so a local reset does not re-identify optional remote
    /// Live Activity delivery records; remote deletion is a separate operation.
    static let preservedTransportKeys = ["ollie.installationID"]

    static func clearStandardDefaults(_ defaults: UserDefaults) {
        standardKeys.forEach { defaults.removeObject(forKey: $0) }
        defaults.dictionaryRepresentation().keys
            .filter { key in dynamicStandardKeyPrefixes.contains(where: key.hasPrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
    }

    static func clearAppGroupDefaults(_ defaults: UserDefaults) {
        appGroupKeys.forEach { defaults.removeObject(forKey: $0) }
    }

    static func clear(
        standardDefaults: UserDefaults,
        appGroupDefaults: UserDefaults?
    ) {
        clearStandardDefaults(standardDefaults)
        if let appGroupDefaults {
            clearAppGroupDefaults(appGroupDefaults)
        }
    }
}

enum CountingSheepRootRoute: Equatable {
    case freshOnboarding
    case resumeOnboarding
    case home

    static func resolve(
        onboardingVersion: Int,
        currentOnboardingVersion: Int,
        hasOnboardingDraft: Bool,
        hasConfiguredNightWatch: Bool,
        hasActiveRun: Bool
    ) -> Self {
        if hasActiveRun || hasConfiguredNightWatch || onboardingVersion >= currentOnboardingVersion {
            return .home
        }
        return hasOnboardingDraft ? .resumeOnboarding : .freshOnboarding
    }
}
