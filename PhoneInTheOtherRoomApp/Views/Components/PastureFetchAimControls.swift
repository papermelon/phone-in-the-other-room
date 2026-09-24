import SwiftUI

/// Adjustable controls offer the same landing guide and travel model as a swipe.
struct PastureFetchAimControls: View {
    let game: PastureFetchViewModel
    @State private var heading = 0.0
    @State private var strength = 30.0

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Turn from straight ahead, then choose your throw strength.")
                    .fixedSize(horizontal: false, vertical: true)
                Text(heading == 0 ? "Direction: straight ahead" : "Direction: \(Int(abs(heading)))° \(heading < 0 ? "left" : "right")")
                    .fixedSize(horizontal: false, vertical: true)
                Slider(value: $heading, in: -180...180, step: 5) {
                    Text("Throw direction")
                }
                .frame(minHeight: 44)
                .accessibilityValue(heading == 0 ? "Straight ahead" : "\(Int(abs(heading))) degrees \(heading < 0 ? "left" : "right") from ahead")
                Text("Strength: \(Int(strength)) percent")
                Slider(value: $strength, in: 1...100, step: 1) { Text("Throw strength") }
                    .frame(minHeight: 44)
                    .accessibilityValue("\(Int(strength)) percent")
                if let target = game.practiceTarget, let aim = preview {
                    Text(landingDescription(aim, target: target))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fetch-aim-description")
                }
                Button("Throw ball") { game.aimBall(heading: heading, strength: strength, launch: true) }
                    .frame(minHeight: 44)
            }
            .disabled(!game.canThrow)
            .onChange(of: heading) { _, _ in updateAim() }
            .onChange(of: strength) { _, _ in updateAim() }
        } label: {
            Text("Aim without swiping").fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
        }
        .font(AppTypography.caption)
    }

    private var preview: PastureScenePoint? {
        guard let travel = PastureFetchPractice.translation(heading: heading, strength: strength) else { return nil }
        return PastureFetchRound.throwTarget(origin: game.origin, translation: travel, predictedTranslation: travel)
    }
    private func updateAim() { game.aimBall(heading: heading, strength: strength) }
    private func landingDescription(_ point: PastureScenePoint, target: PastureFetchPractice.Target) -> String {
        switch target.points(for: point) {
        case 3: return "Your aim is inside the inner ring."
        case 1: return "Your aim is inside the clover."
        default:
            let horizontal = point.x < target.point.x - target.radius ? "left of" : point.x > target.point.x + target.radius ? "right of" : "level with"
            let vertical = point.y < target.point.y ? "beyond" : "short of"
            return "Your aim is \(horizontal) and \(vertical) the clover."
        }
    }
}

#Preview("Practice aim · large text") {
    PastureFetchAimControls(game: PastureFetchViewModel())
        .padding().environment(\.dynamicTypeSize, .accessibility3)
}
