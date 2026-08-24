import SwiftUI

/// Phone-authoritative presentation of the independent morning occurrence.
/// It contains no Wind Down result or Slumber Party entry point.
struct ScreenFreeMorningView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let occurrence: MorningQuietOccurrence

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

                PixelCard {
                    Menu {
                        ForEach(QuietPurposeCue.allCases, id: \.self) { cue in
                            Button(cue.shieldText) { viewModel.setCurrentPurposeCue(cue) }
                        }
                    } label: {
                        HStack {
                            Label("Purpose", systemImage: "leaf.fill")
                            Spacer()
                            Text(viewModel.currentPurposeCue?.shieldText ?? "Choose")
                        }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.ink)
                    }
                    .accessibilityLabel("Current purpose: \(viewModel.currentPurposeCue?.shieldText ?? "not chosen")")
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

                Button("Finish Screen-Free Morning") {
                    viewModel.finishScreenFreeMorning(occurrence.id)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(PixelPrimaryButtonStyle())
                .accessibilityHint("Saves actual elapsed minutes and returns to Home")
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Screen-Free Morning")
        .navigationBarTitleDisplayMode(.inline)
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
