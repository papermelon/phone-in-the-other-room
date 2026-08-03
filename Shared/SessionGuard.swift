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
        case .qrCode: return "Scan phone bed"
        case .nfcTag: return "Tap phone bed"
        }
    }

    var detail: String {
        switch self {
        case .honorTimer: return "A simple timer for the walk to another room. No NFC tag needed."
        case .watchPlacement: return "Ollie watches the phone head away, then rests."
        case .qrCode: return "Scan a code where your phone sleeps."
        case .nfcTag: return "Tap the same tag to start and end Wind Down."
        }
    }

    var compactTitle: String {
        switch self {
        case .honorTimer: return "Timer"
        case .watchPlacement: return "Watch"
        case .qrCode: return "QR code"
        case .nfcTag: return "NFC tag"
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
        case .appShielding: return "App Shielding"
        case .nfcAndAppShielding: return "NFC + App Shielding"
        }
    }

    var detail: String {
        switch self {
        case .appShielding:
            return "Selected apps rest during both quiet windows. No tag needed."
        case .nfcAndAppShielding:
            return "A phone-bed tag confirms the phone is away while selected apps rest."
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

    init(duration: TimeInterval, guardKind: SessionGuardKind) {
        self.duration = max(60, duration)
        self.guardKind = guardKind
        self.nightWatchPlan = nil
    }

    init(nightWatchPlan: NightWatchPlan, guardKind: SessionGuardKind) {
        self.duration = 0
        self.guardKind = guardKind
        self.nightWatchPlan = nightWatchPlan
    }
}
