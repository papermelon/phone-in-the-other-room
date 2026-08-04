import SwiftUI
import UIKit

struct NightJourneyView: View {
    let run: FocusRun
    let reduceMotion: Bool

    // The dog/ and farm/ groups intentionally provide namespaces in the asset
    // catalog. Keep the qualified names here so Release builds render the same
    // assets as previews and Debug builds.
    private let environmentAsset = "farm/farm_hills_side_scroll_test"
    private let environmentAspectRatio: CGFloat = 1983.0 / 793.0
    private let scrollCycleDuration: TimeInterval = 18

    private func journey(at date: Date) -> NightJourneyProgress {
        guard let plan = run.nightWatchPlan else {
            return NightJourneyProgress(fraction: 0, segment: .prairie)
        }
        return NightJourneyProgress.resolve(plan: plan, at: date)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.14, paused: reduceMotion)) { context in
            let journey = journey(at: context.date)
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    sceneBackground(for: journey.segment, size: size, at: context.date)
                    OllieWalkCycleView(
                        state: ollieState(for: journey.segment),
                        frame: reduceMotion ? 0 : walkFrame(at: context.date),
                        size: min(112, size.width * 0.28)
                    )
                        .position(
                            x: size.width * 0.38,
                            y: ollieGroundY(for: size)
                        )
                    VStack {
                        HStack(alignment: .top) {
                            sceneBadge(
                                title: journey.segment.title.uppercased(),
                                detail: "Ollie is on watch"
                            )
                            Spacer()
                            sceneBadge(
                                title: String(format: "%.1f MI", journey.illustratedMiles),
                                detail: "ILLUSTRATED TRAIL"
                            )
                        }
                        Spacer()
                        HStack {
                            Text("A quiet trail, one step at a time.")
                                .font(AppTypography.caption)
                                .foregroundStyle(.white.opacity(0.92))
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background(.black.opacity(0.28), in: Capsule())
                            Spacer()
                        }
                    }
                    .padding(AppSpacing.sm)
                }
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .stroke(AppColors.stroke.opacity(0.48), lineWidth: 2)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Ollie on the \(journey.segment.title.lowercased), \(Int(journey.fraction * 100)) percent along the illustrated quiet trail"
                )
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
    }

    private func sceneBackground(
        for segment: NightJourneySegment,
        size: CGSize,
        at date: Date
    ) -> some View {
        ZStack {
            scrollingEnvironment(size: size, at: date)
            atmosphere(for: segment)
            if segment == .moonlit {
                Circle()
                    .fill(AppColors.wool.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .overlay(Circle().fill(AppColors.ink).offset(x: 10, y: -4))
                    .offset(x: size.width * 0.29, y: -size.height * 0.22)
            } else if segment == .sunrise {
                Circle()
                    .fill(AppColors.amber.opacity(0.92))
                    .frame(width: 38, height: 38)
                    .offset(x: size.width * 0.30, y: -size.height * 0.20)
            }
        }
    }

    private func scrollingEnvironment(size: CGSize, at date: Date) -> some View {
        let imageWidth = size.height * environmentAspectRatio
        let cycle = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: scrollCycleDuration)
        let progress = cycle >= 0 ? cycle / scrollCycleDuration : (cycle + scrollCycleDuration) / scrollCycleDuration
        let offset = reduceMotion ? 0 : CGFloat(progress) * imageWidth

        return HStack(spacing: 0) {
            environmentImage(width: imageWidth, height: size.height)
            environmentImage(width: imageWidth, height: size.height)
        }
        .frame(width: imageWidth * 2, height: size.height, alignment: .leading)
        .offset(x: -offset)
        .frame(width: size.width, height: size.height, alignment: .leading)
        .clipped()
        .accessibilityHidden(true)
    }

    private func environmentImage(width: CGFloat, height: CGFloat) -> some View {
        JourneyAssetImage(name: environmentAsset, contentMode: .fill)
            .frame(width: width, height: height)
    }

    private func atmosphere(for segment: NightJourneySegment) -> some View {
        Rectangle()
            .fill(atmosphereTint(for: segment))
            .blendMode(.multiply)
            .allowsHitTesting(false)
    }

    private func ollieGroundY(for size: CGSize) -> CGFloat {
        let ollieSize = min(112, size.width * 0.28)
        // The generated run frames place Ollie's feet at 330/360 of the canvas.
        // The scene's black silhouette begins at roughly 78% of its height.
        return size.height * 0.78 - ollieSize * 0.4167
    }

    private func sceneBadge(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(pixelFont(.caption2))
                .foregroundStyle(.white.opacity(0.92))
            Text(detail)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 6)
        .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
    }

    private func ollieState(for segment: NightJourneySegment) -> OllieRitualState {
        switch segment {
        case .prairie, .mountain: return .guarding
        case .moonlit: return .overnight
        case .sunrise: return .morningQuiet
        }
    }

    private func walkFrame(at date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate * 7.0).modulo(6)
    }

    private func atmosphereTint(for segment: NightJourneySegment) -> Color {
        switch segment {
        case .prairie: return .white.opacity(0.02)
        case .mountain: return AppColors.lavender.opacity(0.10)
        case .moonlit: return AppColors.ink.opacity(0.26)
        case .sunrise: return AppColors.amber.opacity(0.10)
        }
    }
}

private extension Int {
    func modulo(_ value: Int) -> Int {
        let remainder = self % value
        return remainder >= 0 ? remainder : remainder + value
    }
}

private struct OllieWalkCycleView: View {
    let state: OllieRitualState
    let frame: Int
    let size: CGFloat

    var body: some View {
        Group {
            if state == .completed {
                OllieRitualView(state: state, size: size)
            } else {
                JourneyAssetImage(name: "dog/dog_run_frame_0\(frame + 1)")
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Journey art is optional content: a missing or miscompiled catalog member
/// must never turn the active-run scene into an empty rectangle. The qualified
/// catalog names are checked at runtime and the fallback remains legible in a
/// TestFlight build while the rest of the run continues normally.
private struct JourneyAssetImage: View {
    let name: String
    var contentMode: ContentMode = .fit

    var body: some View {
        if let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .antialiased(false)
                .aspectRatio(contentMode: contentMode)
        } else {
            ZStack {
                LinearGradient(
                    colors: [AppColors.sky, AppColors.grass.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Image(systemName: name.hasPrefix("dog/") ? "figure.walk" : "mountain.2.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .aspectRatio(contentMode: contentMode)
            .accessibilityLabel("Journey illustration unavailable")
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
