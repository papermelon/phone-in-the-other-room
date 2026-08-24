import Foundation

/// Bounded transport/presentation data for Watch, notifications, and Live
/// Activity. It deliberately cannot encode a sheep, reward, odds, or journal
/// benefit payload.
struct ScreenFreeMorningPresentation: Codable, Hashable, Identifiable {
    var id: UUID { occurrenceID }
    var occurrenceID: UUID
    var linkedWindDownRunID: UUID?
    var status: Status
    var startsAt: Date
    var endsAt: Date
    var actualEligibleMinutes: Int

    enum Status: String, Codable, Hashable {
        case scheduled
        case active
        case skipped
        case finished

        var title: String {
            switch self {
            case .scheduled: return "Screen-Free Morning planned"
            case .active: return "Screen-Free Morning"
            case .skipped: return "Screen-Free Morning skipped"
            case .finished: return "Screen-Free Morning finished"
            }
        }
    }

    init(occurrence: MorningQuietOccurrence, at date: Date = Date()) {
        occurrenceID = occurrence.id
        linkedWindDownRunID = occurrence.linkedWindDownRunID
        startsAt = occurrence.scheduledStart
        endsAt = occurrence.scheduledEnd
        actualEligibleMinutes = occurrence.eligibleElapsedMinutes(at: date)
        switch occurrence.outcome {
        case .scheduled: status = .scheduled
        case .active: status = .active
        case .skipped: status = .skipped
        case .finished: status = .finished
        }
    }

    var isActive: Bool { status == .active }
    var isDeferred: Bool { status == .scheduled }
}

enum ScreenFreeMorningPresentationRouting {
    static func current(
        occurrences: [MorningQuietOccurrence],
        at date: Date = Date()
    ) -> ScreenFreeMorningPresentation? {
        let active = occurrences.filter { $0.outcome == .active }
            .sorted { $0.scheduledStart < $1.scheduledStart }
            .first
        if let active { return ScreenFreeMorningPresentation(occurrence: active, at: date) }
        let deferred = occurrences.filter { $0.outcome == .scheduled }
            .sorted { $0.scheduledStart < $1.scheduledStart }
            .first
        return deferred.map { ScreenFreeMorningPresentation(occurrence: $0, at: date) }
    }
}

enum ScreenFreeMorningWatchPresentationPolicy {
    static func preferred(
        morning: ScreenFreeMorningPresentation?,
        run: FocusRun?
    ) -> ScreenFreeMorningPresentation? {
        guard let morning else { return nil }
        if morning.isActive { return morning }
        guard morning.status == .scheduled else { return nil }
        guard run == nil || [.completed, .endedEarly, .setup].contains(run?.state) else { return nil }
        return morning
    }
}
