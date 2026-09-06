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
        id(tip).anchorPreference(key: ContextualGuideTargetPreferenceKey.self, value: .bounds) {
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
        GeometryReader { viewport in
            ScrollViewReader { scroll in
                VStack(spacing: AppSpacing.sm) {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlayPreferenceValue(ContextualGuideTargetPreferenceKey.self) { targets in
                            GeometryReader { proxy in
                                if let tip, let anchor = targets[tip] {
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
                    if let tip {
                        CountingSheepContextualTourOverlay(
                            tip: tip,
                            targetFrame: .zero,
                            onAcknowledge: { onAcknowledge(tip); self.tip = nil },
                            onSkipAll: { onSkipAll(); self.tip = nil }
                        )
                        .frame(height: viewport.size.height * 0.48)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.sm)
                    }
                }
                .task(id: "\(String(describing: tip))-\(viewport.size)") {
                    guard let tip else { return }
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    scroll.scrollTo(tip, anchor: .top)
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

    var body: some View {
        GuidePrimer(eyebrow: "APP GUIDE", title: tip.title, message: tip.message) {
            VStack(spacing: AppSpacing.xs) {
                Button(action: onAcknowledge) {
                    Text("Got it")
                        .font(AppTypography.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelPrimaryButtonStyle())
                Button("Skip all tips", action: onSkipAll)
                    .font(AppTypography.caption)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .id(tip)
    }
}

#Preview("Contextual guide · largest text") {
    CountingSheepContextualTourOverlay(
        tip: .barnCapacity, targetFrame: .zero, onAcknowledge: {}, onSkipAll: {}
    )
    .frame(height: 360)
    .padding()
    .environment(\.dynamicTypeSize, .accessibility5)
}
