import SwiftUI

struct NightFlockOrientationView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    private let steps: [(String, String)] = [
        ("Choose one goal together", "Your group agrees on one thing to practise for seven nights."),
        ("Keep your own routine", "Bedtimes and Wind Down routines can be different. Share only the ideas you want others to see."),
        ("Help one another follow through", "See nightly progress and send a small cheer. There are no rankings."),
        ("You control what is shared", "Your app choices and exact schedule stay on your phone. Group sharing and impact sharing are separate choices.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Slumber Party").font(AppTypography.display(30))
            Text("A small guide before you begin").font(AppTypography.body).foregroundStyle(AppColors.secondaryText)
            Spacer(minLength: 0)
            Text(steps[step].0).font(AppTypography.title)
            Text(steps[step].1).font(AppTypography.body).foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: AppSpacing.xs) {
                ForEach(steps.indices, id: \.self) { index in
                    Circle().fill(index == step ? AppColors.grass : AppColors.stroke).frame(width: 8, height: 8)
                }
            }
            HStack {
                Button("Dismiss") {
                    viewModel.dismissNightFlockOrientation()
                    dismiss()
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                Spacer()
                Button(step == steps.count - 1 ? "Got it" : "Next") {
                    if step == steps.count - 1 {
                        viewModel.finishNightFlockOrientation()
                        dismiss()
                    } else {
                        step += 1
                    }
                }
                .buttonStyle(PixelPrimaryButtonStyle())
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.paper.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
