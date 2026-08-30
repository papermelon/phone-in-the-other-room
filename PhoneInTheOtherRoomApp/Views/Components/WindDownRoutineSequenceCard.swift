import SwiftUI

/// A non-interactive reminder of the private sequence chosen for this run.
/// The run owns the frozen steps; this card never reads future preferences or
/// turns an invitation into a tracked checklist.
struct WindDownRoutineSequenceCard: View {
    let eyebrow: String
    let steps: [WindDownRoutineStep]

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(eyebrow)
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Your optional ideas")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)

                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Image(systemName: step.activity?.systemImage ?? "leaf.fill")
                            .foregroundStyle(AppColors.grass)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text("\(index + 1). \(step.title)")
                            .font(AppTypography.body.weight(.semibold))
                            .foregroundStyle(AppColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("An invitation, not a checklist.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eyebrow). Optional ideas: \(steps.map(\.title).joined(separator: ", "))")
    }
}

#Preview("Routine sequence") {
    WindDownRoutineSequenceCard(
        eyebrow: "BEFORE BED",
        steps: [
            .suggested(.read, phase: .evening),
            .custom("Leave room for a sketch", phase: .evening)
        ]
    )
    .padding()
    .background(AppColors.paper)
}
