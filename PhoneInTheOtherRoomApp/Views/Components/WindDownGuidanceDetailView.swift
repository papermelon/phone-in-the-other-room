import SwiftUI

struct WindDownGuidanceDetailView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let item: WindDownGuidanceItem
    var onboardingDraft: Binding<OnboardingDraft>? = nil
    @State private var replacementStepIDs: [UUID] = []
    @State private var showReplacementChoice = false
    @State private var statusMessage: String?

    private var routineSteps: [WindDownRoutineStep] {
        guard let phase = item.routinePhase else { return [] }
        if let onboardingDraft {
            return phase == .evening
                ? onboardingDraft.wrappedValue.eveningRoutine
                : onboardingDraft.wrappedValue.morningRoutine
        }
        return phase == .evening
            ? viewModel.nightWatchPreferences.eveningRoutine
            : viewModel.nightWatchPreferences.morningRoutine
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(item.group.title.uppercased())
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(item.title)
                        .font(AppTypography.display(30))
                    Text(item.suggestion)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                }

                detailCard(title: "WHY IT MAY HELP", detail: item.rationale)
                detailCard(title: "A SMALL EXAMPLE", detail: item.practicalExample)

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(item.howToFit)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondaryText)
                        Text("This is an optional experiment in a broader Wind Down. Counting Sheep does not track it or promise a particular sleep result.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                    .padding(.top, AppSpacing.xs)
                } label: {
                    Text("More context")
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(AppColors.ink)
                }
                .tint(AppColors.grass)
                .padding(AppSpacing.sm)
                .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))

                if let phase = item.routinePhase, let activity = item.routineActivity {
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("ADD TO YOUR ROUTINE")
                                .font(pixelFont(.caption))
                                .foregroundStyle(AppColors.grass)
                            Text("Add \(activity.title) to your \(phase == .evening ? "evening" : "morning") ideas. Your routine remains optional and has a \(phase == .evening ? "three" : "two")-idea limit.")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.secondaryText)
                            Button(onboardingDraft == nil
                                ? "Add to my \(phase == .evening ? "evening" : "morning") ideas"
                                : "Add to this draft") {
                                addToRoutine()
                            }
                            .buttonStyle(PixelPrimaryButtonStyle())
                            if let statusMessage {
                                Text(statusMessage)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.grass)
                            }
                        }
                    }
                } else {
                    Text("This is background guidance rather than a routine step. Keep what feels useful.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }

                sourceSection
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Idea details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Your \(item.routinePhase == .evening ? "evening" : "morning") ideas are full",
            isPresented: $showReplacementChoice,
            titleVisibility: .visible
        ) {
            ForEach(routineSteps.filter { replacementStepIDs.contains($0.id) }) { step in
                Button("Replace \(step.title)") {
                    let result = addToRoutine(replacing: step.id)
                    statusMessage = result == .added ? "Ollie added this idea to your routine." : "Ollie kept your routine as it was."
                }
            }
            Button("Keep my routine", role: .cancel) {}
        } message: {
            Text("Choose the optional idea you would like to swap out.")
        }
    }

    private func detailCard(title: String, detail: String) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text(detail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private var sourceSection: some View {
        let sources = item.sourceIDs.compactMap(WindDownGuidanceSourceRegistry.source(for:))
        return DisclosureGroup {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(sources) { source in
                    NavigationLink {
                        WindDownGuidanceSourceDetailView(
                            source: source,
                            onboardingDraft: onboardingDraft
                        )
                    } label: {
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(source.title)
                                    .font(AppTypography.body.weight(.semibold))
                                Text(source.organization)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.muted)
                            }
                            Spacer(minLength: AppSpacing.sm)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(AppColors.ink)
                        .frame(minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, AppSpacing.xs)
        } label: {
            Label("Relevant sources (\(sources.count))", systemImage: "books.vertical.fill")
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(AppColors.ink)
        }
        .tint(AppColors.grass)
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private func addToRoutine() {
        switch addToRoutine(replacing: nil) {
        case .added:
            statusMessage = "Ollie added this idea to your routine."
        case .alreadyAdded:
            statusMessage = "This idea is already in your routine."
        case let .needsReplacement(_, stepIDs):
            replacementStepIDs = stepIDs
            showReplacementChoice = true
        case .unavailable:
            statusMessage = "This idea is not available as a routine step yet."
        }
    }

    @discardableResult
    private func addToRoutine(replacing stepID: UUID?) -> WindDownGuidanceRoutineAddResult {
        if let onboardingDraft {
            var updated = onboardingDraft.wrappedValue
            guard let phase = item.routinePhase else { return .unavailable }
            var steps = phase == .evening ? updated.eveningRoutine : updated.morningRoutine
            let result = WindDownGuidanceRoutineMutation.add(item, replacing: stepID, to: &steps)
            guard result == .added else { return result }
            if phase == .evening { updated.eveningRoutine = steps }
            else { updated.morningRoutine = steps }
            updated.eveningCueText = updated.eveningRoutine.first?.kind == .custom
                ? updated.eveningRoutine.first?.customText
                : nil
            updated.morningCueText = updated.morningRoutine.first?.kind == .custom
                ? updated.morningRoutine.first?.customText
                : nil
            if let activity = updated.eveningRoutine.first?.activity { updated.eveningActivity = activity }
            if let activity = updated.morningRoutine.first?.activity { updated.morningActivity = activity }
            onboardingDraft.wrappedValue = updated
            return .added
        }
        return viewModel.addGuidanceToRoutine(item, replacing: stepID)
    }
}

#Preview("Guidance details") {
    NavigationStack {
        WindDownGuidanceDetailView(item: WindDownGuidanceLibrary.items[0])
            .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
}
