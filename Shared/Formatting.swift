import Foundation

enum OllieFormat {
    static func timer(_ seconds: TimeInterval) -> String {
        let remaining = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    static func minutes(_ seconds: TimeInterval) -> Int {
        max(0, Int(seconds / 60))
    }
}

