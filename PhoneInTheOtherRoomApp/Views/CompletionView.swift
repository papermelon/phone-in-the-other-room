import SwiftUI

struct CompletionView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    private var run: FocusRun? { viewModel.activeRun }
    private var minutes: Int { run?.creditedQuietMinutes ?? 0 }
    private var isPhoneAway: Bool { run?.nightWatchPlan?.role == .additionalQuiet }
    private var persistedOutcome: SheepSearchOutcome? {
        guard let run else { return nil }
        guard isPhoneAway || run.isProgressionEligibleNightWatch || run.isPractice else { return nil }
        return viewModel.sheepSearchOutcome(for: run.id)
    }
    private var phoneAwayReceipt: PhoneAwayReceiptPresentation {
        guard let run else {
            return .make(record: nil)
        }
        return .make(
            record: viewModel.phoneAwaySearchSettlement(for: run.id),
            outcome: persistedOutcome
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                CompletionHeader(run: run, quietMinutes: minutes)

                NightWatchReceiptCard(
                    run: run,
                    sleepSummary: viewModel.lastNightSleep,
                    sleepAuthorization: viewModel.sleepAuthorization,
                    screenTimeAuthorization: viewModel.screenTimeAuthorization
                )

                if let run,
                   run.completedSuccessfully,
                   run.isProgressionEligibleNightWatch,
                   viewModel.nightFlockViewModel.hasSharedResult(for: run.id) {
                    NavigationLink {
                        NightFlockHubView(viewModel: viewModel.nightFlockViewModel)
                    } label: {
                        NightFlockResultCard(snapshot: viewModel.nightFlockViewModel.snapshot)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the shared pasture result for this completed Wind Down")
                }

                if isPhoneAway {
                    AdditionalQuietMapReceipt(presentation: phoneAwayReceipt)

                    if let persistedOutcome, phoneAwayReceipt.showsSearchLink || persistedOutcome.origin == .onboardingPractice {
                        NavigationLink {
                            WindDownRevealView(
                                outcome: persistedOutcome,
                                showExactOdds: viewModel.sheepSearchState.showExactOdds,
                                farmState: viewModel.farmState,
                                onReturnToFarm: returnToFarm
                            )
                        } label: {
                            Label(
                                SheepSearchPresentation.completionLinkTitle(for: persistedOutcome.origin),
                                systemImage: "note.text"
                            )
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PixelPrimaryButtonStyle())
                        .accessibilityLabel(SheepSearchPresentation.completionLinkTitle(for: persistedOutcome.origin))
                        .accessibilityHint(SheepSearchPresentation.completionLinkHint(for: persistedOutcome.origin))
                    }
                } else if run?.isProgressionEligibleNightWatch == true {
                    NavigationLink {
                        WindDownRevealView(
                            outcome: persistedOutcome,
                            showExactOdds: viewModel.sheepSearchState.showExactOdds,
                            farmState: viewModel.farmState,
                            onReturnToFarm: returnToFarm
                        )
                    } label: {
                        Label(
                            persistedOutcome.map { SheepSearchPresentation.completionLinkTitle(for: $0.origin) } ?? "Open Search Journal",
                            systemImage: "note.text"
                        )
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .accessibilityHint(
                        persistedOutcome.map { SheepSearchPresentation.completionLinkHint(for: $0.origin) }
                            ?? "Shows the Search Journal note for this Wind Down"
                    )
                }

                if run?.id == viewModel.orientationState.practiceRunID,
                   run?.completedSuccessfully == true,
                   !viewModel.orientationState.milestones.contains(.practiceRecordViewed) {
                    OrientationRecordPrompt {
                        viewModel.resetSetup()
                        viewModel.focusNightsRecord(viewModel.orientationState.practiceRunID)
                        NotificationCenter.default.post(name: .countingSheepShowNights, object: nil)
                    }
                }

                NavigationLink("See your nights") {
                    FocusStatsView()
                        .environmentObject(viewModel)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))

                Button("Done for now") { viewModel.resetSetup() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PixelPrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColors.paper.ignoresSafeArea())
        .onAppear(perform: viewModel.refreshSleepSummary)
    }

    private func returnToFarm() {
        NotificationCenter.default.post(name: .countingSheepShowFarm, object: nil)
        viewModel.resetSetup()
    }
}

private struct CompletionHeader: View {
    let run: FocusRun?
    let quietMinutes: Int

    var body: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                OllieRitualView(state: .completed, presentation: .inline)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(run?.nightWatchPlan?.role == .additionalQuiet ? "PHONE AWAY COMPLETE" : "WIND DOWN COMPLETE")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(run?.nightWatchPlan?.role == .additionalQuiet ? "Ollie kept the phone tucked away." : "The phone slept in the other room.")
                        .font(AppTypography.title)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(run?.nightWatchPlan?.role == .additionalQuiet
                        ? quietMinutes.description + " quiet minutes recorded."
                        : quietMinutes.description + " quiet minutes around sleep recorded.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(run?.nightWatchPlan?.role == .additionalQuiet
                ? "Phone Away complete. " + quietMinutes.description + " quiet minutes recorded."
                : "Wind Down complete. The phone slept in the other room. " + quietMinutes.description + " quiet minutes around sleep recorded.")
        }
    }
}

private struct AdditionalQuietMapReceipt: View {
    let presentation: PhoneAwayReceiptPresentation

    var body: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.grass)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(presentation.eyebrow)
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(presentation.title)
                        .font(AppTypography.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(presentation.message)
                        .font(AppTypography.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.accessibilityLabel)
        }
    }
}

struct WindDownRevealView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var contextualTip: CountingSheepContextualTip?
    let outcome: SheepSearchOutcome?
    let showExactOdds: Bool
    let farmState: FarmState
    let onReturnToFarm: (() -> Void)?

    init(
        outcome: SheepSearchOutcome?,
        showExactOdds: Bool = false,
        farmState: FarmState = .empty,
        onReturnToFarm: (() -> Void)? = nil
    ) {
        self.outcome = outcome
        self.showExactOdds = showExactOdds
        self.farmState = farmState
        self.onReturnToFarm = onReturnToFarm
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FieldNoteTitle()

                if let outcome {
                    FieldNotePaper(outcome: outcome, showExactOdds: showExactOdds, farmState: farmState)
                        .contextualGuideTarget(.trailNote)
                } else {
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("No Search Journal entry saved.")
                                .font(pixelFont(.caption))
                                .foregroundStyle(AppColors.grass)
                    Text("This Wind Down has no saved Search Journal note.")
                        .font(AppTypography.headline)
                    Text("Your quiet-time receipt is still saved in Nights.")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }
                }

                if outcome?.result == .trailOnly {
                    NavigationLink("Open Ollie’s Search") { TrailBoardView() }
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else if outcome?.result == .found {
                    NavigationLink(arrivalIsPending ? "Make room in The Barn" : "See the flock in The Barn") {
                        FarmBarnView()
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }

                Button("Back to the Farm") {
                    if let onReturnToFarm {
                        onReturnToFarm()
                    } else {
                        dismiss()
                    }
                }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .accessibilityHint("Returns to the Farm")
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Search Journal")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard outcome != nil else { return }
            contextualTip = viewModel.contextualTip(from: [.trailNote])
        }
        .contextualGuideOverlay(
            tip: $contextualTip,
            onAcknowledge: viewModel.acknowledgeContextualTip,
            onSkipAll: viewModel.disableContextualTips
        )
    }

    private var arrivalIsPending: Bool {
        guard let outcome else { return false }
        return farmState.sheep.first { $0.sourceOutcomeID == outcome.id }?.status == .pending
    }
}

private struct FieldNoteTitle: View {
    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(AppColors.grass)
                .accessibilityHidden(true)
            Text("SEARCH JOURNAL ENTRY")
                .font(pixelFont(.title3))
                .foregroundStyle(AppColors.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.panel, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.55), lineWidth: 1.5)
        }
    }
}

private struct FieldNotePaper: View {
    let outcome: SheepSearchOutcome
    let showExactOdds: Bool
    let farmState: FarmState

    private var sheep: SheepDefinition? {
        guard outcome.result == .found else { return nil }
        return outcome.sheepID.flatMap(SheepCatalog.definition)
    }

    private var flockSheep: FlockSheep? {
        farmState.sheep.first { $0.sourceOutcomeID == outcome.id }
    }

    private var nextLead: SheepDefinition? {
        let known = Set(farmState.discoveries.map(\.definitionID))
        let eligibilityNight = outcome.origin == .phoneBreak
            ? outcome.protectedNightNumber
            : outcome.protectedNightNumber + 1
        return SheepCatalog.eligible(for: eligibilityNight)
            .first { !known.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if let sheep {
                PixelAssetImage(name: sheep.assetName)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 150, maxHeight: 230)
                    .accessibilityLabel(flockSheep?.displayName ?? sheep.name)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(SheepSearchPresentation.foundEyebrow(for: outcome.origin))
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(flockSheep?.displayName ?? sheep.name)
                        .font(AppTypography.display(32))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(SheepSearchPresentation.foundHeadline(for: outcome.origin))
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(sheep.story)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                FieldNoteMetric(title: "Habitat", value: outcome.habitat?.title ?? sheep.habitat.title)
                FieldNoteMetric(title: "At the Farm", value: arrivalStatus)
                FieldNoteTrailDetails(outcome: outcome, showExactOdds: showExactOdds)
            } else {
                TrailOnlyNote(outcome: outcome, showExactOdds: showExactOdds, nextLead: nextLead)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(AppColors.ink)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.45), lineWidth: 1.5)
        }
    }

    private var arrivalStatus: String {
        switch farmState.sheep.first(where: { $0.sourceOutcomeID == outcome.id })?.status {
        case .active: return "Living in The Barn"
        case .pending: return "Waiting at The Barn gate"
        case .sold: return "Discovery kept · sheep moved on"
        case nil: return "Homecoming recorded"
        }
    }
}

private struct TrailOnlyNote: View {
    let outcome: SheepSearchOutcome
    let showExactOdds: Bool
    let nextLead: SheepDefinition?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                PixelAssetImage(name: AssetSlot.Dog.proud)
                    .frame(width: 72, height: 72)
                    .accessibilityLabel("Ollie following the trail")
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("OLLIE KEPT TO THE TRAIL")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(SheepSearchPresentation.trailHeadline(for: outcome.origin))
                        .font(AppTypography.title)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(SheepSearchPresentation.trailBody(for: outcome.origin))
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            FieldNoteMetric(
                title: "Clue gained",
                value: nextLead?.posterClue ?? "The trail reaches beyond the current board."
            )
            if outcome.origin == .windDown {
                FieldNoteMetric(
                    title: "Mapped quiet used",
                    value: outcome.trailMapBonusPercentagePoints > 0
                        ? "+\(outcome.trailMapBonusPercentagePoints) percentage points"
                        : "No mapped bonus used"
                )
            }
            FieldNoteMetric(
                title: "Next eligible lead",
                value: nextLead.map { "\($0.rarity.title) · \($0.habitat.title)" }
                    ?? "All current searches explored"
            )
            FieldNoteTrailDetails(outcome: outcome, showExactOdds: showExactOdds)
        }
    }
}

private struct FieldNoteTrailDetails: View {
    let outcome: SheepSearchOutcome
    let showExactOdds: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(SheepSearchPresentation.detailsHeading(for: outcome.origin))
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            FieldNoteMetric(title: "How they arrived", value: SheepSearchPresentation.openedByLine(for: outcome.origin))
            if SheepSearchPresentation.showsTrailMetrics(for: outcome.origin) {
                if outcome.origin == .phoneBreak {
                    FieldNoteMetric(
                        title: "Clues before this note",
                        value: outcome.consecutiveNoFinds.description
                    )
                } else {
                    FieldNoteMetric(title: "Distance", value: String(format: "%.1f km", outcome.trailDistance))
                    FieldNoteMetric(title: "Trail strength", value: strengthLabel)
                }
            }
            if outcome.origin == .windDown, outcome.trailMapBonusPercentagePoints > 0 {
                FieldNoteMetric(
                    title: "Mapped bonus applied",
                    value: "+" + outcome.trailMapBonusPercentagePoints.description + " percentage points"
                )
            }
            if showExactOdds, SheepSearchPresentation.showsTrailMetrics(for: outcome.origin) {
                FieldNoteMetric(
                    title: "Chance",
                    value: Int((outcome.encounterOdds * 100).rounded()).description + "%"
                )
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private var strengthLabel: String {
        switch outcome.trailStrength {
        case 0..<35: return "Faint"
        case 35..<60: return "Promising"
        case 60..<80: return "Strong"
        default: return "Very strong"
        }
    }
}

private struct FieldNoteMetric: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
            Spacer(minLength: AppSpacing.xs)
            Text(value)
                .font(AppTypography.caption.weight(.bold))
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

extension Notification.Name {
    static let countingSheepShowFarm = Notification.Name("countingSheep.showFarm")
    static let countingSheepShowNights = Notification.Name("countingSheep.showNights")
    static let countingSheepShowHome = Notification.Name("countingSheep.showHome")
    static let countingSheepShowNightFlock = Notification.Name("countingSheep.showNightFlock")
}

#Preview("Search Journal entry found") {
    NavigationStack {
        WindDownRevealView(
            outcome: SheepSearchOutcome(
                id: UUID(), runID: UUID(), protectedNightNumber: 3, result: .found,
                sheepID: "mabel", rarity: .common, habitat: .starterPasture,
                trailStrength: 72, encounterOdds: 0.68, trailDistance: 4.2,
                consecutiveNoFinds: 0, bonusPoints: 2, trailMapBonusPercentagePoints: 2,
                createdAt: Date()
            ),
            showExactOdds: false
        )
    }
    .environmentObject(FocusRunViewModel())
}

#Preview("Search Journal welcome gift") {
    NavigationStack {
        WindDownRevealView(
            outcome: SheepSearchOutcome(
                id: UUID(), runID: UUID(), origin: .starter, protectedNightNumber: 0,
                result: .found, sheepID: "mabel", rarity: .common, habitat: .starterPasture,
                trailStrength: 0, encounterOdds: 1, trailDistance: 0,
                consecutiveNoFinds: 0, bonusPoints: 0, createdAt: Date()
            ),
            showExactOdds: false
        )
    }
    .environmentObject(FocusRunViewModel())
}

#Preview("Search Journal clue only · Reduce Motion") {
    NavigationStack {
        WindDownRevealView(
            outcome: SheepSearchOutcome(
                id: UUID(), runID: UUID(), protectedNightNumber: 8, result: .trailOnly,
                sheepID: nil, rarity: nil, habitat: nil,
                trailStrength: 42, encounterOdds: 0.46, trailDistance: 3.1,
                consecutiveNoFinds: 1, bonusPoints: 0, createdAt: Date()
            )
        )
    }
    .environmentObject(FocusRunViewModel())
    .transaction { transaction in
        transaction.disablesAnimations = true
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
