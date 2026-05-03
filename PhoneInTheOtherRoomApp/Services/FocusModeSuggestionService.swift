import Foundation

struct FocusModeSuggestionService {
    func guidance(accepted: Bool) -> String {
        if accepted {
            return "Open Control Center and turn on Focus, or connect Phone in the Other Room to a Shortcut. The run continues either way."
        }
        return "Focus skipped. Ollie can still run."
    }
}
