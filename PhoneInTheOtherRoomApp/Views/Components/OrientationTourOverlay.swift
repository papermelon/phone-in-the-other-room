import SwiftUI

enum OrientationTourTarget: Hashable {
    case homePlan
    case startAction
    case phoneAway
    case navigation
    case farmPasture
    case farmCapacity
    case farmWool
    case farmShop
    case farmSearch
    case settingsWindDown
    case nightsRecord
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

struct OptionalOrientationTarget: ViewModifier {
    let target: OrientationTourTarget?

    func body(content: Content) -> some View {
        if let target {
            content.orientationTourTarget(target)
        } else {
            content
        }
    }
}

struct CountingSheepOrientationTourOverlay: View {
    let step: CountingSheepOrientationStep
    var targetFrame: CGRect?
    var context: FirstRunAdvanceContext = .defaults
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var coachMarkSize: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let highlightedFrame {
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
                } else {
                    Color.black.opacity(0.54)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                }

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

    private var highlightedFrame: CGRect? {
        targetFrame?.insetBy(dx: -5, dy: -5)
    }

    private var targetCornerRadius: CGFloat { AppRadius.lg + 4 }

    private var stepNumber: Int { FirstRunJourney.number(for: step, context: context) }
    private var stepCount: Int { FirstRunJourney.count(context: context) }
    private var title: String { FirstRunGuideCopy.title(for: step) }
    private var message: String { FirstRunGuideCopy.message(for: step) }
    private var isFirstVisibleStep: Bool {
        FirstRunJourney.visibleSteps(context: context).first == step.normalized
    }

    private var coachMark: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.xs) {
                Label("GETTING TO KNOW COUNTING SHEEP", systemImage: "sparkles")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.lavender)
                Spacer()
                Text("\(stepNumber) OF \(stepCount)")
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(AppColors.muted)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.title)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: AppSpacing.sm) {
                Button(FirstRunGuideCopy.skipForNow, action: onSkip)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .frame(minHeight: 44)

                Spacer(minLength: 0)

                if !isFirstVisibleStep {
                    Button("Back", action: onBack)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.ink)
                        .frame(minHeight: 44)
                }

                Button(step.normalized == .completion ? "Done" : "Continue", action: onNext)
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
        .accessibilityLabel("Getting to know Counting Sheep, step \(stepNumber) of \(stepCount). \(title). \(message)")
    }

    private func coachMarkPosition(in size: CGSize) -> CGPoint {
        let margin = AppSpacing.sm
        let measuredHeight = max(220, coachMarkSize.height)
        let halfHeight = measuredHeight / 2
        guard let highlightedFrame else {
            return CGPoint(x: size.width / 2, y: min(size.height * 0.42, size.height - halfHeight - margin))
        }
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

#Preview("Farm coach mark · large type") {
    ZStack {
        AppColors.paper.ignoresSafeArea()
        CountingSheepOrientationTourOverlay(
            step: .farmMeetSheep,
            targetFrame: CGRect(x: 16, y: 120, width: 361, height: 220),
            onBack: {},
            onNext: {},
            onSkip: {}
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Farm coach mark · missing target") {
    ZStack {
        AppColors.paper.ignoresSafeArea()
        CountingSheepOrientationTourOverlay(
            step: .farmShop,
            targetFrame: nil,
            onBack: {},
            onNext: {},
            onSkip: {}
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
