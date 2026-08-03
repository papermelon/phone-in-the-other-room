import SwiftUI

struct NightJourneyView: View {
    let run: FocusRun
    let reduceMotion: Bool

    private func journey(at date: Date) -> NightJourneyProgress {
        guard let plan = run.nightWatchPlan else {
            return NightJourneyProgress(fraction: 0, segment: .prairie)
        }
        return NightJourneyProgress.resolve(plan: plan, at: date)
    }

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let journey = journey(at: context.date)
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    sky(for: journey.segment)
                    hills(for: journey.segment)
                    PixelAssetImage(name: AssetSlot.Dog.focused)
                        .frame(width: 76, height: 76)
                        .offset(x: (reduceMotion ? 0 : CGFloat(journey.fraction) * proxy.size.width * 0.55) - proxy.size.width * 0.28, y: -18)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: journey.fraction)
                        .accessibilityLabel("Ollie on the \(journey.segment.title.lowercased())")
                    HStack {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(journey.segment.title.uppercased())
                                .font(pixelFont(.caption2))
                                .foregroundStyle(.white.opacity(0.86))
                            Text("Ollie is \(Int(journey.fraction * 100))% along the quiet trail")
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
        }
        .frame(height: 190)
        .accessibilityElement(children: .contain)
    }

    private func sky(for segment: NightJourneySegment) -> some View {
        ZStack {
            PixelAssetImage(name: AssetSlot.Farm.backgroundDay, contentMode: .fill)
            LinearGradient(
                colors: [overlayColor(for: segment).opacity(0.2), overlayColor(for: segment).opacity(0.64)],
                startPoint: .top,
                endPoint: .bottom
            )
            if segment == .moonlit {
                Circle()
                    .fill(AppColors.wool.opacity(0.86))
                    .frame(width: 42, height: 42)
                    .overlay(Circle().fill(AppColors.ink).offset(x: 12, y: -6))
                    .offset(x: 110, y: -48)
            } else if segment == .sunrise {
                Circle()
                    .fill(AppColors.amber.opacity(0.9))
                    .frame(width: 48, height: 48)
                    .offset(x: 112, y: -42)
            }
        }
    }

    private func hills(for segment: NightJourneySegment) -> some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: -30) {
                Ellipse().fill(segment == .mountain ? AppColors.lavender.opacity(0.82) : AppColors.bark.opacity(0.86)).frame(width: 260, height: segment == .mountain ? 128 : 90)
                Ellipse().fill(AppColors.grass.opacity(0.88)).frame(width: 280, height: segment == .mountain ? 150 : 110)
                Ellipse().fill(segment == .prairie ? AppColors.amber.opacity(0.6) : AppColors.bark.opacity(0.72)).frame(width: 240, height: segment == .mountain ? 112 : 88)
            }
            .offset(y: 42)
        }
    }

    private func overlayColor(for segment: NightJourneySegment) -> Color {
        switch segment {
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
