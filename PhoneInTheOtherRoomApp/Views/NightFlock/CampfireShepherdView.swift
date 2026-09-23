import SwiftUI

/// Campfire art uses the person's existing outfit and head drawing beneath one
/// blanket. It never changes the saved avatar or creates a new equipment variant.
struct CampfireShepherdView: View {
    let presentation: CountingSheepPublicPresentation
    var pose: CampfireShepherdPose = .awake
    var size: CGFloat = 72
    var motionEnabled = true
    var seated = false
    var facesLeft: Bool? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        Group {
            if pose == .bedtime {
                if motionEnabled && !reduceMotion && scenePhase == .active && isVisible {
                    TimelineView(.animation(minimumInterval: 1.0 / 15)) { context in
                        sleeping(blanketLift: CampfireShepherdMotionRules.blanketLift(
                            at: context.date.timeIntervalSinceReferenceDate, reduceMotion: reduceMotion,
                            isActive: scenePhase == .active && isVisible))
                    }
                } else {
                    sleeping(blanketLift: 0)
                }
            } else if seated {
                ShepherdStudyCanvas(appearance: seatedAppearance, seated: true)
                    .frame(width: size, height: size)
            } else {
                ShepherdAvatarView(profile: presentation.shepherdProfile, size: size - AppSpacing.sm)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pose.accessibilityDescription)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    private var seatedAppearance: ShepherdStudyAppearance {
        var appearance = ShepherdStudyAppearance(profile: presentation.shepherdProfile)
        if let facesLeft { appearance.faceLeft = facesLeft }
        return appearance
    }

    private func sleeping(blanketLift: Double) -> some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 320
            var p = ShepherdStudyPainter(context: context, texture: true)
            p.context.scaleBy(x: scale, y: scale)
            p.context.translateBy(x: 38, y: 5)
            p = p.rotated(-48, around: CGPoint(x: 123, y: 157))
            p.rounded(37, 67, 176, 91, 28, ShepherdStudyPalette.cream)
            p.rounded(45, 73, 160, 76, 24, ShepherdStudyPalette.masterPaper)

            var person = p
            person.context.clip(to: Path(CGRect(x: 0, y: 0, width: 240, height: 205)))
            ShepherdStudyCanvas(appearance: ShepherdStudyAppearance(profile: presentation.shepherdProfile),
                pose: .init(eyesClosed: true)).draw(in: person)

            let top = 183 - blanketLift
            let blanket = Path { path in
                path.move(to: CGPoint(x: 51, y: top))
                path.addQuadCurve(to: CGPoint(x: 194, y: top), control: CGPoint(x: 123, y: top + 21))
                path.addLine(to: CGPoint(x: 196, y: 252))
                path.addQuadCurve(to: CGPoint(x: 162, y: 285), control: CGPoint(x: 197, y: 286))
                path.addLine(to: CGPoint(x: 83, y: 285))
                path.addQuadCurve(to: CGPoint(x: 49, y: 252), control: CGPoint(x: 48, y: 286))
                path.closeSubpath()
            }
            p.fill(blanket, ShepherdStudyPalette.moon)
            var fold = Path()
            fold.move(to: CGPoint(x: 52, y: top + 4))
            fold.addQuadCurve(to: CGPoint(x: 193, y: top + 4), control: CGPoint(x: 123, y: top + 27))
            p.context.stroke(fold, with: .color(ShepherdStudyPalette.cream),
                             style: StrokeStyle(lineWidth: 9, lineCap: .round))
            p.context.stroke(Path { path in
                path.move(to: CGPoint(x: 70, y: top + 24))
                path.addQuadCurve(to: CGPoint(x: 84, y: 270), control: CGPoint(x: 62, y: 259))
            }, with: .color(ShepherdStudyPalette.midnight.opacity(0.5)), lineWidth: 2)
        }
    }
}

#Preview("Campfire · awake and tucked in") {
    HStack {
        CampfireShepherdView(presentation: .defaultValue, size: 120)
        CampfireShepherdView(presentation: .defaultValue, pose: .bedtime, size: 120)
    }.padding().background(AppColors.paper)
}

#Preview("Campfire · static bedtime") {
    CampfireShepherdView(presentation: .defaultValue, pose: .bedtime, size: 160, motionEnabled: false)
        .padding().background(AppColors.paper)
}
