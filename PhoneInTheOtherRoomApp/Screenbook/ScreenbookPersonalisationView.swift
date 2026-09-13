#if DEBUG
import SwiftUI

/// Pure synthetic content for compact-screen and accessibility captures.
struct ScreenbookPersonalisationView: View {
    private var goal: RitualGoal {
        RitualGoal(mode: .morning, kind: .personal,
                   wording: "A little time for myself after my night shift, while staying available for family", now: Date())
    }
    private var plan: RitualPlanRevision {
        RitualPlanRevision(goal: goal, preferences: .defaults, support: WindDownHabitPlan(morningCue: "After opening the curtains"), now: Date())
    }
    var body: some View {
        Group {
            if ProcessInfo.processInfo.arguments.contains("-personalisation-review") {
                RitualPlanReview(plan: plan, suggestion: nil, onSave: { _, _, _ in false })
            } else if ProcessInfo.processInfo.arguments.contains("-personalisation-reflection") {
                NavigationStack {
                    ScrollView {
                        WindDownHabitReflectionContent(reflection: reflection, plans: [plan], initiallyExpanded: true, onSave: { _, _ in false })
                            .padding(AppSpacing.md)
                    }.background(AppColors.paper)
                }
            } else {
                RitualGoalEditor(goal: goal, onSave: { _, _, _ in false })
            }
        }
    }
    private var reflection: WindDownHabitReflection {
        var note = WindDownHabitReflection(day: Date(), obstacle: .neededPhone, mode: .morning)
        note.experience = RitualExperienceFeedback(answer: .notSure, recordedAt: Date(), timeZoneIdentifier: "Asia/Singapore")
        return note
    }
}
#endif
