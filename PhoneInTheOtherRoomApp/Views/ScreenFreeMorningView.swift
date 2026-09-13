import SwiftUI

/// Phone-authoritative presentation of the independent morning occurrence.
/// It contains no Wind Down result or Slumber Party entry point.
struct ScreenFreeMorningView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let occurrence: MorningQuietOccurrence
    var fixedNow: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showEmergencyExit = false
    @State private var emergencyReason = ""
    @State private var emergencyConfirmation = ""

    private var endDate: Date { occurrence.scheduledEnd }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        NightJourneyView(morning: occurrence, reduceMotion: reduceMotion, fixedDate: fixedNow,
                                         accessoryItemID: viewModel.farmState.equipment.ollieAccessoryItemID)
                        Label("Screen-Free Morning", systemImage: "sun.max.fill")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.grass)
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            if let fixedNow {
                                Text(OllieFormat.timer(max(0, endDate.timeIntervalSince(fixedNow))))
                                    .font(pixelFont(.largeTitle))
                            } else {
                                Text(timerInterval: countdownInterval, countsDown: true, showsHours: true)
                                    .font(pixelFont(.largeTitle))
                            }
                            Text("Remaining · until \(OllieFormat.time(endDate))")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !morningSteps.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Your morning ideas")
                            .font(AppTypography.headline)
                        ForEach(morningSteps) { step in
                            Label(step.title, systemImage: step.activity?.systemImage ?? "leaf.fill")
                                .font(AppTypography.body)
                        }
                    }
                    .foregroundStyle(AppColors.ink)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Optional morning ideas: \(morningSteps.map(\.title).joined(separator: ", "))")
                }

                let tracker = viewModel.briefAccessTrackerSummary(forScreenFreeMorning: occurrence)
                if tracker.pauseCount > 0 {
                    Label("Brief Access · \(tracker.pauseCount) use\(tracker.pauseCount == 1 ? "" : "s")", systemImage: "arrow.triangle.2.circlepath")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }

                if viewModel.shieldingReadiness != .ready {
                    NavigationLink {
                        ScreenTimeProtectionRepairView()
                    } label: {
                        Label("Review app protection", systemImage: "exclamationmark.shield")
                            .font(AppTypography.headline)
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    .accessibilityHint("Repair app protection before another start")
                }

                DisclosureGroup("Timer & protection details") {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("\(occurrence.eligibleElapsedMinutes(at: fixedNow ?? Date())) timer minutes so far")
                        Text(QuietTimeShieldRole.screenFreeMorning.briefAccessExplanation)
                        Text("App protection uses your selected apps and categories. Websites and unselected apps remain available.")
                        if viewModel.shieldingReadiness != .ready {
                            Text(viewModel.shieldingReadiness.detail)
                                .foregroundStyle(AppColors.warning)
                        }
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .padding(.top, AppSpacing.xs)
                }
                .font(AppTypography.caption)
                .tint(AppColors.grass)

                if linkedParentRun?.guardKind == .nfcTag {
                    Button("Tap tag to finish this morning timer") {
                        viewModel.requestEndWindDown()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .accessibilityHint("Uses the registered tag to finish the Screen-Free Morning timer")

                    if !viewModel.nfcStatus.isEmpty {
                        Text(viewModel.nfcStatus)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("Need an emergency exit?") {
                        guard viewModel.beginEmergencyExitChallenge() else { return }
                        emergencyReason = ""
                        emergencyConfirmation = ""
                        showEmergencyExit = true
                    }
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.amber)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHint("Opens the existing deliberate confirmation before ending without the tag")
                } else {
                    Button("Finish Screen-Free Morning") {
                        viewModel.finishScreenFreeMorning(occurrence.id)
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .accessibilityHint("Saves elapsed timer minutes and ends Screen-Free Morning")
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Screen-Free Morning")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEmergencyExit, onDismiss: cancelEmergencyExit) {
            emergencyExitSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var countdownInterval: ClosedRange<Date> {
        let now = Date()
        return now...max(now, endDate)
    }

    private var morningSteps: [WindDownRoutineStep] {
        if let plan = linkedParentRun?.nightWatchPlan { return plan.morningRoutine }
        // A deferred morning may outlive the active run; use its frozen record.
        return viewModel.nightWatchRecords.first { $0.id == occurrence.linkedWindDownRunID }?.plan.morningRoutine ?? []
    }

    private var linkedParentRun: FocusRun? {
        guard let run = viewModel.activeRun,
              run.id == occurrence.linkedWindDownRunID,
              ![.setup, .completed, .endedEarly].contains(run.state) else {
            return nil
        }
        return run
    }

    private var emergencyExitSheet: some View {
        let challenge = viewModel.emergencyExitChallenge
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppColors.grass)
                        .accessibilityHidden(true)
                    Text("Emergency exit")
                        .font(AppTypography.display(30))
                    if challenge?.stage == .readyToConfirm,
                       let reason = challenge?.reason {
                        Text("Type your reason again to end Screen-Free Morning without the tag.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.muted)
                        Text(reason)
                            .font(AppTypography.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.sm)
                            .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                        TextField("Type your reason again", text: $emergencyConfirmation)
                            .textInputAutocapitalization(.sentences)
                            .font(AppTypography.headline)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Type your reason again")
                            .onChange(of: emergencyConfirmation) { _, newValue in
                                _ = viewModel.submitEmergencyExitConfirmation(newValue)
                            }
                    } else {
                        Text("What do you need your phone for?")
                            .font(AppTypography.title)
                        Text("Take a moment to name what you’re reaching for.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.muted)
                        TextField("e.g. Reply to a message", text: $emergencyReason)
                            .textInputAutocapitalization(.sentences)
                            .font(AppTypography.headline)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("What do you need your phone for?")
                    }
                    Button(challenge?.stage == .readyToConfirm ? "End Screen-Free Morning" : "Continue") {
                        if challenge?.stage == .readyToConfirm {
                            guard viewModel.confirmEmergencyExit() else { return }
                            showEmergencyExit = false
                        } else {
                            _ = viewModel.submitEmergencyExitReason(emergencyReason)
                        }
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .disabled(challenge?.stage == .readyToConfirm
                        ? challenge?.canConfirm != true
                        : EmergencyExitChallenge.normalizedReason(emergencyReason).isEmpty)
                    Button("Keep Screen-Free Morning running") {
                        showEmergencyExit = false
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle("Emergency exit")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func cancelEmergencyExit() {
        emergencyReason = ""
        emergencyConfirmation = ""
        viewModel.cancelEmergencyExitChallenge()
        showEmergencyExit = false
    }
}

#Preview("Screen-Free Morning · repair needed") {
    ScreenFreeMorningView(
        occurrence: MorningQuietOccurrence(
            scheduledStart: Date().addingTimeInterval(-12 * 60),
            scheduledEnd: Date().addingTimeInterval(18 * 60),
            actualStart: Date(),
            outcome: .active
        )
    )
    .environmentObject(FocusRunViewModel(startsExternalServices: false))
}
