import SwiftUI

struct CompletionView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    private var run: FocusRun? { viewModel.activeRun }
    private var minutes: Int { run?.creditedQuietMinutes ?? 0 }
    private var persistedOutcome: SheepSearchOutcome? {
        guard let run, run.isProgressionEligibleNightWatch else { return nil }
        return viewModel.sheepSearchOutcome(for: run.id)
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

                if run?.nightWatchPlan?.role == .additionalQuiet {
                    AdditionalQuietMapReceipt(map: viewModel.sheepSearchState.trailMap, minutes: minutes)
                } else if run?.isProgressionEligibleNightWatch == true {
                    NavigationLink {
                        WindDownRevealView(
                            outcome: persistedOutcome,
                            showExactOdds: viewModel.sheepSearchState.showExactOdds,
                            farmState: viewModel.farmState,
                            onReturnToFarm: returnToFarm
                        )
                    } label: {
                        Label("Open Ollie’s Trail Notes", systemImage: "note.text")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .accessibilityHint("Shows the saved sheep search result for this Wind Down")
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
                    Text(run?.nightWatchPlan?.role == .additionalQuiet ? "QUIET TIME COMPLETE" : "WIND DOWN COMPLETE")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(run?.nightWatchPlan?.role == .additionalQuiet ? "A quiet stretch is on the map." : "The phone slept in the other room.")
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
                ? "Quiet time complete. " + quietMinutes.description + " quiet minutes recorded."
                : "Wind Down complete. The phone slept in the other room. " + quietMinutes.description + " quiet minutes around sleep recorded.")
        }
    }
}

private struct AdditionalQuietMapReceipt: View {
    let map: SheepTrailMapState
    let minutes: Int

    var body: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.grass)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("TRAIL MAP UPDATED")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(map.pendingMappedMinutes >= SheepTrailMapState.maximumMappedMinutes
                        ? "The trail map is ready for a future search."
                        : minutes.description + " quiet minutes are mapped for a future search.")
                        .font(AppTypography.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

struct WindDownRevealView: View {
    @Environment(\.dismiss) private var dismiss
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
                } else {
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("NO TRAIL NOTE SAVED")
                                .font(pixelFont(.caption))
                                .foregroundStyle(AppColors.grass)
                            Text("This Wind Down has no saved Trail Note.")
                                .font(AppTypography.headline)
                            Text("Your quiet-time receipt is still saved in Nights.")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }
                }

                if outcome?.result == .trailOnly {
                    NavigationLink("See the Trail Board") { TrailBoardView() }
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
        .navigationTitle("Ollie’s Trail Notes")
        .navigationBarTitleDisplayMode(.inline)
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
            Text("TRAIL NOTE")
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
        return SheepCatalog.eligible(for: outcome.protectedNightNumber + 1)
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
                    Text("A SHEEP FOUND ITS WAY HOME")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(flockSheep?.displayName ?? sheep.name)
                        .font(AppTypography.display(32))
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
                    Text("The trail continues.")
                        .font(AppTypography.title)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Ollie didn't find a sheep on this trail. The clue is saved for another quiet night.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            FieldNoteMetric(
                title: "Clue gained",
                value: nextLead?.posterClue ?? "The trail reaches beyond the current board."
            )
            FieldNoteMetric(
                title: "Mapped quiet used",
                value: outcome.trailMapBonusPercentagePoints > 0
                    ? "+\(outcome.trailMapBonusPercentagePoints) percentage points"
                    : "No mapped bonus used"
            )
            FieldNoteMetric(
                title: "Next eligible lead",
                value: nextLead.map { "\($0.rarity.title) · \($0.habitat.title)" }
                    ?? "All current trails explored"
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
            Text("TRAIL DETAILS")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            FieldNoteMetric(title: "Distance", value: String(format: "%.1f km", outcome.trailDistance))
            FieldNoteMetric(title: "Trail strength", value: strengthLabel)
            if outcome.trailMapBonusPercentagePoints > 0 {
                FieldNoteMetric(
                    title: "Mapped bonus applied",
                    value: "+" + outcome.trailMapBonusPercentagePoints.description + " percentage points"
                )
            }
            if showExactOdds {
                FieldNoteMetric(
                    title: "Encounter odds",
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
}

#Preview("Trail Note found") {
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
}

#Preview("Trail Note trail only · Reduce Motion") {
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
    .transaction { transaction in
        transaction.disablesAnimations = true
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
