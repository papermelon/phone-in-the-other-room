import SwiftUI

/// Phone-authoritative presentation of the independent morning occurrence.
/// It contains no Wind Down result or Slumber Party entry point.
struct ScreenFreeMorningView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let occurrence: MorningQuietOccurrence
    @State private var showEmergencyExit = false
    @State private var emergencyReason = ""
    @State private var emergencyConfirmation = ""

    private var endDate: Date { occurrence.scheduledEnd }
    private var actualMinutes: Int { occurrence.eligibleElapsedMinutes(at: Date()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("SCREEN-FREE MORNING")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text("Your phone is staying away for now.")
                            .font(AppTypography.title)
                            .foregroundStyle(AppColors.ink)
                        Text("Until \(OllieFormat.time(endDate))")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondaryText)
                        Text("\(actualMinutes) actual minutes so far")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                            .accessibilityLabel("\(actualMinutes) actual Screen-Free Morning minutes so far")
                    }
                }

                let tracker = viewModel.briefAccessTrackerSummary(forScreenFreeMorning: occurrence)
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("BRIEF ACCESS")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text(tracker.subtitle)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondaryText)
                        Text("Brief Access does not reduce your Screen-Free Morning minutes.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }

                if let parent = linkedParentRun,
                   let steps = parent.nightWatchPlan?.morningRoutine,
                   !steps.isEmpty {
                    WindDownRoutineSequenceCard(
                        eyebrow: "BEFORE THE PHONE RETURNS",
                        steps: steps
                    )
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("THIS TIME IS FOR")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Menu {
                            ForEach(QuietPurposeCue.allCases, id: \.self) { cue in
                                Button {
                                    viewModel.setCurrentPurposeCue(cue)
                                } label: {
                                    if viewModel.currentPurposeCue == cue {
                                        Label(cue.appFacingTitle, systemImage: "checkmark")
                                    } else {
                                        Text(cue.appFacingTitle)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Label("Purpose", systemImage: "leaf.fill")
                                Spacer()
                                Text(viewModel.currentPurposeCue?.appFacingTitle ?? "Choose")
                            }
                            .font(AppTypography.body.weight(.semibold))
                            .foregroundStyle(AppColors.ink)
                        }
                        .accessibilityLabel("Current purpose: \(viewModel.currentPurposeCue?.appFacingTitle ?? "not chosen")")
                    }
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("APP PROTECTION")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text("Your consented app and category selection is used when protection is available.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondaryText)
                        if viewModel.shieldingReadiness != .ready {
                            Text("Protection needs repair in Settings before another start.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.warning)
                        }
                    }
                }

                if linkedParentRun?.guardKind == .nfcTag {
                    Button("Tap tag to finish Wind Down") {
                        viewModel.requestEndWindDown()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .accessibilityHint("Uses the registered Wind Down tag to finish this morning and its parent Wind Down")

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
                    .accessibilityHint("Saves actual elapsed minutes and ends this Wind Down")
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
                        Text("Type your reason again to end this Wind Down without the tag.")
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
                    Button(challenge?.stage == .readyToConfirm ? "End Wind Down" : "Continue") {
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
                    Button("Keep Wind Down running") {
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
