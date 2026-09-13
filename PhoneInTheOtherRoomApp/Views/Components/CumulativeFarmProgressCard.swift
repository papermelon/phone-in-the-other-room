import SwiftUI

struct CumulativeFarmProgressCard: View {
    let credit: CumulativeFarmCredit

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("PROGRESS THAT STAYS")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Wind Down · \(Int(credit.windDownSeconds / 60)) / 420 min")
                    .font(pixelFont(.body))
                Text("Phone Away · \(Int(credit.phoneAwaySeconds / 60)) / 100 min")
                    .font(pixelFont(.body))
                Text("Each full meter opens a search. Shorter sessions carry forward and grow wool. Brief access is excluded.")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.secondaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview("Partial night") {
    CumulativeFarmProgressCard(credit: CumulativeFarmCredit(windDownSeconds: 338 * 60, phoneAwaySeconds: 12 * 60))
}
