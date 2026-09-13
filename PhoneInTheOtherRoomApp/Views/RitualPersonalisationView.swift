import SwiftUI

struct RitualPersonalisationView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsGoal = false
    @State private var showsPlan = false
    @State private var reviewingSuggestion: RitualSuggestion?
    @State private var editorToken: RitualPersonalisationEditToken?
    @State private var confirmsClear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if let message = viewModel.personalisationMessage {
                    Text(message).font(AppTypography.body).foregroundStyle(AppColors.warning)
                }
                if viewModel.personalisationIsActive {
                    Text("Your timer is on. Come back to this later.")
                        .font(AppTypography.body)
                } else if viewModel.personalisationToken() == nil {
                    Text("Your saved choices aren’t ready to edit. Try loading them again.")
                        .font(AppTypography.body)
                    Button("Try loading again") { viewModel.reloadWindDownHabitState() }.frame(minHeight: 44)
                } else if !viewModel.personalisationLoadFailed {
                    goalCard
                    if let goal = viewModel.personalisation.goal {
                        planCard(goal)
                        if let suggestion = RitualPersonalisationRules.visibleSuggestion(viewModel.personalisation, now: viewModel.nowProvider()) {
                            suggestionCard(suggestion)
                        }
                        WindDownHabitReflectionCard(day: viewModel.nowProvider(), mode: goal.mode, showsPlanLink: false)
                    }
                    history
                    privacy
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .foregroundStyle(AppColors.ink)
        .navigationTitle("My routine")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.reloadPersonalisation() }
        .onChange(of: viewModel.habitEditingIdentity) { _, _ in dismiss() }
        .sheet(isPresented: $showsGoal) {
            if let token = editorToken {
                RitualGoalEditor(goal: viewModel.personalisation.goal) { mode, kind, wording in
                    viewModel.saveRitualGoal(mode: mode, kind: kind, wording: wording, token: token)
                }
                .id(viewModel.habitEditingIdentity)
            }
        }
        .sheet(isPresented: $showsPlan) {
            if let plan = viewModel.personalisation.currentPlan, let token = editorToken {
                RitualPlanReview(plan: plan, suggestion: reviewingSuggestion) { activities, cue, preparation in
                    viewModel.reviewRitualPlan(activities: activities, cue: cue, preparation: preparation,
                                              suggestionID: reviewingSuggestion?.id, token: token)
                }
                .id(viewModel.habitEditingIdentity)
            }
        }
        .confirmationDialog("Clear goals, reflections and suggestions?", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("Clear personalisation", role: .destructive) {
                if let token = viewModel.personalisationToken() {
                    _ = viewModel.updatePersonalisationPrivacy(clearAll: true, token: token)
                }
            }
        } message: {
            Text("Your routine settings, timer history and Farm stay in place. Reflection invitations will be turned off.")
        }
    }

    private var goalCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(viewModel.personalisation.goal?.wording ?? "No goal chosen")
                    .font(AppTypography.headline)
                if let goal = viewModel.personalisation.goal {
                    Text(goal.mode == .morning ? "Screen-Free Morning" : "Wind Down")
                        .font(AppTypography.caption).foregroundStyle(AppColors.muted)
                }
                Button(viewModel.personalisation.goal == nil ? "Choose a goal" : "Edit goal") { editorToken = viewModel.personalisationToken(); showsGoal = true }
                    .frame(minHeight: 44)
            }
        }
    }

    private func planCard(_ goal: RitualGoal) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("My plan").font(AppTypography.headline)
                if let plan = viewModel.personalisation.currentPlan {
                    ForEach(plan.activities) { Text($0.title).font(AppTypography.body) }
                    if let cue = plan.cue { Text("Begin: \(cue)").font(AppTypography.body) }
                }
                Button("Review my activity") { editorToken = viewModel.personalisationToken(); reviewingSuggestion = nil; showsPlan = true }
                    .frame(minHeight: 44)
            }
        }
    }

    private func suggestionCard(_ suggestion: RitualSuggestion) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(suggestion.action.title).font(AppTypography.headline)
                Text(suggestion.reason).font(AppTypography.body)
                DisclosureGroup("See my reflections") {
                    ForEach(viewModel.windDownHabitReflections.entries.filter {
                        $0.experience.map { suggestion.evidenceIDs.contains($0.id) } ?? false
                    }, id: \.experience?.id) { entry in
                        Text("\(entry.displayDay.formatted(date: .abbreviated, time: .omitted)): \(entry.obstacle?.title ?? "Your reflection")")
                            .font(AppTypography.body)
                    }
                }.frame(minHeight: 44)
                Button("Review change") { editorToken = viewModel.personalisationToken(); reviewingSuggestion = suggestion; showsPlan = true }.frame(minHeight: 44)
                Button("Keep my plan") { respond(suggestion, .dismissed) }.frame(minHeight: 44)
                Button("Later") { respond(suggestion, .deferred) }.frame(minHeight: 44)
            }
        }
    }

    private func respond(_ suggestion: RitualSuggestion, _ status: RitualSuggestion.Status) {
        if let token = viewModel.personalisationToken() {
            _ = viewModel.respondToRitualSuggestion(suggestion.id, status: status, token: token)
        }
    }

    private var history: some View {
        DisclosureGroup("My history") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                ForEach(viewModel.personalisation.plans.reversed()) { plan in
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("\(plan.savedAt.formatted(date: .abbreviated, time: .shortened)) · \(plan.goal.wording)")
                            .font(AppTypography.body.weight(.semibold))
                        Text(plan.activities.map(\.title).joined(separator: " · ")).font(AppTypography.body)
                        if let cue = plan.cue { Text("Begin: \(cue)").font(AppTypography.body) }
                    }
                }
                ForEach(viewModel.windDownHabitReflections.entries, id: \.reviewIdentity) { entry in
                    WindDownHabitReflectionCard(day: entry.displayDay, mode: entry.mode)
                }
                if viewModel.windDownHabitReflections.entries.isEmpty {
                    Text("No reflections yet. There’s nothing you need to catch up on.").font(AppTypography.body)
                }
                ForEach(viewModel.personalisation.adjustments) { adjustment in
                    Text(adjustment.applicationPending ? "A chosen change needs to finish saving." :
                        adjustment.wasApplied == false ? "A newer routine was kept after a plan review." : "Reviewed activity and cue change saved.")
                        .font(AppTypography.body)
                }
                ForEach(viewModel.personalisation.suggestions) { suggestion in
                    Text("\(suggestion.action.title) · \(suggestion.status.reviewTitle)")
                        .font(AppTypography.body)
                }
            }.padding(.top, AppSpacing.sm)
        }.font(AppTypography.headline).frame(minHeight: 44)
    }

    private var privacy: some View {
        DisclosureGroup("Personalisation & privacy") {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Toggle("Occasional reflection invitations", isOn: Binding(
                    get: { viewModel.personalisation.invitationsEnabled },
                    set: { value in
                        if let token = viewModel.personalisationToken() {
                            _ = viewModel.updatePersonalisationPrivacy(invitations: value, token: token)
                        }
                    }
                )).font(AppTypography.body).frame(minHeight: 44)
                Text("Goals and reflections stay on this device, separate for each account and guest. They aren’t sent to AI, Farm sync or Slumber Party.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.muted)
                Text("Detailed history: up to 90 days, plus your current plan. Reflections: up to 45 morning or evening notes. Rejected suggestions stay hidden until you change your goal.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.muted)
                Button("Clear suggestions") {
                    if let token = viewModel.personalisationToken() {
                        _ = viewModel.updatePersonalisationPrivacy(clearSuggestions: true, token: token)
                    }
                }.frame(minHeight: 44)
                Button("Clear personalisation", role: .destructive) { confirmsClear = true }.frame(minHeight: 44)
            }.padding(.top, AppSpacing.sm)
        }.font(AppTypography.body).frame(minHeight: 44)
    }

}

extension WindDownHabitReflection {
    var reviewIdentity: String { "\(mode.rawValue)-\(id.timeIntervalSince1970)" }
}

extension RitualSuggestion.Status {
    var reviewTitle: String {
        switch self {
        case .proposed: return "Available to review"
        case .accepted: return "Change chosen"
        case .dismissed: return "Kept my plan"
        case .deferred: return "Saved for later"
        case .superseded: return "No longer current"
        }
    }
}
