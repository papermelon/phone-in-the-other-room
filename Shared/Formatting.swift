import Foundation

enum OllieFormat {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func dateAndTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    static func timeRange(from start: Date, to end: Date) -> String {
        "\(time(start))–\(time(end))"
    }

    static func timer(_ seconds: TimeInterval) -> String {
        let remaining = max(0, Int(seconds.rounded()))
        if remaining >= 60 * 60 {
            return String(format: "%02d:%02d:%02d", remaining / 3600, (remaining % 3600) / 60, remaining % 60)
        }
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    static func minutes(_ seconds: TimeInterval) -> Int {
        max(0, Int(seconds / 60))
    }

    static func duration(minutes: Int) -> String {
        let value = max(0, minutes)
        if value < 60 { return "\(value) min" }
        return "\(value / 60)h \(value % 60)m"
    }

    /// A displayed mean is rounded only for reading; the stored derived value
    /// remains the server-provided arithmetic mean.
    static func approximateDuration(minutes: Double) -> String {
        guard minutes.isFinite else { return "—" }
        let value = max(0, minutes)
        guard value.rounded() != value else { return duration(minutes: Int(value)) }
        return "~\(duration(minutes: Int(value.rounded())))"
    }
}
