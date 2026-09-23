import SwiftUI

struct WindDownHabitHomeCard: View {
    var routine: [WindDownRoutineStep]
    var plan: WindDownHabitPlan
    @Binding var useSmallerVersion: Bool
    var saveMessage: String? = nil
    var onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onEdit) {
                routineSummary
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home-wind-down-routine")
            .accessibilityHint("Explore ideas and edit your whole Wind Down routine")

            if plan.hasSmallerVersion || saveMessage != nil {
                routineOptions.padding(AppSpacing.md)
            }
        }
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
        .onChange(of: plan.hasSmallerVersion) { _, available in
            if !available { useSmallerVersion = false }
        }
        .onAppear {
            if !plan.hasSmallerVersion { useSmallerVersion = false }
        }
    }

    private var routineSummary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text("Your Wind Down routine")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                    .accessibilityHidden(true)
            }
            Text("Make the time before bed your own.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if invitations.isEmpty {
                Text("Explore ideas for reading, unwinding, or getting ready for tomorrow.")
                    .font(AppTypography.body)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(Array(invitations.enumerated()), id: \.offset) { index, invitation in
                        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                            Text("\(index + 1)")
                                .font(pixelFont(.caption))
                                .foregroundStyle(AppColors.grass)
                                .frame(minWidth: AppSpacing.lg)
                            Text(invitation).font(AppTypography.body)
                        }
                    }
                }
            }
            if let cue = plan.cue {
                detail("Begin", value: cue)
            }
            if let preparation = plan.preparation {
                detail("Get ready", value: preparation)
            }
            Text(plan.phonePlacement.actionCue)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            Text(routine.isEmpty ? "Explore routine ideas" : "Explore ideas & edit routine")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.grass)
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var routineOptions: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
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
    }

    private var invitations: [String] {
        if useSmallerVersion, let smaller = WindDownHabitRules.smallerActivityInvitation(for: plan) {
            return [smaller]
        }
        return routine.map(\.title)
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
    WindDownHabitHomeCard(routine: [], plan: WindDownHabitPlan(), useSmallerVersion: .constant(false), onEdit: {})
        .padding(AppSpacing.md)
        .background(AppColors.paper)
}

#Preview("My evening · smaller version") {
    WindDownHabitHomeCard(
        routine: [.suggested(.read, phase: .evening), .suggested(.stretch, phase: .evening), .suggested(.prepareTomorrow, phase: .evening)],
        plan: WindDownHabitPlan(cue: "After brushing my teeth", preparation: "Book beside the chair", smallerActivity: "Read one paragraph"),
        useSmallerVersion: .constant(true),
        onEdit: {}
    )
    .padding(AppSpacing.md)
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}

#Preview("Whole evening routine") {
    WindDownHabitHomeCard(
        routine: [.suggested(.read, phase: .evening), .suggested(.stretch, phase: .evening), .suggested(.prepareTomorrow, phase: .evening)],
        plan: WindDownHabitPlan(cue: "After dinner"),
        useSmallerVersion: .constant(false), onEdit: {})
        .padding(AppSpacing.md).background(AppColors.paper).preferredColorScheme(.dark)
}
