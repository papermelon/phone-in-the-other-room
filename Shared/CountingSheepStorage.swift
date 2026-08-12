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
        "ollie.nightWatch.preferences",
        "ollie.nightWatch.automaticSchedule",
        "ollie.nightWatch.schedule",
        "ollie.nightWatch.routines",
        "ollie.nightWatch.nextOverride",
        "ollie.offlinePurpose",
        "ollie.screenTime.reportPreferences",
        "ollie.morningCheckIns",
        "ollie.nightWatch.history",
        "ollie.impactSharing.preferences",
        "ollie.impactSharing.records",
        "ollie.sheepSearch.state",
        "ollie.farm.state",
        "ollie.nightFlock.outbox",
        "ollie.nightFlock.runContexts",
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
        QuietTimeShieldSharedStorage.statusKey,
        QuietTimeShieldSharedStorage.statusHistoryKey,
        QuietTimeShieldSharedStorage.briefAccessStateKey
    ] + ScreenTimeSelectionScope.allCases.map {
        ScreenTimeSharedStorage.selectionKey(for: $0)
    }

    /// This identity is transport metadata rather than user product state. It
    /// remains stable so a local reset does not re-identify optional remote
    /// Live Activity delivery records; remote deletion is a separate operation.
    static let preservedTransportKeys = ["ollie.installationID"]

    static func clearStandardDefaults(_ defaults: UserDefaults) {
        standardKeys.forEach { defaults.removeObject(forKey: $0) }
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
