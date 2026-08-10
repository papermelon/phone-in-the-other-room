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
}
