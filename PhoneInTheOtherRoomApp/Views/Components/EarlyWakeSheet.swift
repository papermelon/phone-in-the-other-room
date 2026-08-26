import SwiftUI
import UIKit

/// A deliberately small decision sheet: it never writes a morning choice
/// until the existing exit credential has authorized the terminal handoff.
struct EarlyWakeSheet: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("I'M AWAKE EARLY")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("What would feel right this morning?")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.ink)
                    Text("These choices only change tonight. Your usual Wind Down plan stays the same.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)

                    choice(
                        title: "Start Screen-Free Morning now",
                        detail: "Begin your full planned morning time now.",
                        intent: .startNow
                    )
                    choice(
                        title: "Keep at usual time",
                        detail: "Leave a calm gap, then begin at your planned wake time.",
                        intent: .deferToUsualTime
                    )
                    choice(
                        title: "Skip today",
                        detail: "Finish Wind Down now without a Screen-Free Morning today.",
                        intent: .skipToday
                    )

                    Button("Keep Wind Down running") {
                        viewModel.chooseEarlyWake(.keepWindDownRunning)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    .accessibilityHint("Leaves your current Wind Down unchanged")

                    if !viewModel.nfcStatus.isEmpty {
                        Text(viewModel.nfcStatus)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .accessibilityLabel("Exit authorization status: \(viewModel.nfcStatus)")
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle("Early wake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: viewModel.nfcStatus) { _, status in
                guard !status.isEmpty, UIAccessibility.isVoiceOverRunning else { return }
                UIAccessibility.post(notification: .announcement, argument: status)
            }
        }
    }

    private func choice(title: String, detail: String, intent: MorningQuietIntent) -> some View {
        Button {
            viewModel.chooseEarlyWake(intent)
            // NFC may keep the run in place while its sheet is visible. The
            // result text remains available from the active journey after this
            // sheet closes, rather than implying an unverified transition.
            dismiss()
        } label: {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.ink)
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}

#Preview("Early wake choices") {
    EarlyWakeSheet()
        .environmentObject(FocusRunViewModel(startsExternalServices: false))
}
