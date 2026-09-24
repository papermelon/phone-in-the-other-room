import SwiftUI

/// Bramble's existing run cycle keeps waits in the same world as the Farm.
/// Animation is decorative; VoiceOver receives one stable progress label.
struct SheepLoadingView: View {
    var title: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(_ title: String? = nil) { self.title = title }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion || scenePhase != .active)) { context in
                let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                let frame = Int(time * 8) % NightJourneyAssets.companionSheepRunFrames.count
                VStack(spacing: 0) {
                    if let art = UIImage(named: NightJourneyAssets.companionSheepRunFrames[frame])
                        ?? UIImage(named: "sheep/sheep_bramble_wool_ready") {
                        Image(uiImage: art)
                            .resizable().interpolation(.high).scaledToFit()
                            .frame(width: 64, height: 64)
                            .offset(x: reduceMotion ? 0 : sin(time * .pi * 2 / 1.5) * 5,
                                    y: reduceMotion ? 0 : -abs(sin(time * .pi * 2 / 1.5)) * 7)
                    } else {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(AppColors.wool).frame(width: 64, height: 64)
                    }
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(0..<3) { index in
                            let lift = reduceMotion ? 0 : max(0, sin(time * .pi * 2 / 1.5 - Double(index) * 0.8))
                            Circle().fill(AppColors.grass)
                                .frame(width: 5, height: 5)
                                .opacity(reduceMotion ? 0.7 : 0.35 + lift * 0.65)
                                .offset(y: -lift * 4)
                        }
                    }
                }
            }
            .frame(width: 76, height: 76)
            .accessibilityHidden(true)
            if let title {
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title ?? "Loading")
        .accessibilityValue("In progress")
    }
}

#Preview("Bramble · loading") { SheepLoadingView("Bringing your party together…").padding().background(AppColors.paper) }
#Preview("Bramble · paused") {
    SheepLoadingView("Syncing live updates…").padding().background(AppColors.paper)
        .environment(\.scenePhase, .inactive)
}
#Preview("Bramble · large text") {
    SheepLoadingView("Syncing live updates…").padding().background(AppColors.paper)
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
