import SwiftUI

struct EarlyEndView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PixelCard {
                    HStack(alignment: .top, spacing: 14) {
                        OllieRitualView(state: .endedEarly)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(viewModel.activeRun?.nightWatchPlan?.role == .additionalQuiet ? "QUIET TIME ENDED" : AppCopy.EarlyEnd.eyebrow.value)
                                .font(pixelFont(.caption))
                                .foregroundStyle(AppColors.secondaryText)
                            Text(viewModel.activeRun?.nightWatchPlan?.role == .additionalQuiet
                                ? "Quiet time ended early. Your receipt is ready."
                                : AppCopy.EarlyEnd.title.value)
                                .font(pixelFont(.title3))
                            Text(minutesAwayText + " Tonight can simply be a fresh start.")
                                .font(pixelFont(.body))
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }
                }
                NightWatchReceiptCard(
                    run: viewModel.activeRun,
                    sleepSummary: viewModel.lastNightSleep,
                    sleepAuthorization: viewModel.sleepAuthorization,
                    screenTimeAuthorization: viewModel.screenTimeAuthorization
                )
                Button(AppCopy.EarlyEnd.doneButton.value) { viewModel.resetSetup() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PixelPrimaryButtonStyle())
            }
            .padding(16)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .onAppear(perform: viewModel.refreshSleepSummary)
    }

    private var minutesAwayText: String {
        let run = viewModel.activeRun
        let minutes = run?.isNightWatch == true
            ? run?.creditedQuietMinutes ?? 0
            : Int((run?.actualDurationSeconds ?? 0) / 60)
        switch minutes {
        case 0: return "Your phone got a little time away."
        case 1: return "Your phone was away for a minute."
        default: return "Your phone was away for \(minutes) minutes."
        }
    }
}
