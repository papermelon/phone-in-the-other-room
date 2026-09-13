import SwiftUI

struct WindDownHabitHomeCard: View {
    var activity: String?
    var plan: WindDownHabitPlan
    @Binding var useSmallerVersion: Bool
    var saveMessage: String? = nil
    var onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text("A LITTLE ROOM FOR YOU")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Edit", action: onEdit)
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.grass)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Edit my Wind Down routine")
            }
            Text(invitation)
                .font(AppTypography.headline)
                .fixedSize(horizontal: false, vertical: true)
            if let cue = plan.cue {
                detail("Begin", value: cue)
            }
            if let preparation = plan.preparation {
                detail("Get ready", value: preparation)
            }
            Text(plan.phonePlacement.actionCue)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)

            if plan.hasSmallerVersion {
                Toggle("Smaller version for my next Wind Down", isOn: $useSmallerVersion)
                    .font(AppTypography.caption.weight(.semibold))
                    .tint(AppColors.grass)
                    .frame(minHeight: 44)
                Text(useSmallerVersion
                    ? "One Wind Down only. Your schedule and app protection stay the same."
                    : "For a difficult evening: \(WindDownHabitRules.smallerActivityInvitation(for: plan) ?? "A smaller version").")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let saveMessage {
                Text(saveMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
        .onChange(of: plan.hasSmallerVersion) { _, available in
            if !available { useSmallerVersion = false }
        }
        .onAppear {
            if !plan.hasSmallerVersion { useSmallerVersion = false }
        }
    }

    private var invitation: String {
        if useSmallerVersion, let smaller = WindDownHabitRules.smallerActivityInvitation(for: plan) {
            return smaller
        }
        return activity ?? "Choose something you’ll look forward to."
    }

    private func detail(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(label)
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.muted)
            Text(value)
                .font(AppTypography.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("My evening · empty") {
    WindDownHabitHomeCard(activity: nil, plan: WindDownHabitPlan(), useSmallerVersion: .constant(false), onEdit: {})
        .padding(AppSpacing.md)
        .background(AppColors.paper)
}

#Preview("My evening · smaller version") {
    WindDownHabitHomeCard(
        activity: "Read my book",
        plan: WindDownHabitPlan(cue: "After brushing my teeth", preparation: "Book beside the chair", smallerActivity: "Read one paragraph"),
        useSmallerVersion: .constant(true),
        onEdit: {}
    )
    .padding(AppSpacing.md)
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}
