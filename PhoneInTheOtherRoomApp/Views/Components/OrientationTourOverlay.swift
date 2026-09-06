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
        id(target).anchorPreference(key: OrientationTourTargetPreferenceKey.self, value: .bounds) {
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

/// The primer occupies a separate region so it cannot cover the page it explains.
struct GuidePresentationModifier<Panel: View>: ViewModifier {
    let target: OrientationTourTarget?
    @ViewBuilder let panel: () -> Panel

    func body(content: Content) -> some View {
        GeometryReader { viewport in
            ScrollViewReader { scroll in
                VStack(spacing: AppSpacing.sm) {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlayPreferenceValue(OrientationTourTargetPreferenceKey.self) { anchors in
                            GeometryReader { proxy in
                                if let target, let anchor = anchors[target] {
                                    let frame = proxy[anchor]
                                    RoundedRectangle(cornerRadius: AppRadius.lg)
                                        .stroke(AppColors.lavender, lineWidth: 3)
                                        .frame(width: frame.width, height: frame.height)
                                        .position(x: frame.midX, y: frame.midY)
                                }
                            }
                            .clipped()
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                        }
                    if target != nil {
                        panel()
                            .frame(height: viewport.size.height * 0.48)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.bottom, AppSpacing.sm)
                    }
                }
                .task(id: "\(String(describing: target))-\(viewport.size)") {
                    guard let target else { return }
                    // Wait for the reserved panel and selected screen to lay out.
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    scroll.scrollTo(target, anchor: .top)
                }
            }
        }
    }
}

struct GuidePrimer<Actions: View>: View {
    let eyebrow: String
    let title: String
    let message: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        // One visible scroll region includes the actions at extreme text sizes.
        // No fixed text height or concealed scroll indicators can truncate the primer.
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(eyebrow)
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.lavender)
                Text(title)
                    .font(AppTypography.headline)
                Text(message)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                actions()
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
        }
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(AppColors.ink)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.lavender, lineWidth: 3)
        }
        .accessibilityElement(children: .contain)
    }
}

struct CountingSheepOrientationTourOverlay: View {
    let step: CountingSheepOrientationStep
    var targetFrame: CGRect?
    var context: FirstRunAdvanceContext = .defaults
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    private var chapter: FirstRunGuideChapter {
        FirstRunJourney.chapter(for: step) ?? .homeBasics
    }

    var body: some View {
        GuidePrimer(
            eyebrow: "\(chapter.title) · \(FirstRunJourney.number(for: step, chapter: chapter)) OF \(FirstRunJourney.count(for: chapter))",
            title: FirstRunGuideCopy.title(for: step),
            message: FirstRunGuideCopy.message(for: step)
        ) {
            VStack(spacing: AppSpacing.xs) {
                Button(action: onNext) {
                    Text(step.normalized == .completion ? "Done" : "Continue")
                        .font(AppTypography.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelPrimaryButtonStyle())
                // Full-width rows preserve words at every supported text size.
                if FirstRunJourney.visibleSteps(for: chapter).first != step.normalized {
                    Button("Back", action: onBack)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                Button(FirstRunGuideCopy.skipForNow, action: onSkip)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .font(AppTypography.caption)
            .buttonStyle(.plain)
        }
        .id(step)
    }
}

#Preview("Guide · largest text") {
    CountingSheepOrientationTourOverlay(step: .start, onBack: {}, onNext: {}, onSkip: {})
        .frame(height: 360)
        .padding()
        .environment(\.dynamicTypeSize, .accessibility5)
}
