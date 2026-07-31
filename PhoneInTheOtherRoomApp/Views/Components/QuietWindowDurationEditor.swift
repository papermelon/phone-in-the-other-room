import SwiftUI

struct QuietWindowDurationEditor: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var isExpanded: Bool

    init(initiallyExpanded: Bool = false) {
        self._isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                durationPicker(
                    title: "Before bed",
                    selection: $viewModel.nightWatchPreferences.windDownMinutes
                )
                durationPicker(
                    title: "After waking",
                    selection: $viewModel.nightWatchPreferences.morningQuietMinutes
                )
                Text("Choose each window separately, from 15 minutes to 3 hours.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            .padding(.top, AppSpacing.md)
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "clock")
                    .foregroundStyle(AppColors.grass)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Your Wind Down")
                        .font(AppTypography.headline)
                    Text(summary)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
        .tint(AppColors.grass)
        .onChange(of: viewModel.nightWatchPreferences.windDownMinutes) { _, _ in
            viewModel.saveQuietTimeDurations()
        }
        .onChange(of: viewModel.nightWatchPreferences.morningQuietMinutes) { _, _ in
            viewModel.saveQuietTimeDurations()
        }
    }

    private var summary: String {
        "\(viewModel.nightWatchPreferences.windDownMinutes) min before bed · " +
        "\(viewModel.nightWatchPreferences.morningQuietMinutes) min after waking"
    }

    private func durationPicker(
        title: String,
        selection: Binding<Int>
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.body)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(QuietTimeDurationOptions.including(selection.wrappedValue), id: \.self) { minutes in
                    Text(QuietTimeDurationOptions.label(for: minutes)).tag(minutes)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColors.grass)
        }
    }
}

enum QuietTimeDurationOptions {
    static let all = [15, 30, 45, 60, 90, 120, 180]

    static func including(_ minutes: Int) -> [Int] {
        Array(Set(all + [minutes])).sorted()
    }

    static func label(for minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return hours == 1 ? "1 hour" : "\(hours) hours"
            }
            return "\(hours) hr \(remainingMinutes) min"
        }
        return "\(minutes) minutes"
    }
}

#Preview {
    PixelCard {
        QuietWindowDurationEditor(initiallyExpanded: true)
            .environmentObject(FocusRunViewModel())
    }
    .padding()
    .background(AppColors.paper)
}
