import SwiftUI

struct NightJourneyView: View {
    let run: FocusRun
    let reduceMotion: Bool

    private var journey: NightJourneyProgress {
        guard let plan = run.nightWatchPlan else {
            return NightJourneyProgress(fraction: 0, segment: .prairie)
        }
        return NightJourneyProgress.resolve(plan: plan, at: Date())
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                sky
                hills
                PixelAssetImage(name: AssetSlot.Dog.focused)
                    .frame(width: 76, height: 76)
                    .offset(x: (reduceMotion ? 0 : CGFloat(journey.fraction) * proxy.size.width * 0.55) - proxy.size.width * 0.28, y: -18)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: journey.fraction)
                    .accessibilityLabel("Ollie on the (journey.segment.title.lowercased())")
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(journey.segment.title.uppercased())
                            .font(pixelFont(.caption2))
                            .foregroundStyle(.white.opacity(0.86))
                        Text("Ollie is (Int(journey.fraction * 100))% along the quiet trail")
                            .font(AppTypography.caption)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(AppSpacing.sm)
                .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                .padding(AppSpacing.sm)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        }
        .frame(height: 190)
        .accessibilityElement(children: .contain)
    }

    private var sky: some View {
        ZStack {
            PixelAssetImage(name: AssetSlot.Farm.backgroundDay, contentMode: .fill)
            LinearGradient(
                colors: [overlayColor.opacity(0.2), overlayColor.opacity(0.64)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var hills: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: -30) {
                Ellipse().fill(AppColors.bark.opacity(0.86)).frame(width: 260, height: 90)
                Ellipse().fill(AppColors.grass.opacity(0.88)).frame(width: 280, height: 110)
                Ellipse().fill(AppColors.bark.opacity(0.72)).frame(width: 240, height: 88)
            }
            .offset(y: 42)
        }
    }

    private var overlayColor: Color {
        switch journey.segment {
        case .prairie: return AppColors.sky
        case .mountain: return AppColors.lavender
        case .moonlit: return AppColors.ink
        case .sunrise: return AppColors.amber
        }
    }
}

#Preview("Night journey") {
    NightJourneyView(
        run: FocusRun(
            plannedDurationSeconds: 60,
            startedAt: Date(),
            state: .running,
            nightWatchPlan: NightWatchPreferences.defaults.makePlan()
        ),
        reduceMotion: true
    )
    .padding()
    .background(AppColors.paper)
}
