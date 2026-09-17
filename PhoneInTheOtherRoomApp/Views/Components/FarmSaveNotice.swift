import SwiftUI

struct FarmSaveNotice: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Your Farm save").font(AppTypography.body)
                Text(message).font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                Button("Try again", action: onRetry)
                    .font(AppTypography.body)
            }
        }
        .padding(AppSpacing.md)
    }
}

#Preview("Save unavailable") {
    FarmSaveNotice(message: "Your Farm save could not be read. The original has been kept.", onRetry: {})
}
