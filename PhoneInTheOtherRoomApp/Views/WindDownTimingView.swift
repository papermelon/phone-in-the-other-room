import SwiftUI

struct WindDownTimingView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var bedtime = Date()
    @State private var wake = Date()
    @State private var windDownMinutes = 30
    @State private var morningQuietMinutes = 30

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Your usual quiet window")
                    .font(AppTypography.display(30))
                Text("Set the sleep window Ollie uses for your regular Wind Down. You can still add Phone Away from Home.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        DatePicker("Bedtime", selection: $bedtime, displayedComponents: .hourAndMinute)
                        DatePicker("Wake time", selection: $wake, displayedComponents: .hourAndMinute)
                    }
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        durationPicker(title: "Quiet before bed", selection: $windDownMinutes)
                        durationPicker(title: "Quiet after waking", selection: $morningQuietMinutes)
                    }
                }

                Button("Save timing") {
                    viewModel.saveTimingDraft(
                        bedtime: bedtime,
                        wake: wake,
                        windDownMinutes: windDownMinutes,
                        morningQuietMinutes: morningQuietMinutes
                    )
                    dismiss()
                }
                .buttonStyle(PixelPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Wind Down timing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private func durationPicker(title: String, selection: Binding<Int>) -> some View {
        HStack {
            Text(title).font(AppTypography.headline)
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

    private func load() {
        bedtime = viewModel.nightWatchBedtimeDate
        wake = viewModel.nightWatchWakeDate
        windDownMinutes = viewModel.nightWatchPreferences.windDownMinutes
        morningQuietMinutes = viewModel.nightWatchPreferences.morningQuietMinutes
    }
}

#Preview {
    NavigationStack {
        WindDownTimingView()
            .environmentObject(FocusRunViewModel())
    }
}
