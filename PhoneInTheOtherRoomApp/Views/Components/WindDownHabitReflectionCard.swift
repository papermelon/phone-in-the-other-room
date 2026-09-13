import SwiftUI

struct WindDownHabitReflectionCard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    var day: Date
    var embedded = false
    var mode: WindDownRoutinePhase = .evening
    var showsPlanLink = true

    var body: some View {
        let ownerEpoch = viewModel.habitEditingIdentity
        if !viewModel.personalisationIsActive {
            WindDownHabitReflectionContent(
                reflection: viewModel.windDownHabitReflections.entry(for: day, mode: mode)
                    ?? WindDownHabitReflection(day: day, mode: mode),
                plans: viewModel.personalisation.plans.filter { $0.goal.mode == mode },
                token: viewModel.personalisationToken(),
                embedded: embedded,
                showsPlanLink: showsPlanLink,
                onSave: { reflection, token in
                    guard ownerEpoch == viewModel.habitEditingIdentity else { return false }
                    if let token { return viewModel.savePersonalisationReflection(reflection, token: token) }
                    // The original evening note remains independently usable when
                    // an unrelated personalisation field is unreadable.
                    if mode == .evening && reflection.experience == nil {
                        return viewModel.saveWindDownHabitReflection(reflection)
                    }
                    return false
                }
            )
            .id("\(viewModel.habitEditingIdentity)-\(mode.rawValue)-\(Calendar.current.startOfDay(for: day).timeIntervalSince1970)")
        }
    }
}

struct WindDownHabitReflectionContent: View {
    let reflection: WindDownHabitReflection
    let plans: [RitualPlanRevision]
    let token: RitualPersonalisationEditToken?
    var embedded = false
    var showsPlanLink = true
    let onSave: (WindDownHabitReflection, RitualPersonalisationEditToken?) -> Bool
    @State private var draft: WindDownHabitReflection
    @State private var editingToken: RitualPersonalisationEditToken?
    @State private var isExpanded: Bool
    @State private var saved = false
    @State private var saveFailed = false
    @State private var stale = false

    init(reflection: WindDownHabitReflection, plans: [RitualPlanRevision] = [],
         token: RitualPersonalisationEditToken? = nil, embedded: Bool = false, showsPlanLink: Bool = true,
         initiallyExpanded: Bool = false,
         onSave: @escaping (WindDownHabitReflection, RitualPersonalisationEditToken?) -> Bool) {
        self.reflection = reflection; self.plans = plans; self.token = token
        self.embedded = embedded; self.showsPlanLink = showsPlanLink; self.onSave = onSave
        _draft = State(initialValue: reflection); _editingToken = State(initialValue: token)
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        Group {
            if embedded { disclosure.padding(.vertical, AppSpacing.sm) }
            else { PixelCard { disclosure } }
        }
        .onChange(of: reflection) { previous, current in
            if draft == previous || draft == current { draft = current; editingToken = token }
            else { stale = true }
        }
    }

    private var disclosure: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(reflection.displayDay.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTypography.caption).foregroundStyle(AppColors.muted)
                if reflection.mode == .morning || !plans.isEmpty || draft.experience != nil {
                    experienceFields
                }
                if reflection.mode == .evening {
                    DisclosureGroup("How did beginning feel?") {
                        Picker("How did beginning feel?", selection: $draft.ease) {
                            Text("Not answered").tag(nil as WindDownStartingEase?)
                            ForEach(WindDownStartingEase.allCases) { Text($0.title).tag(Optional($0)) }
                        }.pickerStyle(.menu).frame(minHeight: 44)
                    }.font(AppTypography.body).frame(minHeight: 44)
                }
                DisclosureGroup("Anything to add? (optional)") {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Picker("What got in the way?", selection: $draft.obstacle) {
                            Text("Nothing to add").tag(nil as WindDownObstacle?)
                            ForEach(WindDownObstacle.allCases) { Text($0.title).tag(Optional($0)) }
                        }.pickerStyle(.menu).frame(minHeight: 44)
                        if token != nil {
                            TextField("What worked, or got in the way", text: Binding(
                                get: { draft.experience?.context ?? "" },
                                set: { ensureExperience(); draft.experience?.context = String($0.prefix(240)) }
                            ), axis: .vertical)
                            .font(AppTypography.body).lineLimit(2...5).frame(minHeight: 44)
                            .accessibilityLabel("Optional context, up to 240 characters")
                        }
                    }
                }.font(AppTypography.body).frame(minHeight: 44)
                if stale {
                    Text("A newer note was saved. Load it before editing again.")
                        .font(AppTypography.body).foregroundStyle(AppColors.warning)
                    Button("Load saved reflection") {
                        draft = reflection; editingToken = token; stale = false
                    }.frame(minHeight: 44)
                }
                Button("Save reflection") { save(draft) }
                    .buttonStyle(PixelChipButtonStyle(isSelected: true)).frame(minHeight: 44).disabled(stale)
                if !reflection.isEmpty {
                    Button("Delete this reflection", role: .destructive) {
                        var empty = draft
                        empty.ease = nil; empty.obstacle = nil; empty.experience = nil
                        save(empty)
                    }.frame(minHeight: 44).disabled(stale)
                }
                if saved { Text("Reflection saved.").font(AppTypography.body).foregroundStyle(AppColors.grass) }
                if saveFailed { RitualEditorSaveError() }
                if draft.obstacle == .neededPhone {
                    Text("Keep essential calls and alerts in mind.")
                        .font(AppTypography.body)
                    NavigationLink("Review app protection") { SettingsProtectionTagsView() }.frame(minHeight: 44)
                }
                if draft.obstacle == .timing {
                    NavigationLink("Review my timing") { FocusRunSetupView(initialHabitFocus: .activity) }.frame(minHeight: 44)
                }
                if showsPlanLink {
                    NavigationLink("Review my plan") { RitualPersonalisationView() }.frame(minHeight: 44)
                }
                Text("Private. No effect on rewards.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.muted)
            }.padding(.top, AppSpacing.md)
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(reflection.mode == .morning ? "Morning reflection" : "Evening reflection")
                    .font(AppTypography.headline)
                Text(reflection.experience?.answer?.title ?? reflection.ease?.title ?? "Optional")
                    .font(AppTypography.caption).foregroundStyle(AppColors.muted)
            }.frame(minHeight: 44, alignment: .leading)
        }.tint(AppColors.grass)
    }

    private var experienceFields: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Picker("Which plan?", selection: Binding(
                get: { draft.experience?.planID },
                set: { ensureExperience(); draft.experience?.planID = $0 }
            )) {
                Text("General reflection").tag(nil as UUID?)
                ForEach(plans.reversed()) { plan in
                    Text("\(plan.savedAt.formatted(date: .abbreviated, time: .shortened)) · \(plan.goal.wording)")
                        .tag(Optional(plan.id))
                }
            }.pickerStyle(.menu).frame(minHeight: 44)
            if let plan = plans.first(where: { $0.id == draft.experience?.planID }) {
                Text(plan.goal.wording).font(AppTypography.body.weight(.semibold))
            }
            Text(reflection.mode == .morning ? "Was it the start you wanted?" : "Did Wind Down help?")
                .font(AppTypography.body.weight(.semibold))
            Picker("Did it help?", selection: Binding(
                get: { draft.experience?.answer },
                set: { ensureExperience(); draft.experience?.answer = $0 }
            )) {
                Text("Not answered").tag(nil as RitualExperienceAnswer?)
                ForEach(RitualExperienceAnswer.allCases) { Text($0.title).tag(Optional($0)) }
            }.pickerStyle(.menu).frame(minHeight: 44)
        }
    }

    private func ensureExperience() {
        if draft.experience == nil {
            draft.experience = RitualExperienceFeedback(recordedAt: Date(), timeZoneIdentifier: TimeZone.current.identifier)
        }
    }

    private func save(_ value: WindDownHabitReflection) {
        var value = value
        if value.experience != nil {
            value.experience?.recordedAt = Date()
            // A revised note is new evidence; suggestions that cited its old
            // contents must retire, including edits that only change context.
            if value != reflection { value.experience?.id = UUID() }
        }
        saved = onSave(value, editingToken)
        saveFailed = !saved
        if saved { draft = value; isExpanded = false }
    }
}

#Preview("Reflection · no session or answer") {
    NavigationStack {
        WindDownHabitReflectionContent(reflection: WindDownHabitReflection(day: Date()), onSave: { _, _ in true })
            .padding(AppSpacing.md).background(AppColors.paper)
    }
}

#Preview("Reflection · morning · not sure · large text") {
    NavigationStack {
        ScrollView {
            WindDownHabitReflectionContent(reflection: WindDownHabitReflection(day: Date(), obstacle: .neededPhone, mode: .morning),
                initiallyExpanded: true, onSave: { _, _ in false })
                .padding(AppSpacing.md)
        }.background(AppColors.paper)
    }.environment(\.dynamicTypeSize, .accessibility3).preferredColorScheme(.dark)
}
