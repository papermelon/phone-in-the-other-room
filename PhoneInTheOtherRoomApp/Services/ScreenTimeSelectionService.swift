import Foundation

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls

final class ScreenTimeSelectionService {
    static let shared = ScreenTimeSelectionService()

    private let defaults = UserDefaults.standard
    private let keyPrefix = "phoneOther.screenTime.selection."

    func load(_ scope: ScreenTimeSelectionScope) -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: key(for: scope)),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    func save(_ selection: FamilyActivitySelection, for scope: ScreenTimeSelectionScope) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: key(for: scope))
    }

    private func key(for scope: ScreenTimeSelectionScope) -> String {
        keyPrefix + scope.rawValue
    }
}

extension FamilyActivitySelection {
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
