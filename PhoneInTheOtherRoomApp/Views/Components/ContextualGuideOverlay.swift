import SwiftUI

struct ContextualGuideTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [CountingSheepContextualTip: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [CountingSheepContextualTip: Anchor<CGRect>],
        nextValue: () -> [CountingSheepContextualTip: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

extension View {
    func contextualGuideTarget(_ tip: CountingSheepContextualTip) -> some View {
        anchorPreference(key: ContextualGuideTargetPreferenceKey.self, value: .bounds) {
            [tip: $0]
        }
    }

    func contextualGuideOverlay(
        tip: Binding<CountingSheepContextualTip?>,
        onAcknowledge: @escaping (CountingSheepContextualTip) -> Void,
        onSkipAll: @escaping () -> Void
    ) -> some View {
        modifier(ContextualGuideOverlayModifier(
            tip: tip,
            onAcknowledge: onAcknowledge,
            onSkipAll: onSkipAll
        ))
    }
}

private struct ContextualGuideOverlayModifier: ViewModifier {
    @Binding var tip: CountingSheepContextualTip?
    let onAcknowledge: (CountingSheepContextualTip) -> Void
    let onSkipAll: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityHidden(tip != nil)
            .overlayPreferenceValue(ContextualGuideTargetPreferenceKey.self) { targets in
                GeometryReader { proxy in
                    if let tip, let anchor = targets[tip] {
                        CountingSheepContextualTourOverlay(
                            tip: tip,
                            targetFrame: proxy[anchor],
                            onAcknowledge: {
                                onAcknowledge(tip)
                                self.tip = nil
                            },
                            onSkipAll: {
                                onSkipAll()
                                self.tip = nil
                            }
                        )
                        .zIndex(50)
                    }
                }
            }
    }
}

struct CountingSheepContextualTourOverlay: View {
    let tip: CountingSheepContextualTip
    let targetFrame: CGRect
    let onAcknowledge: () -> Void
    let onSkipAll: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var coachMarkSize: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ContextualSpotlightShape(targetFrame: highlightedFrame)
                    .fill(Color.black.opacity(0.64), style: FillStyle(eoFill: true))

                RoundedRectangle(cornerRadius: AppRadius.lg + 4, style: .continuous)
                    .stroke(AppColors.lavender, lineWidth: 4)
                    .frame(width: highlightedFrame.width, height: highlightedFrame.height)
                    .position(x: highlightedFrame.midX, y: highlightedFrame.midY)
                    .shadow(color: AppColors.lavender.opacity(0.34), radius: 10)
                    .accessibilityHidden(true)

                coachMark(isBelowTarget: coachMarkAppearsBelow(in: proxy.size))
                    .padding(.horizontal, AppSpacing.md)
                    .background {
                        GeometryReader { coachProxy in
                            Color.clear.preference(
                                key: ContextualCoachMarkSizePreferenceKey.self,
                                value: coachProxy.size
                            )
                        }
                    }
                    .position(coachMarkPosition(in: proxy.size))
            }
            .contentShape(Rectangle())
        }
        .transition(.opacity)
        .animation(reduceMotion ? AppMotion.reducedFade : AppMotion.stateChange, value: tip)
        .onPreferenceChange(ContextualCoachMarkSizePreferenceKey.self) { coachMarkSize = $0 }
        .accessibilityElement(children: .contain)
    }

    private func coachMark(isBelowTarget: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("APP GUIDE", systemImage: "sparkles")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.lavender)

            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: isBelowTarget ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppColors.lavender)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(tip.title)
                        .font(AppTypography.title)
                    Text(tip.message)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: AppSpacing.sm) {
                Button("Skip all tips", action: onSkipAll)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .frame(minHeight: 44)
                Spacer(minLength: 0)
                Button("Got it", action: onAcknowledge)
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
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg + 6))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg + 6)
                .stroke(AppColors.lavender, lineWidth: 3)
        }
        .shadow(color: Color.black.opacity(0.34), radius: 20, x: 0, y: 8)
        .accessibilityLabel("App guide. \(tip.title). \(tip.message)")
    }

    private var highlightedFrame: CGRect {
        targetFrame.insetBy(dx: -6, dy: -6)
    }

    private func coachMarkPosition(in size: CGSize) -> CGPoint {
        let margin = AppSpacing.sm
        let measuredHeight = max(210, coachMarkSize.height)
        let halfHeight = measuredHeight / 2
        let spaceBelow = size.height - highlightedFrame.maxY - margin
        let proposedY = spaceBelow >= measuredHeight + margin
            ? highlightedFrame.maxY + margin + halfHeight
            : highlightedFrame.minY - margin - halfHeight
        let y = min(size.height - halfHeight - margin, max(halfHeight + margin, proposedY))
        return CGPoint(x: size.width / 2, y: y)
    }

    private func coachMarkAppearsBelow(in size: CGSize) -> Bool {
        coachMarkPosition(in: size).y > highlightedFrame.midY
    }
}

private struct ContextualSpotlightShape: Shape {
    let targetFrame: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: targetFrame,
            cornerSize: CGSize(width: AppRadius.lg + 4, height: AppRadius.lg + 4)
        )
        return path
    }
}

private struct ContextualCoachMarkSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

#Preview("Contextual guide · barn capacity") {
    ZStack {
        AppColors.paper.ignoresSafeArea()
        PixelCard { Text("Pasture space · 20 / 20") }
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
        CountingSheepContextualTourOverlay(
            tip: .barnCapacity,
            targetFrame: CGRect(x: 16, y: 80, width: 361, height: 110),
            onAcknowledge: {},
            onSkipAll: {}
        )
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}
