import Foundation

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls

final class ScreenTimeSelectionService {
    static let shared = ScreenTimeSelectionService()

    private let sharedDefaults: UserDefaults
    private let legacyDefaults: UserDefaults

    init(
        sharedDefaults: UserDefaults? = UserDefaults(
            suiteName: ScreenTimeSharedStorage.appGroupIdentifier
        ),
        legacyDefaults: UserDefaults = .standard
    ) {
        self.sharedDefaults = sharedDefaults ?? legacyDefaults
        self.legacyDefaults = legacyDefaults
        migrateLegacySelectionsIfNeeded()
    }

    func load(_ scope: ScreenTimeSelectionScope) -> FamilyActivitySelection {
        guard let data = sharedDefaults.data(forKey: ScreenTimeSharedStorage.selectionKey(for: scope)),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection.appsAndCategoriesOnly
    }

    func save(_ selection: FamilyActivitySelection, for scope: ScreenTimeSelectionScope) {
        guard let data = try? JSONEncoder().encode(selection.appsAndCategoriesOnly) else { return }
        sharedDefaults.set(data, forKey: ScreenTimeSharedStorage.selectionKey(for: scope))
    }

    private func migrateLegacySelectionsIfNeeded() {
        for scope in ScreenTimeSelectionScope.allCases {
            let sharedKey = ScreenTimeSharedStorage.selectionKey(for: scope)
            guard sharedDefaults.data(forKey: sharedKey) == nil else { continue }

            let legacyKeys = [
                sharedKey,
                ScreenTimeSharedStorage.legacySelectionKey(for: scope)
            ]
            guard let legacyData = legacyKeys.lazy.compactMap({
                self.legacyDefaults.data(forKey: $0)
            }).first else {
                continue
            }
            sharedDefaults.set(legacyData, forKey: sharedKey)
        }
    }
}

extension FamilyActivitySelection {
    /// Apple's picker includes website activity and opaque identifiers alongside apps.
    /// Counting Sheep's reports are app/category based, so website tokens must not leak
    /// into persisted selections or DeviceActivity filters.
    var appsAndCategoriesOnly: FamilyActivitySelection {
        var normalized = self
        normalized.webDomainTokens.removeAll()
        return normalized
    }

    var phoneOtherIsEmpty: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }

    var phoneOtherSelectionSummary: String {
        let total = applicationTokens.count + categoryTokens.count + webDomainTokens.count
        guard total > 0 else { return "None selected" }

        var parts: [String] = []
        if !applicationTokens.isEmpty { parts.append("\(applicationTokens.count) apps") }
        if !categoryTokens.isEmpty { parts.append("\(categoryTokens.count) categories") }
        if !webDomainTokens.isEmpty { parts.append("\(webDomainTokens.count) sites") }
        return parts.joined(separator: ", ")
    }
}
#endif
