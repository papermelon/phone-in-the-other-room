import Foundation

protocol MorningCheckInChoice: Identifiable, Hashable {
    var title: String { get }
}

enum SleepOnsetEstimate: String, Codable, CaseIterable, MorningCheckInChoice {
    case under15
    case fifteenTo30
    case thirtyTo60
    case over60
    case notSure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .under15: return "Under 15 minutes"
        case .fifteenTo30: return "15–30 minutes"
        case .thirtyTo60: return "30–60 minutes"
        case .over60: return "More than an hour"
        case .notSure: return "Not sure"
        }
    }
}

enum MorningRestfulness: String, Codable, CaseIterable, MorningCheckInChoice {
    case notMuch
    case somewhat
    case rested
    case notSure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notMuch: return "Not much"
        case .somewhat: return "Somewhat"
        case .rested: return "Rested"
        case .notSure: return "Not sure"
        }
    }
}

enum BedtimeSleepiness: String, Codable, CaseIterable, MorningCheckInChoice {
    case sleepy
    case notSleepy
    case notSure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleepy: return "I felt sleepy"
        case .notSleepy: return "I was not sleepy yet"
        case .notSure: return "Not sure"
        }
    }
}

struct MorningCheckIn: Codable, Equatable, Identifiable {
    var day: Date
    var sleepOnset: SleepOnsetEstimate?
    var restfulness: MorningRestfulness?
    var bedtimeSleepiness: BedtimeSleepiness?

    var id: Date { day }
    var isEmpty: Bool {
        sleepOnset == nil && restfulness == nil && bedtimeSleepiness == nil
    }

    var summary: String {
        let answered = [sleepOnset != nil, restfulness != nil, bedtimeSleepiness != nil]
            .filter { $0 }
            .count
        return answered == 0 ? "Three optional reflections" : "\(answered) of 3 answered"
    }
}

struct MorningCheckInHistory: Codable, Equatable {
    private(set) var entries: [MorningCheckIn]

    init(entries: [MorningCheckIn] = [], calendar: Calendar = .current) {
        var unique: [Date: MorningCheckIn] = [:]
        for entry in entries where !entry.isEmpty {
            var normalized = entry
            normalized.day = calendar.startOfDay(for: entry.day)
            unique[normalized.day] = normalized
        }
        self.entries = Array(unique.values)
            .sorted { $0.day > $1.day }
            .prefix(45)
            .map { $0 }
    }

    func entry(for date: Date, calendar: Calendar = .current) -> MorningCheckIn? {
        entries.first { calendar.isDate($0.day, inSameDayAs: date) }
    }

    mutating func upsert(_ entry: MorningCheckIn, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: entry.day)
        entries.removeAll { calendar.isDate($0.day, inSameDayAs: day) }
        if !entry.isEmpty {
            var normalized = entry
            normalized.day = day
            entries.append(normalized)
        }
        entries.sort { $0.day > $1.day }
        entries = Array(entries.prefix(45))
    }
}
