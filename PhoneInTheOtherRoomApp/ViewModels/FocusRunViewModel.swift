import Foundation
import Combine

@MainActor
final class FocusRunViewModel: ObservableObject {
    @Published var selectedDuration: TimeInterval = 25 * 60
    @Published var durationMinutes = 25
    @Published var durationSeconds = 0
    @Published var showCustomDurationPicker = false
    @Published var showFocusModePrompt = false
    @Published var focusPromptAnswered = false
    @Published var focusAccepted = false
    @Published var focusGuidance = ""
    @Published var demoDistance: Double = 1.0
    @Published var customDurationSelected = false

    @Published var coordinator = ProximitySessionCoordinator()

    private let focusService = FocusModeSuggestionService()
    private let notifications = PhoneNotificationService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        coordinator.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        applyShortcutPreparationIfNeeded()
    }

    var activeRun: FocusRun? { coordinator.run }
    var isRunning: Bool {
        guard let state = activeRun?.state else { return false }
        return ![.setup, .completed, .endedEarly].contains(state)
    }

    func chooseDuration(minutes: Int) {
        durationMinutes = minutes
        durationSeconds = 0
        customDurationSelected = false
        updateSelectedDuration()
    }

    func chooseCustomDuration() {
        customDurationSelected = true
        showCustomDurationPicker = true
    }

    var selectedDurationLabel: String {
        let minutes = Int(selectedDuration / 60)
        let seconds = Int(selectedDuration) % 60
        if seconds == 0 { return "\(minutes) min" }
        if minutes == 0 { return "\(seconds) sec" }
        return "\(minutes) min \(seconds) sec"
    }

    func updateSelectedDuration() {
        selectedDuration = TimeInterval((durationMinutes * 60) + durationSeconds)
    }

    func applyShortcutPreparationIfNeeded() {
        guard let duration = FocusRunShortcutStore.consumePendingDuration() else { return }
        durationMinutes = Int(duration) / 60
        durationSeconds = Int(duration) % 60
        selectedDuration = duration
        customDurationSelected = !Self.presetMinutes.contains(durationMinutes) || durationSeconds != 0
        focusGuidance = "Shortcut prepared a \(selectedDurationLabel) Focus Run. Turn on Focus from your Shortcut, then tap Send Ollie Out."
    }

    func requestStartRun() {
        updateSelectedDuration()
        showFocusModePrompt = true
    }

    func answerFocusPrompt(_ accepted: Bool) {
        focusPromptAnswered = true
        focusAccepted = accepted
        focusGuidance = focusService.guidance(accepted: accepted)
    }

    func startRun(focusAccepted accepted: Bool) {
        answerFocusPrompt(accepted)
        coordinator.start(duration: max(1, selectedDuration), demoMode: false, focusAccepted: accepted)
        notifications.scheduleOpenWatchReminder()
        showFocusModePrompt = false
    }

    func updateDemoDistance(_ distance: Double) {
        demoDistance = distance
    }

    func resetSetup() {
        coordinator.resetToSetup()
        showCustomDurationPicker = false
        showFocusModePrompt = false
        focusPromptAnswered = false
        focusAccepted = false
        focusGuidance = ""
        demoDistance = 1.0
        customDurationSelected = false
    }

    private static let presetMinutes = [3, 10, 25, 60]
}
