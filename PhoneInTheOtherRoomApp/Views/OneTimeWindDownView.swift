import SwiftUI

struct OneTimeWindDownView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var starts = Date().addingTimeInterval(15 * 60)
    @State private var ends = Date().addingTimeInterval(45 * 60)
    @State private var message = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("A little extra quiet")
                    .font(AppTypography.display(30))
                Text("Add one bounded quiet period outside your usual sleep plan. It is an additional quiet record, not another protected night.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        DatePicker("Starts", selection: $starts, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("Ends", selection: $ends, displayedComponents: [.date, .hourAndMinute])
                        Text("Ollie will remind you at the start. You can end it normally whenever you are ready.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }

                Button("Use this Wind Down once") {
                    guard viewModel.adjustNextWindDown(start: starts, end: ends, role: .additionalQuiet) else {
                        message = "Choose a future period that does not overlap another saved window."
                        return
                    }
                    dismiss()
                }
                .buttonStyle(PixelPrimaryButtonStyle())
                .frame(maxWidth: .infinity)

                if viewModel.nextWindDownOverride?.role == .additionalQuiet {
                    Button("Clear one-time Wind Down", role: .destructive) {
                        viewModel.clearNextWindDownOverride()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }

                if !message.isEmpty {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("One-Time Wind Down")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private func load() {
        guard let override = viewModel.nextWindDownOverride,
              override.role == .additionalQuiet else { return }
        starts = override.interval.start
        ends = override.interval.end
    }
}

#Preview {
    NavigationStack {
        OneTimeWindDownView()
            .environmentObject(FocusRunViewModel())
    }
}
