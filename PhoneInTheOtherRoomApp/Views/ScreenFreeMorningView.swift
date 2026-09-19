import SwiftUI

/// Phone-authoritative presentation of the independent morning occurrence.
/// It contains no Wind Down result or Slumber Party entry point.
struct ScreenFreeMorningView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let occurrence: MorningQuietOccurrence
    var fixedNow: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

                PersonalShieldActions()

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

                    Button("End Screen-Free Morning") { viewModel.openPersonalShield(.endSession) }
                        .font(AppTypography.body).foregroundStyle(AppColors.muted).frame(minHeight: 44)
                } else {
                    Button("End Screen-Free Morning") {
                        viewModel.openPersonalShield(.endSession)
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
    }

    private var countdownInterval: ClosedRange<Date> {
        let now = Date()
        return now...max(now, endDate)
    }

    private var linkedParentRun: FocusRun? {
        guard let run = viewModel.activeRun,
              run.id == occurrence.linkedWindDownRunID,
              ![.setup, .completed, .endedEarly].contains(run.state) else {
            return nil
        }
        return run
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
