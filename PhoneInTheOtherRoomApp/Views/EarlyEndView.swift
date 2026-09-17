import SwiftUI

struct EarlyEndView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PixelCard {
                    receiptHeader
                }
                NightWatchReceiptCard(
                    run: viewModel.activeRun,
                    sleepSummary: viewModel.lastNightSleep,
                    sleepAuthorization: viewModel.sleepAuthorization,
                    screenTimeAuthorization: viewModel.screenTimeAuthorization,
                    record: terminalRecord,
                    farmCredit: viewModel.activeRun.flatMap { viewModel.farmState.cumulativeCredit?.receipts[$0.id] }
                )
                if let run = viewModel.activeRun,
                   let credit = viewModel.farmState.cumulativeCredit?.receipts[run.id], credit.creditedSeconds > 0 {
                    Button("View farm") {
                        NotificationCenter.default.post(name: .countingSheepShowFarm, object: nil)
                        viewModel.resetSetup()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PixelPrimaryButtonStyle())
                }
                Button(AppCopy.EarlyEnd.doneButton.value) { viewModel.resetSetup() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
            }
            .padding(16)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .onAppear(perform: viewModel.refreshSleepSummary)
    }

    @ViewBuilder
    private var receiptHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stackedReceiptHeader
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    OllieRitualView(state: .completed, presentation: .cardCompanion)
                    receiptMessage
                        .frame(width: 176, alignment: .leading)
                        .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                stackedReceiptHeader
            }
        }
    }

    private var stackedReceiptHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            OllieRitualView(state: .completed, presentation: .cardCompanion)
                .frame(maxWidth: .infinity)
            receiptMessage
        }
    }

    private var receiptMessage: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(terminalPresentation?.eyebrow ?? "TIMER ENDED EARLY")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.secondaryText)
            Text(terminalPresentation?.headline ?? "The timer ended early.")
                .font(pixelFont(.title3))
            Text(terminalPresentation?.timerSummary ?? "Your session summary is below.")
                .font(pixelFont(.body))
                .foregroundStyle(AppColors.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(terminalPresentation?.accessibilityLabel ?? "The timer ended early. Your session summary is below.")
    }

    private var terminalPresentation: RunTerminalPresentation? {
        viewModel.activeRun.map { RunTerminalPresentation(run: $0) }
    }

    private var terminalRecord: NightWatchRecord? {
        guard let run = viewModel.activeRun else { return nil }
        return viewModel.nightWatchRecords.first { $0.id == run.id }
    }
}
