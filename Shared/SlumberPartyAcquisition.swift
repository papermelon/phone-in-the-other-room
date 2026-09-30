import Foundation

/// Keep the same command identity after an uncertain response. Repeated taps
/// cannot create duplicate parties or replace the staged agreement in flight.
struct SlumberPartyAcquisition: Codable, Equatable {
    enum Intent: Codable, Equatable {
        case create(name: String, timeZone: String)
        case join(code: String)
        case invitation(UUID)
    }
    private(set) var intent: Intent?
    private(set) var commandID: UUID?
    private(set) var isBusy = false
    private(set) var acceptedPartyID: UUID?

    mutating func begin(_ intent: Intent) -> UUID? {
        guard !isBusy else { return nil }
        if self.intent != intent || commandID == nil {
            self.intent = intent
            commandID = UUID()
        }
        isBusy = true
        acceptedPartyID = nil
        return commandID
    }

    mutating func dismissAcknowledgement() { acceptedPartyID = nil }

    mutating func finish(partyID: UUID? = nil, rejected: Bool = false) {
        isBusy = false
        if rejected { intent = nil; commandID = nil }
        if let partyID {
            acceptedPartyID = partyID
            intent = nil
            commandID = nil
        }
    }
}
