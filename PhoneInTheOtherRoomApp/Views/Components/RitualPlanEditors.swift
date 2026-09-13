import SwiftUI

struct RitualGoalEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mode: WindDownRoutinePhase
    @State private var kind: RitualGoalKind?
    @State private var wording: String
    @State private var failed = false
    let onSave: (WindDownRoutinePhase, RitualGoalKind?, String) -> Bool

    init(goal: RitualGoal?, onSave: @escaping (WindDownRoutinePhase, RitualGoalKind?, String) -> Bool) {
        _mode = State(initialValue: goal?.mode ?? .morning)
        _kind = State(initialValue: goal?.kind)
        _wording = State(initialValue: goal?.kind == .personal ? goal?.wording ?? "" : "")
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("What would you like to change?").font(AppTypography.headline)
                    Picker("Routine", selection: $mode) {
                        Text("Screen-Free Morning").tag(WindDownRoutinePhase.morning)
                        Text("Wind Down").tag(WindDownRoutinePhase.evening)
                    }.pickerStyle(.menu).frame(minHeight: 44)
                    Picker("One optional goal", selection: $kind) {
                        Text("No goal for now").tag(nil as RitualGoalKind?)
                        ForEach(RitualGoalKind.allCases.filter { $0.supports(mode) }) { goal in
                            Text(goal.title).tag(Optional(goal))
                        }
                    }.pickerStyle(.menu).frame(minHeight: 44)
                    if kind == .personal {
                        TextField("My own reason", text: Binding(get: { wording }, set: { wording = String($0.prefix(120)) }), axis: .vertical)
                            .font(AppTypography.body).lineLimit(2...5).frame(minHeight: 44)
                            .accessibilityLabel("My own reason, up to 120 characters")
                    }
                    if let activity = kind?.proposedActivity {
                        Text("An idea: \(activity)").font(AppTypography.body)
                    }
                    Text(kind == nil ? "You can choose a goal later." : "You’ll choose an activity next.")
                        .font(AppTypography.body).foregroundStyle(AppColors.muted)
                    if failed { RitualEditorSaveError() }
                    Button(kind == nil ? "Save choice" : "Save goal") {
                        if onSave(mode, kind, wording) { dismiss() } else { failed = true }
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: true)).frame(minHeight: 44)
                    .disabled(kind == .personal && wording.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(AppSpacing.md)
            }
            .tint(AppColors.grass)
            .background(AppColors.paper).navigationTitle("My goal").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } } }
            .onChange(of: mode) { _, _ in if let kind, !kind.supports(mode) { self.kind = nil } }
        }
    }
}

struct RitualPlanReview: View {
    @Environment(\.dismiss) private var dismiss
    let plan: RitualPlanRevision
    let suggestion: RitualSuggestion?
    let onSave: ([WindDownRoutineStep], String, String) -> Bool
    @State private var activity: String
    @State private var cue: String
    @State private var preparation: String
    @State private var failed = false
    private var changesActivity: Bool { suggestion == nil || [.simplify, .swapActivity].contains(suggestion?.action) }

    init(plan: RitualPlanRevision, suggestion: RitualSuggestion?, onSave: @escaping ([WindDownRoutineStep], String, String) -> Bool) {
        self.plan = plan; self.suggestion = suggestion; self.onSave = onSave
        let proposed = suggestion == nil ? plan.goal.kind.proposedActivity : nil
        _activity = State(initialValue: proposed ?? plan.activities.first?.title ?? "")
        _cue = State(initialValue: plan.cue ?? "")
        _preparation = State(initialValue: plan.support.preparation ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(suggestion?.action.title ?? "Try one small activity").font(AppTypography.headline)
                    Text(suggestion?.reason ?? plan.goal.kind.rationale).font(AppTypography.body)
                    DisclosureGroup("My goal") {
                        Text(plan.goal.wording).font(AppTypography.body).padding(.top, AppSpacing.xs)
                    }.font(AppTypography.body).frame(minHeight: 44)
                    if !plan.activities.isEmpty {
                        DisclosureGroup(changesActivity ? "Activities this replaces" : "My activities") {
                            ForEach(plan.activities) { Text($0.title).font(AppTypography.body) }
                        }.font(AppTypography.body).frame(minHeight: 44)
                    }
                    if changesActivity {
                        Menu("Choose an activity") {
                            ForEach(plan.goal.mode == .morning ? PhoneFreeActivity.morningChoices : PhoneFreeActivity.eveningChoices) { choice in
                                Button(choice.title) { activity = choice.title }
                            }
                            if suggestion?.action == .simplify {
                                ForEach(plan.activities) { step in Button(step.title) { activity = step.title } }
                            }
                        }.frame(minHeight: 44)
                        field("My activity", text: $activity, limit: PhoneFreeCue.maximumTextLength)
                    }
                    field("Begin after… (optional)", text: $cue, limit: 120)
                    if plan.goal.mode == .evening {
                        field("Get ready beforehand (optional)", text: $preparation, limit: 120)
                    }
                    Text("Timing and app protection stay the same.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.muted)
                    DisclosureGroup("Where my words appear") {
                        Text("Activity wording follows your Watch and Live Activity settings, including remote updates. Goals and reflections stay on this device.")
                            .font(AppTypography.caption).foregroundStyle(AppColors.muted)
                    }.font(AppTypography.caption).frame(minHeight: 44)
                    if failed { RitualEditorSaveError() }
                    Button("Save change") {
                        let steps: [WindDownRoutineStep]
                        if changesActivity {
                            let existing = plan.activities.first { $0.title == activity }
                            steps = [existing ?? .custom(activity, phase: plan.goal.mode)]
                        } else { steps = plan.activities }
                        if onSave(steps, cue, preparation) { dismiss() } else { failed = true }
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: true)).frame(minHeight: 44)
                    .disabled(changesActivity && PhoneFreeCue.normalized(activity) == nil)
                }.padding(AppSpacing.md)
            }
            .tint(AppColors.grass)
            .background(AppColors.paper).navigationTitle("Review change").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } } }
        }
    }

    private func field(_ title: String, text: Binding<String>, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title).font(AppTypography.body.weight(.semibold))
            TextField(title, text: Binding(get: { text.wrappedValue }, set: { text.wrappedValue = String($0.prefix(limit)) }), axis: .vertical)
                .font(AppTypography.body).lineLimit(1...4).padding(AppSpacing.sm).frame(minHeight: 44)
                .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                .accessibilityLabel(title)
        }
    }
}

struct RitualEditorSaveError: View {
    var body: some View {
        Text("Couldn’t confirm the save. Reopen this page to check your choices.")
            .font(AppTypography.body).foregroundStyle(AppColors.warning)
    }
}

#Preview("Optional goal · skipped") {
    RitualGoalEditor(goal: nil, onSave: { _, _, _ in true })
}

#Preview("Personal goal · long text · save unavailable") {
    RitualGoalEditor(goal: RitualGoal(mode: .morning, kind: .personal,
        wording: "A little time for myself after my night shift, while staying available for family", now: Date()),
        onSave: { _, _, _ in false })
        .environment(\.dynamicTypeSize, .accessibility3).preferredColorScheme(.dark)
}

#Preview("Review one morning activity") {
    RitualPlanReview(plan: RitualPlanRevision(goal: RitualGoal(mode: .morning, kind: .lessRushed,
        wording: RitualGoalKind.lessRushed.title, now: Date()), preferences: .defaults,
        support: WindDownHabitPlan(), now: Date()), suggestion: nil, onSave: { _, _, _ in true })
}
