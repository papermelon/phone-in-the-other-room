import SwiftUI

enum OrientationTourTarget: Hashable {
    case homePlan
    case startAction
    case navigation
}

struct OrientationTourTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [OrientationTourTarget: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [OrientationTourTarget: Anchor<CGRect>],
        nextValue: () -> [OrientationTourTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

extension View {
    func orientationTourTarget(_ target: OrientationTourTarget) -> some View {
        anchorPreference(key: OrientationTourTargetPreferenceKey.self, value: .bounds) {
            [target: $0]
        }
    }
}

struct CountingSheepOrientationTourOverlay: View {
    let step: CountingSheepOrientationStep
    let targetFrame: CGRect
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var coachMarkSize: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                OrientationSpotlightShape(
                    targetFrame: highlightedFrame,
                    cornerRadius: targetCornerRadius
                )
                    .fill(
                        Color.black.opacity(0.64),
                        style: FillStyle(eoFill: true)
                    )

                RoundedRectangle(cornerRadius: targetCornerRadius, style: .continuous)
                    .stroke(AppColors.lavender, lineWidth: 4)
                    .frame(width: highlightedFrame.width, height: highlightedFrame.height)
                    .position(x: highlightedFrame.midX, y: highlightedFrame.midY)
                    .shadow(color: AppColors.lavender.opacity(0.34), radius: 10)
                    .accessibilityHidden(true)

                coachMark
                    .padding(.horizontal, AppSpacing.md)
                    .background {
                        GeometryReader { coachProxy in
                            Color.clear.preference(
                                key: OrientationCoachMarkSizePreferenceKey.self,
                                value: coachProxy.size
                            )
                        }
                    }
                    .position(coachMarkPosition(in: proxy.size))
            }
            .contentShape(Rectangle())
        }
        .transition(.opacity)
        .animation(reduceMotion ? AppMotion.reducedFade : AppMotion.stateChange, value: step)
        .onPreferenceChange(OrientationCoachMarkSizePreferenceKey.self) { coachMarkSize = $0 }
        .accessibilityElement(children: .contain)
    }

    private var highlightedFrame: CGRect {
        let inset: CGFloat
        switch step {
        case .home: inset = 6
        case .start: inset = 5
        case .navigation: inset = 4
        }
        return targetFrame.insetBy(dx: -inset, dy: -inset)
    }

    private var targetCornerRadius: CGFloat {
        switch step {
        case .home: return AppRadius.lg + 4
        case .start: return 15
        case .navigation: return AppRadius.lg + 10
        }
    }

    private var coachMark: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.xs) {
                Label("QUICK TOUR", systemImage: "sparkles")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.lavender)
                Spacer()
                Text("\(step.number) OF \(CountingSheepOrientationStep.count)")
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(AppColors.muted)
            }

            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: step == .home ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppColors.lavender)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.title)
                    Text(message)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: AppSpacing.sm) {
                Button("Skip tour", action: onSkip)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .frame(minHeight: 44)

                Spacer(minLength: 0)

                if step != .home {
                    Button("Back", action: onBack)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.ink)
                        .frame(minHeight: 44)
                }

                Button(step == .navigation ? "Done" : "Next", action: onNext)
                    .font(AppTypography.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .frame(minHeight: 44)
                    .background(AppColors.lavender, in: RoundedRectangle(cornerRadius: AppRadius.lg))
            }
        }
        .foregroundStyle(AppColors.ink)
        .padding(AppSpacing.lg)
        .frame(maxWidth: 440, alignment: .leading)
        .background(
            AppColors.surface,
            in: RoundedRectangle(cornerRadius: AppRadius.lg + 6, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg + 6, style: .continuous)
                .stroke(AppColors.lavender, lineWidth: 3)
        }
        .shadow(color: Color.black.opacity(0.34), radius: 20, x: 0, y: 8)
        .accessibilityLabel("Quick tour, step \(step.number) of \(CountingSheepOrientationStep.count). \(title). \(message)")
    }

    private var title: String {
        switch step {
        case .home: return "Tonight’s plan"
        case .start: return "Start what’s ready"
        case .navigation: return "Your four places"
        }
    }

    private var message: String {
        switch step {
        case .home:
            return "Bedtime, wake time, and both quiet windows live here."
        case .start:
            return "Begin tonight’s Wind Down—or a practice quiet—from this button."
        case .navigation:
            return "Nights keeps your records. Farm follows Ollie. Settings holds your plan."
        }
    }

    private func coachMarkPosition(in size: CGSize) -> CGPoint {
        let margin = AppSpacing.sm
        let measuredHeight = max(220, coachMarkSize.height)
        let halfHeight = measuredHeight / 2
        let spaceBelow = size.height - highlightedFrame.maxY - margin
        let proposedY: CGFloat
        if spaceBelow >= measuredHeight + margin {
            proposedY = highlightedFrame.maxY + margin + halfHeight
        } else {
            proposedY = highlightedFrame.minY - margin - halfHeight
        }
        let y = min(size.height - halfHeight - margin, max(halfHeight + margin, proposedY))
        return CGPoint(x: size.width / 2, y: y)
    }
}

private struct OrientationSpotlightShape: Shape {
    let targetFrame: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: targetFrame,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return path
    }
}

private struct OrientationCoachMarkSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

struct CountingSheepPracticeOfferSheet: View {
    let onStartPractice: () -> Void
    let onMaybeLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Label("TOUR COMPLETE", systemImage: "checkmark.circle.fill")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Want to test it?")
                    .font(AppTypography.title)
                Text("Start a real five-minute practice quiet. It will appear in Nights, but it will not count as a protected night or start Ollie’s sheep search.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
            }

            Button(action: onStartPractice) {
                Label("Try 5 minutes", systemImage: "timer")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PixelPrimaryButtonStyle())

            Button("Maybe later", action: onMaybeLater)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .foregroundStyle(AppColors.ink)
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.paper.ignoresSafeArea())
    }
}

struct OrientationRecordPrompt: View {
    let onSeeNights: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("YOUR PRACTICE RECORD", systemImage: "book.closed.fill")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Five minutes of quiet, recorded plainly.")
                    .font(AppTypography.headline)
                Text("It appears in Nights, but it does not count as a Wind Down or open a sheep search.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                Button("See it in Nights", action: onSeeNights)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
    }
}

#Preview("Home coach mark") {
    ZStack {
        AppColors.paper.ignoresSafeArea()
        PixelCard {
            Text("Tonight · 11:00 PM – 7:00 AM")
                .font(AppTypography.headline)
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)

        CountingSheepOrientationTourOverlay(
            step: .home,
            targetFrame: CGRect(x: 16, y: 90, width: 361, height: 170),
            onBack: {},
            onNext: {},
            onSkip: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Practice offer") {
    CountingSheepPracticeOfferSheet(onStartPractice: {}, onMaybeLater: {})
}

#Preview("Navigation coach mark · large type") {
    ZStack {
        AppColors.paper.ignoresSafeArea()
        CountingSheepOrientationTourOverlay(
            step: .navigation,
            targetFrame: CGRect(x: 16, y: 720, width: 361, height: 82),
            onBack: {},
            onNext: {},
            onSkip: {}
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.light)
}
