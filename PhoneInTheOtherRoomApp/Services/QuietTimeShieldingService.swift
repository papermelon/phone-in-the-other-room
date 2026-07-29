import Foundation

#if SCREEN_TIME_REPORTS && canImport(FamilyControls) && canImport(ManagedSettings)
import FamilyControls
import ManagedSettings
#endif

@MainActor
protocol QuietTimeShieldingProviding {
    func reconcile(for run: FocusRun?, at date: Date)
    func clear()
}

@MainActor
final class QuietTimeShieldingService: QuietTimeShieldingProviding {
    static let enabledKey = "ollie.screenTime.shielding.enabled"
    private let defaults: UserDefaults
#if SCREEN_TIME_REPORTS && canImport(FamilyControls) && canImport(ManagedSettings)
    private let store = ManagedSettingsStore(named: .init("ollie.quietTime"))
    private let selections = ScreenTimeSelectionService.shared
#endif

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func reconcile(for run: FocusRun?, at date: Date = Date()) {
        guard QuietTimeShieldingPolicy.shouldShield(
            run: run, at: date, isEnabled: developmentFeatureEnabled
        ) else { clear(); return }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls) && canImport(ManagedSettings)
        let selection = selections.load(.bedtime)
        guard !selection.phoneOtherIsEmpty else { clear(); return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
#endif
    }

    func clear() {
#if SCREEN_TIME_REPORTS && canImport(ManagedSettings)
        store.clearAllSettings()
#endif
    }

    private var developmentFeatureEnabled: Bool {
#if DEBUG
        defaults.bool(forKey: Self.enabledKey)
#else
        false
#endif
    }
}
