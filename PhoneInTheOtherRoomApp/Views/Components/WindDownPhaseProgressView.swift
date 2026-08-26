import SwiftUI

struct WindDownPhaseProgressView: View {
    let interval: ClosedRange<Date>

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            ProgressView(timerInterval: interval, countsDown: false)
                .progressViewStyle(.linear)
                .tint(AppColors.grass)
                .scaleEffect(y: 2, anchor: .center)
                .frame(height: 12)
                .background(AppColors.panel)
                .overlay(Rectangle().stroke(AppColors.stroke, lineWidth: 2))

            HStack(alignment: .firstTextBaseline) {
                Text("Elapsed")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.secondaryText)
                Spacer(minLength: AppSpacing.sm)
                Text(timerInterval: interval, countsDown: false, showsHours: true)
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(AppColors.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}

#Preview("In progress") {
    WindDownPhaseProgressView(
        interval: Date().addingTimeInterval(-75 * 60)...Date().addingTimeInterval(45 * 60)
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Complete") {
    WindDownPhaseProgressView(
        interval: Date().addingTimeInterval(-2 * 60 * 60)...Date().addingTimeInterval(-60)
    )
    .padding()
    .background(AppColors.paper)
}
