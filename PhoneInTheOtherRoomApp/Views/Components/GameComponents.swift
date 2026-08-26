import SwiftUI

enum OlliePalette {
    static let appBackground = Color(red: 0.04, green: 0.07, blue: 0.04)
    static let cardBackground = Color(red: 0.09, green: 0.12, blue: 0.08)
    static let elevatedCard = Color(red: 0.13, green: 0.17, blue: 0.11)
    static let cream = Color(red: 0.98, green: 0.92, blue: 0.78)
    static let brown = Color(red: 0.39, green: 0.22, blue: 0.12)
    static let darkBrown = Color(red: 0.20, green: 0.12, blue: 0.08)
    static let pasture = Color(red: 0.38, green: 0.63, blue: 0.31)
    static let pastureDark = Color(red: 0.22, green: 0.43, blue: 0.25)
    static let sky = Color(red: 0.55, green: 0.78, blue: 0.92)
    static let tile = Color(red: 0.62, green: 0.65, blue: 0.58)
    static let amber = Color(red: 0.93, green: 0.64, blue: 0.20)
    static let success = Color(red: 0.24, green: 0.58, blue: 0.35)
    static let sadBlue = Color(red: 0.44, green: 0.56, blue: 0.70)
    static let ink = Color(red: 0.13, green: 0.13, blue: 0.11)
    static let mist = Color.white.opacity(0.72)
    static let line = Color.white.opacity(0.10)
}

struct GamePanelView<Content: View>: View {
    var title: String?
    var prominence: PanelProminence = .regular
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(OlliePalette.mist)
            }
            content
        }
        .padding(prominence == .hero ? 20 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: prominence == .hero ? 34 : 24, style: .continuous)
                .fill(prominence == .hero ? OlliePalette.elevatedCard : OlliePalette.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: prominence == .hero ? 34 : 24, style: .continuous)
                .stroke(OlliePalette.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 16)
    }
}

enum PanelProminence {
    case regular
    case hero
}

struct OllieSpriteView: View {
    var mood: OllieMood
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.96, green: 0.84, blue: 0.52))
            Circle()
                .fill(Color(red: 0.30, green: 0.16, blue: 0.09))
                .frame(width: size * 0.68, height: size * 0.68)
                .offset(y: size * 0.04)
            Ellipse()
                .fill(.white)
                .frame(width: size * 0.42, height: size * 0.62)
                .offset(y: size * 0.02)
            Triangle()
                .fill(Color(red: 0.24, green: 0.12, blue: 0.07))
                .frame(width: size * 0.24, height: size * 0.32)
                .rotationEffect(.degrees(-18))
                .offset(x: -size * 0.27, y: -size * 0.25)
            Triangle()
                .fill(Color(red: 0.24, green: 0.12, blue: 0.07))
                .frame(width: size * 0.24, height: size * 0.32)
                .rotationEffect(.degrees(18))
                .offset(x: size * 0.27, y: -size * 0.25)
            Circle()
                .fill(.black)
                .frame(width: size * 0.08, height: size * 0.08)
                .offset(x: -size * 0.13, y: -size * 0.03)
            Circle()
                .fill(.black)
                .frame(width: size * 0.08, height: size * 0.08)
                .offset(x: size * 0.13, y: -size * 0.03)
            Capsule()
                .fill(Color(red: 0.12, green: 0.07, blue: 0.05))
                .frame(width: size * 0.14, height: size * 0.09)
                .offset(y: size * 0.12)
            Capsule()
                .fill(Color(red: 0.88, green: 0.30, blue: 0.28))
                .frame(width: size * 0.13, height: mood == .sad ? size * 0.03 : size * 0.16)
                .offset(y: size * 0.24)
            Circle()
                .stroke(Color.white.opacity(0.72), lineWidth: max(2, size * 0.025))
            if mood == .sad {
                Capsule()
                    .fill(OlliePalette.sadBlue)
                    .frame(width: size * 0.07, height: size * 0.18)
                    .offset(x: size * 0.24, y: -size * 0.02)
            }
            if mood == .alert {
                Text("!")
                    .font(.system(size: size * 0.26, weight: .black, design: .monospaced))
                    .foregroundStyle(OlliePalette.amber)
                    .offset(x: size * 0.38, y: -size * 0.35)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: Color.black.opacity(0.30), radius: 12, x: 0, y: 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: mood)
    }

    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

struct IsometricFocusYardView: View {
    var state: FocusRunState
    var bucket: ProximityBucket
    var distanceMeters: Double?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let homePoint = CGPoint(x: size.width * 0.18, y: size.height * 0.58)
            let dogPoint = CGPoint(x: dogX(in: size), y: size.height * 0.58 - dogLift)

            ZStack {
                background
                pastureGrid
                    .opacity(0.62)
                    .position(x: size.width * 0.52, y: size.height * 0.70)

                DistanceTrail(start: homePoint, end: dogPoint, progress: distanceProgress)
                    .stroke(trailColor, style: StrokeStyle(lineWidth: 8, lineCap: .round, dash: [3, 10]))
                    .shadow(color: trailColor.opacity(0.35), radius: 12)

                closeZone
                    .position(homePoint)
                    .opacity(distanceProgress < 0.14 ? 0.92 : 0.42)

                HomeWatchMarker()
                    .position(homePoint)

                PhoneDogMarker(mood: state.ollieMood)
                    .position(dogPoint)
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: distanceProgress)

                VStack(alignment: .leading, spacing: 4) {
                    Text("WATCH HOME")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                    Text(distanceLabel)
                        .font(.system(.title2, design: .rounded).weight(.black))
                        .monospacedDigit()
                    Text(distanceCaption)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.66))
                }
                .foregroundStyle(.white)
                .padding(12)
                .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .position(x: size.width * 0.50, y: size.height * 0.18)
            }
        }
        .frame(height: 360)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 26, x: 0, y: 16)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.16, blue: 0.14),
                    Color(red: 0.04, green: 0.09, blue: 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [trailColor.opacity(0.35), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            stateOverlay
        }
    }

    private var stateOverlay: Color {
        switch state {
        case .warningPhoneTooClose: return OlliePalette.amber.opacity(0.20)
        case .endedEarly: return OlliePalette.sadBlue.opacity(0.26)
        case .completed: return OlliePalette.success.opacity(0.18)
        default: return .clear
        }
    }

    private var pastureGrid: some View {
        VStack(spacing: -18) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: -12) {
                    ForEach(0..<4, id: \.self) { col in
                        IsoTile()
                            .fill(tileColor(row: row, col: col))
                            .frame(width: 72, height: 44)
                            .overlay(IsoTile().stroke(Color.white.opacity(0.10), lineWidth: 1))
                    }
                }
                .offset(x: row.isMultiple(of: 2) ? 0 : 30)
            }
        }
    }

    private var closeZone: some View {
        Circle()
            .stroke(OlliePalette.amber.opacity(0.82), style: StrokeStyle(lineWidth: 3, dash: [6, 6]))
            .background(Circle().fill(OlliePalette.amber.opacity(0.08)))
            .frame(width: 120, height: 120)
    }

    private var distanceProgress: CGFloat {
        guard let distanceMeters else {
            switch bucket {
            case .waitingForDistance: return 0.18
            case .withYou: return 0.06
            case .sameRoom: return 0.28
            case .doorway: return 0.58
            case .probablyOtherRoom, .demo: return 0.86
            case .signalLost, .unsupported: return 0.18
            }
        }
        return min(1, max(0.04, CGFloat(distanceMeters / 8.0)))
    }

    private var dogLift: CGFloat {
        switch state {
        case .completed: return 20
        case .endedEarly: return -4
        default: return distanceProgress > 0.5 ? 14 : 0
        }
    }

    private var trailColor: Color {
        if let distanceMeters, distanceMeters < 2.0 { return OlliePalette.amber }
        switch state {
        case .completed: return OlliePalette.success
        case .endedEarly: return OlliePalette.sadBlue
        default: return OlliePalette.success
        }
    }

    private var distanceLabel: String {
        guard let distanceMeters else { return "Waiting" }
        return "\(String(format: "%.1f", distanceMeters)) m"
    }

    private var distanceCaption: String {
        guard let distanceMeters else { return "Waiting for live distance" }
        if distanceMeters < 2.0 { return "Phone dog is too close" }
        if distanceMeters < 5 { return "Phone dog is leaving" }
        return "Phone dog is away"
    }

    private func dogX(in size: CGSize) -> CGFloat {
        let minX = size.width * 0.24
        let maxX = size.width * 0.82
        return minX + (maxX - minX) * distanceProgress
    }

    private func tileColor(row: Int, col: Int) -> Color {
        (row + col).isMultiple(of: 2) ? OlliePalette.pasture : OlliePalette.pastureDark
    }

    private struct IsoTile: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
            return path
        }
    }

    private struct DistanceTrail: Shape {
        var start: CGPoint
        var end: CGPoint
        var progress: CGFloat

        var animatableData: CGFloat {
            get { progress }
            set { progress = newValue }
        }

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let control = CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - 64)
            path.move(to: start)
            path.addQuadCurve(to: end, control: control)
            return path
        }
    }

    private struct HomeWatchMarker: View {
        var body: some View {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.46))
                    Image(systemName: "applewatch")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white)
                }
                .frame(width: 76, height: 76)
                Text("Home")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
    }

    private struct PhoneDogMarker: View {
        var mood: OllieMood

        var body: some View {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    OllieSpriteView(mood: mood, size: 84)
                    Image(systemName: "iphone")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.66), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .offset(x: 6, y: 6)
                }
                Text("Phone / Ollie")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
    }
}

struct EventTickerView: View {
    var events: [SessionEvent]

    var body: some View {
        GamePanelView(title: "Pasture log") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(events.prefix(5)) { event in
                    Text(event.title)
                        .font(.caption)
                        .foregroundStyle(color(for: event.severity))
                        .lineLimit(2)
                }
                if events.isEmpty {
                    Text("Ollie is waiting at the gate.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
    }

    private func color(for severity: EventSeverity) -> Color {
        switch severity {
        case .info: return .white.opacity(0.78)
        case .success: return OlliePalette.success
        case .warning: return OlliePalette.amber
        case .critical: return Color(red: 1.0, green: 0.35, blue: 0.32)
        }
    }
}

struct RewardRevealView: View {
    var reward: RewardItem?

    var body: some View {
        GamePanelView(title: "Ollie found") {
            if let reward {
                HStack(spacing: 12) {
                    Image(assetName(for: reward.type))
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .padding(4)
                        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reward.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text(reward.rarity.rawValue.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(reward.isDemoReward ? OlliePalette.amber : OlliePalette.success)
                        Text(reward.description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }
            } else {
                Text("Ollie is still sniffing around the pasture.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
    }

    private func assetName(for type: RewardType) -> String {
        switch type {
        case .ollieMail: return "RewardOllieMail"
        case .letter: return "RewardLetter"
        case .ribbon: return "RewardRibbon"
        case .trophy: return "RewardTrophy"
        case .tennisBall: return "RewardTennisBall"
        case .stick: return "RewardStick"
        case .postcard: return "RewardPostcard"
        case .sheepBadge: return "RewardSheepBadge"
        case .fieldMap: return "RewardFieldMap"
        case .muddyPaw: return "RewardMuddyPaw"
        }
    }
}

struct PixelButtonStyle: ButtonStyle {
    var tint: Color = OlliePalette.brown

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.75 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .shadow(color: tint.opacity(configuration.isPressed ? 0.18 : 0.34), radius: 18, x: 0, y: 10)
    }
}
