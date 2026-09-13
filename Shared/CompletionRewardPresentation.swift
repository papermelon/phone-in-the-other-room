import Foundation

/// A terminal presentation of saved rewards; it never resolves or grants one.
struct CompletionRewardPresentation: Equatable {
    let headline: String
    let detail: String
    let sheepID: String?
    let actionTitle: String
    let progressFraction: Double?
    let progressLabel: String?

    init(outcome: SheepSearchOutcome?, credit: FarmCreditReceipt?,
         isPhoneAway: Bool, isPractice: Bool = false, bankedSeconds: TimeInterval? = nil) {
        sheepID = outcome?.result == .found ? outcome?.sheepID : nil
        if let outcome {
            headline = outcome.result == .found ? "Ollie found a sheep" : "Ollie brought back a clue"
            detail = "A new entry in your Search Journal."
            actionTitle = outcome.result == .found ? "Meet your sheep" : "Open Search Journal"
            progressFraction = nil
            progressLabel = nil
        } else {
            let hasCredit = credit.map { $0.creditedSeconds > 0 && !$0.trackingIncomplete } ?? false
            headline = hasCredit ? "Your Farm keeps growing"
                : isPractice ? "Practice finished"
                : isPhoneAway ? "Phone Away finished" : "Wind Down finished"
            detail = hasCredit ? "Your progress carries forward." : "Your timer record is saved."
            actionTitle = "Visit the Farm"
            if hasCredit, let bankedSeconds, bankedSeconds.isFinite {
                let target = isPhoneAway ? CumulativeFarmCredit.phoneAwaySearchSeconds : CumulativeFarmCredit.windDownSearchSeconds
                let bounded = min(target, max(0, bankedSeconds))
                progressFraction = bounded / target
                progressLabel = "\(Int(bounded / 60)) / \(Int(target / 60)) min toward the next search"
            } else {
                progressFraction = nil
                progressLabel = nil
            }
        }
    }
}
