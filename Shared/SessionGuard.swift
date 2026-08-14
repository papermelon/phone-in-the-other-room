import Foundation

/// The ritual used to begin a phone-away session. A guard confirms the start of the
/// ritual; the iPhone remains authoritative for time and completion.
enum SessionGuardKind: String, Codable, CaseIterable, Identifiable {
    case honorTimer
    case watchPlacement
    case qrCode
    case nfcTag

    var id: String { rawValue }

    var title: String {
        switch self {
        case .honorTimer: return "Phone-away timer"
        case .watchPlacement: return "Apple Watch assist"
        case .qrCode: return "Wind Down code"
        case .nfcTag: return "Wind Down tag"
        }
    }

    var detail: String {
        switch self {
        case .honorTimer: return "A simple timer for the walk to another room. No NFC tag needed."
        case .watchPlacement: return "Ollie watches the phone head away, then rests."
        case .qrCode: return "Scan your Wind Down code to confirm the app-access barrier."
        case .nfcTag: return "Tap your Wind Down tag to set the app-access barrier."
        }
    }

    var compactTitle: String {
        switch self {
        case .honorTimer: return "Timer"
        case .watchPlacement: return "Watch"
        case .qrCode: return "Wind Down code"
        case .nfcTag: return "Wind Down tag"
        }
    }

    var systemImage: String {
        switch self {
        case .honorTimer: return "timer"
        case .watchPlacement: return "applewatch"
        case .qrCode: return "qrcode.viewfinder"
        case .nfcTag: return "dot.radiowaves.left.and.right"
        }
    }

    var needsPlacementConfirmation: Bool {
        self == .watchPlacement || self == .qrCode || self == .nfcTag
    }
}

/// The two protection choices shown in current release configuration UI. The
/// older guard kinds remain above for backwards decoding and active-run support.
enum WindDownProtectionChoice: String, CaseIterable, Identifiable, Equatable {
    case appShielding
    case nfcAndAppShielding

    var id: String { rawValue }

    var guardKind: SessionGuardKind {
        switch self {
        case .appShielding: return .honorTimer
        case .nfcAndAppShielding: return .nfcTag
        }
    }

    var title: String {
        switch self {
        case .appShielding: return "App limits"
        case .nfcAndAppShielding: return "NFC + app limits"
        }
    }

    var detail: String {
        switch self {
        case .appShielding:
            return "App limits run from Wind Down start through morning quiet. Counting Sheep stays available, with an emergency exit if you need your phone back sooner."
        case .nfcAndAppShielding:
            return "Tap your Wind Down tag to start the barrier; app limits stay active through morning quiet. Counting Sheep stays available, with an emergency exit if you need your phone back sooner."
        }
    }

    var systemImage: String {
        switch self {
        case .appShielding: return "iphone.slash"
        case .nfcAndAppShielding: return "dot.radiowaves.left.and.right"
        }
    }

    static func from(guardKind: SessionGuardKind) -> Self {
        guardKind == .nfcTag ? .nfcAndAppShielding : .appShielding
    }
}

extension SessionGuardKind {
    /// Maps retired UI choices to the current no-hardware protection choice.
    var releaseCompatibleKind: Self {
        self == .nfcTag ? .nfcTag : .honorTimer
    }
}

/// Keeps manual Wind Down start actions idempotent while an NFC reader session
/// is already in flight. The decision is pure so the UI start path can be tested
/// without Core NFC or SwiftUI.
enum WindDownStartGate {
    static func canPresentPreflight(isRunning: Bool, startInFlight: Bool) -> Bool {
        !isRunning && !startInFlight
    }

    static func canBeginNFCRead(
        forPendingStart: Bool,
        hasActiveRun: Bool,
        startInFlight: Bool,
        scanInFlight: Bool
    ) -> Bool {
        guard !startInFlight, !scanInFlight else { return false }
        return forPendingStart ? !hasActiveRun : hasActiveRun
    }
}

enum PlacementStatus: String, Codable, Equatable {
    case notRequired
    case awaitingConfirmation
    case confirmed
    case unavailable
}

struct PlacementEvidence: Codable, Equatable {
    var guardKind: SessionGuardKind
    var confirmedAt: Date?
    var note: String

    static func notRequired(for kind: SessionGuardKind) -> PlacementEvidence {
        PlacementEvidence(guardKind: kind, confirmedAt: nil, note: "")
    }
}

struct FocusRunConfiguration: Equatable {
    var duration: TimeInterval
    var guardKind: SessionGuardKind
    var nightWatchPlan: NightWatchPlan?
    var isPractice: Bool

    init(duration: TimeInterval, guardKind: SessionGuardKind, isPractice: Bool = false) {
        self.duration = max(FocusRunRules.minimumMeaningfulDurationSeconds, duration)
        self.guardKind = guardKind
        self.nightWatchPlan = nil
        self.isPractice = isPractice
    }

    init(nightWatchPlan: NightWatchPlan, guardKind: SessionGuardKind, isPractice: Bool = false) {
        self.duration = 0
        self.guardKind = guardKind
        self.nightWatchPlan = nightWatchPlan
        self.isPractice = isPractice
    }
}
