import SwiftUI

struct MorningCheckInCard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var isExpanded = false

    var body: some View {
        PixelCard {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    question(
                        "About how long did it take to fall asleep?",
                        selection: sleepOnsetBinding,
                        choices: SleepOnsetEstimate.allCases
                    )
                    question(
                        "How rested do you feel this morning?",
                        selection: restfulnessBinding,
                        choices: MorningRestfulness.allCases
                    )
                    question(
                        "When you went to bed, did you feel sleepy?",
                        selection: bedtimeSleepinessBinding,
                        choices: BedtimeSleepiness.allCases
                    )
                    Text("Optional and kept in this app. It is a reflection, not a sleep score.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                .padding(.top, AppSpacing.md)
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "sun.horizon.fill")
                        .foregroundStyle(AppColors.grass)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("A quick morning note")
                            .font(AppTypography.headline)
                        Text("For \(Date().formatted(.dateTime.weekday(.wide).month().day()))")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.grass)
                        Text(viewModel.todayMorningCheckIn.summary)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }
            }
            .tint(AppColors.grass)
        }
    }

    private var sleepOnsetBinding: Binding<SleepOnsetEstimate?> {
        Binding(
            get: { viewModel.todayMorningCheckIn.sleepOnset },
            set: viewModel.updateMorningSleepOnset
        )
    }

    private var restfulnessBinding: Binding<MorningRestfulness?> {
        Binding(
            get: { viewModel.todayMorningCheckIn.restfulness },
            set: viewModel.updateMorningRestfulness
        )
    }

    private var bedtimeSleepinessBinding: Binding<BedtimeSleepiness?> {
        Binding(
            get: { viewModel.todayMorningCheckIn.bedtimeSleepiness },
            set: viewModel.updateBedtimeSleepiness
        )
    }

    private func question<Value>(
        _ title: String,
        selection: Binding<Value?>,
        choices: [Value]
    ) -> some View where Value: MorningCheckInChoice, Value.ID == String {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.body)
            Picker(title, selection: selection) {
                Text("Not answered").tag(Value?.none)
                ForEach(choices) { choice in
                    Text(choice.title).tag(Optional(choice))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

}

#Preview {
    MorningCheckInCard()
        .environmentObject(FocusRunViewModel())
        .padding()
        .background(AppColors.paper)
}
