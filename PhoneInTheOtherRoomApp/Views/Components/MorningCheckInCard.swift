import SwiftUI

struct MorningCheckInCard: View {
    enum Presentation {
        case standalone
        case embedded
    }

    @EnvironmentObject private var viewModel: FocusRunViewModel
    var record: NightWatchRecord?
    var presentation: Presentation
    @State private var isExpanded = false

    init(
        record: NightWatchRecord? = nil,
        presentation: Presentation = .standalone
    ) {
        self.record = record
        self.presentation = presentation
    }

    private var noteDate: Date {
        record?.plan.wakeTime ?? Date()
    }

    private var note: MorningCheckIn {
        viewModel.morningCheckIn(for: noteDate)
    }

    var body: some View {
        Group {
            if presentation == .standalone {
                PixelCard { disclosure }
            } else {
                disclosure
                    .padding(.vertical, AppSpacing.sm)
            }
        }
    }

    private var disclosure: some View {
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
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Morning note")
                        .font(AppTypography.headline)
                    Text("For \(noteDate.formatted(.dateTime.weekday(.wide).month().day())) · \(note.summary)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
        .tint(AppColors.grass)
    }

    private var sleepOnsetBinding: Binding<SleepOnsetEstimate?> {
        Binding(
            get: { note.sleepOnset },
            set: { viewModel.updateMorningSleepOnset($0, for: noteDate) }
        )
    }

    private var restfulnessBinding: Binding<MorningRestfulness?> {
        Binding(
            get: { note.restfulness },
            set: { viewModel.updateMorningRestfulness($0, for: noteDate) }
        )
    }

    private var bedtimeSleepinessBinding: Binding<BedtimeSleepiness?> {
        Binding(
            get: { note.bedtimeSleepiness },
            set: { viewModel.updateBedtimeSleepiness($0, for: noteDate) }
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
