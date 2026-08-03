import SwiftUI

struct QuietAppearanceGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("A quieter screen")
                    .font(AppTypography.display(34))
                Text("Counting Sheep can soften its own Wind Down screen. If you also want the rest of iOS to appear grayscale, Apple exposes that as an accessibility setting or Shortcut rather than an app-controlled switch.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Optional iPhone Shortcut")
                            .font(AppTypography.headline)
                        Text("In Shortcuts, create a personal automation for Wind Down time that opens Settings → Accessibility → Display & Text Size → Color Filters. Turn Color Filters on and choose Grayscale. Create a matching automation for the morning.")
                            .font(AppTypography.body)
                        Text("This is optional and remains under your control; Counting Sheep never changes system-wide display settings by itself.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Quiet appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { QuietAppearanceGuideView() }
}
