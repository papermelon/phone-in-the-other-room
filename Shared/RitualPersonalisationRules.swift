import Foundation

/// Rules consume only explicit, dated feedback about the current confirmed plan.
/// Timer history, access events, sleep, and rewards are deliberately not inputs.
enum RitualPersonalisationRules {
    static func refresh(_ state: inout RitualPersonalisation, history: WindDownHabitReflectionHistory, now: Date) {
        state.prune(now: now)
        guard let plan = state.currentPlan else { state.supersedeSuggestions(); return }
        let evidence = history.entries.filter {
            guard let feedback = $0.experience, feedback.planID == plan.id,
                  [.partly, .notToday].contains(feedback.answer),
                  feedback.recordedAt <= now, feedback.recordedAt >= now.addingTimeInterval(-28 * 86_400),
                  let date = $0.localDate?.date(in: "UTC"),
                  let today = NightFlockLocalDate(date: now, timeZoneIdentifier: feedback.timeZoneIdentifier)?.date(in: "UTC"),
                  date <= today, date >= today.addingTimeInterval(-28 * 86_400),
                  $0.mode == plan.goal.mode else { return false }
            return true
        }
        let evidenceIDs = Set(evidence.compactMap { $0.experience?.id })
        for index in state.suggestions.indices where [.proposed, .deferred].contains(state.suggestions[index].status) {
            let suggestion = state.suggestions[index]
            if suggestion.targetPlanID != plan.id || suggestion.expiresAt <= now
                || !Set(suggestion.evidenceIDs).isSubset(of: evidenceIDs) {
                state.suggestions[index].status = .superseded
            }
        }
        if state.suggestions.contains(where: { [.proposed, .deferred].contains($0.status) }) { return }
        // Stable priority; one understandable offer at a time, with two distinct civil days.
        for action in RitualAdjustmentAction.allCases where !state.rejectedActions.contains(action) {
            let matching = evidence.filter { entry in
                switch action {
                case .simplify: return plan.activities.count > 1 && [.tooMuch, .rushed].contains(entry.obstacle)
                case .swapActivity: return entry.obstacle == .notAppealing
                case .cue: return entry.obstacle == .forgot && plan.cue == nil
                case .preparation: return false // Unclassified obstacles do not justify guessing an adjustment.
                }
            }.sorted { $0.day > $1.day }
            var days = Set<NightFlockLocalDate>()
            let distinct = matching.filter { entry in
                guard let day = entry.localDate else { return false }
                return days.insert(day).inserted
            }
            guard distinct.count >= 2 else { continue }
            let selected = Array(distinct.prefix(2))
            let ids = selected.compactMap { $0.experience?.id }
            // Expired or superseded evidence cannot endlessly regenerate the same offer.
            guard !state.suggestions.contains(where: { $0.action == action && Set($0.evidenceIDs) == Set(ids) }) else { continue }
            let observation: String
            switch action {
            case .simplify: observation = "You reported too much to fit in or feeling rushed on two days."
            case .swapActivity: observation = "You wanted a different activity on two days."
            case .cue: observation = "You said it slipped your mind on two days."
            case .preparation: observation = "On two days, you noted something else got in the way. You could decide whether preparing something would help."
            }
            state.suggestions.append(RitualSuggestion(
                id: UUID(), ruleVersion: 1, action: action, evidenceIDs: ids, targetPlanID: plan.id,
                reason: observation, createdAt: now, expiresAt: now.addingTimeInterval(14 * 86_400), status: .proposed
            ))
            return
        }
    }

    static func visibleSuggestion(_ state: RitualPersonalisation, now: Date) -> RitualSuggestion? {
        state.suggestions.first {
            $0.targetPlanID == state.currentPlan?.id && $0.expiresAt > now &&
            ($0.status == .proposed || ($0.status == .deferred && now >= ($0.deferredUntil ?? .distantFuture)))
        }
    }

    static func respond(_ state: inout RitualPersonalisation, suggestionID: UUID,
                        status: RitualSuggestion.Status, now: Date) -> Bool {
        guard [.dismissed, .deferred].contains(status),
              let suggestion = visibleSuggestion(state, now: now), suggestion.id == suggestionID,
              let index = state.suggestions.firstIndex(where: { $0.id == suggestionID }) else { return false }
        state.suggestions[index].status = status
        if status == .dismissed, !state.rejectedActions.contains(suggestion.action) {
            state.rejectedActions.append(suggestion.action)
        }
        if status == .deferred { state.suggestions[index].deferredUntil = now.addingTimeInterval(7 * 86_400) }
        return true
    }
}
