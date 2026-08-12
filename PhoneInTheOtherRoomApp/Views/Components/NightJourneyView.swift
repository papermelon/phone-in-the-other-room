import SwiftUI
import UIKit

struct NightJourneyView: View {
    let run: FocusRun
    let reduceMotion: Bool
    var mappedBonusPercentagePoints = 0
    var fixedDate: Date?

    @ViewBuilder
    var body: some View {
        if let fixedDate {
            journey(at: fixedDate)
        } else {
            TimelineView(.periodic(from: .now, by: reduceMotion ? 1 : 1.0 / 30.0)) { context in
                journey(at: context.date)
            }
        }
    }

    @ViewBuilder
    private func journey(at date: Date) -> some View {
        if let journey = NightJourneyProgress.resolve(run: run, at: date) {
            GeometryReader { proxy in
                scene(journey: journey, date: date, size: proxy.size)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(for: journey, at: date))
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
        }
    }

    private func scene(journey: NightJourneyProgress, date: Date, size: CGSize) -> some View {
        let profile = NightJourneyTerrainProfile.profile(for: journey.segment)
        let tileWidth = max(320, size.width * 1.15)
        let elapsedSinceStart = date.timeIntervalSince(run.startedAt)
        let travelled = reduceMotion
            ? 0
            : NightJourneyGait.foregroundDistance(elapsedSinceStart: elapsedSinceStart)
        let ollieX = size.width * CGFloat(0.30 + journey.phaseFraction * 0.08)
        let worldPosition = (Double(ollieX) + travelled) / Double(tileWidth)
        let groundY = CGFloat(profile.normalizedHeight(at: worldPosition)) * size.height
        let slope = profile.normalizedSlope(at: worldPosition) * Double(size.height) / Double(tileWidth)
        let rotation = min(12, max(-12, atan(slope) * 180 / .pi))
        let ollieSize = min(OllieRitualPresentation.journeyAnimation.canvasSize, size.width * 0.28)
        let sheepX = min(size.width * 0.87, ollieX + max(116, size.width * 0.39))
        let sheepSize = min(96, size.width * 0.26)
        let sheepWorldPosition = (Double(sheepX) + travelled) / Double(tileWidth)
        let sheepGroundY = CGFloat(profile.normalizedHeight(at: sheepWorldPosition)) * size.height
        let sheepSlope = profile.normalizedSlope(at: sheepWorldPosition) * Double(size.height) / Double(tileWidth)
        let sheepRotation = min(12, max(-12, atan(sheepSlope) * 180 / .pi))
        let frame = NightJourneyGait.frame(
            forForegroundDistance: travelled,
            reduceMotion: reduceMotion
        )
        let ollieGroundAnchor = CGFloat(NightJourneyAssets.ollieRunGroundAnchors[frame])
        let sheepGroundAnchor = CGFloat(NightJourneyAssets.companionSheepRunGroundAnchors[frame])

        return ZStack {
            backdrops(for: journey, size: size)
            terrain(profile: profile, travelled: travelled, tileWidth: tileWidth, size: size)
            clueLayer(journey: journey, profile: profile, travelled: travelled, tileWidth: tileWidth, size: size)
            SheepWalkCycleView(frame: frame, size: sheepSize)
                .rotationEffect(
                    .degrees(sheepRotation),
                    anchor: UnitPoint(x: 0.5, y: sheepGroundAnchor)
                )
                .position(x: sheepX, y: sheepGroundY - sheepSize * (sheepGroundAnchor - 0.5))
            OllieWalkCycleView(
                state: ollieState(for: journey.segment),
                frame: frame,
                size: ollieSize
            )
            .rotationEffect(
                .degrees(rotation),
                anchor: UnitPoint(x: 0.5, y: ollieGroundAnchor)
            )
            .position(x: ollieX, y: groundY - ollieSize * (ollieGroundAnchor - 0.5))

            VStack {
                HStack(alignment: .top) {
                    sceneBadge(
                        title: journey.segment.title.uppercased(),
                        detail: "OLLIE IS FOLLOWING THE TRAIL"
                    )
                    Spacer()
                    sceneBadge(
                        title: remainingText(journey: journey, at: date),
                        detail: destinationText(for: journey)
                    )
                }
                Spacer()
                HStack {
                    Text(narrativeText(for: journey))
                        .font(AppTypography.caption)
                        .foregroundStyle(.white.opacity(0.94))
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(.black.opacity(0.32), in: Capsule())
                    Spacer()
                    if mappedBonusPercentagePoints > 0 {
                        Text("UP TO +\(mappedBonusPercentagePoints) MAPPED")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(7)
                            .background(.black.opacity(0.28), in: Capsule())
                    }
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
    }

    private func backdrops(for journey: NightJourneyProgress, size: CGSize) -> some View {
        let windDownBlend = min(1, max(0, (journey.phaseFraction - 0.45) / 0.10))
        return ZStack {
            if journey.phase == .windDown {
                backdrop(.prairie, size: size, progress: journey.phaseFraction)
                    .opacity(1 - windDownBlend)
                backdrop(.mountain, size: size, progress: journey.phaseFraction)
                    .opacity(windDownBlend)
            } else {
                backdrop(journey.segment, size: size, progress: journey.phaseFraction)
            }
        }
    }

    private func backdrop(_ segment: NightJourneySegment, size: CGSize, progress: Double) -> some View {
        JourneyAssetImage(name: NightJourneyAssets.backdrops[segment] ?? "", contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .scaleEffect(1.08 + progress * 0.04)
            .offset(x: -size.width * CGFloat(progress) * 0.018)
            .clipped()
            .overlay(atmosphereTint(for: segment).blendMode(.multiply))
            .accessibilityHidden(true)
    }

    private func terrain(
        profile: NightJourneyTerrainProfile,
        travelled: Double,
        tileWidth: CGFloat,
        size: CGSize
    ) -> some View {
        Canvas { context, canvasSize in
            let top = terrainPath(profile: profile, travelled: travelled, tileWidth: tileWidth, size: canvasSize)
            context.fill(top, with: .color(AppColors.grass))

            var path = Path()
            path.move(to: CGPoint(x: 0, y: canvasSize.height))
            for x in stride(from: CGFloat(0), through: canvasSize.width + 4, by: 4) {
                let position = (Double(x) + travelled + 18) / Double(tileWidth)
                let y = CGFloat(profile.normalizedHeight(at: position)) * canvasSize.height + 12
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height))
            path.closeSubpath()
            context.fill(path, with: .color(AppColors.floor.opacity(0.78)))
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private func terrainPath(
        profile: NightJourneyTerrainProfile,
        travelled: Double,
        tileWidth: CGFloat,
        size: CGSize
    ) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        for x in stride(from: CGFloat(0), through: size.width + 4, by: 4) {
            let position = (Double(x) + travelled) / Double(tileWidth)
            let y = CGFloat(profile.normalizedHeight(at: position)) * size.height
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        return path
    }

    private func clueLayer(
        journey: NightJourneyProgress,
        profile: NightJourneyTerrainProfile,
        travelled: Double,
        tileWidth: CGFloat,
        size: CGSize
    ) -> some View {
        let count = reachedClueCount(journey.overallFraction)
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let x = size.width * [0.18, 0.70, 0.84][index]
                let position = (Double(x) + (reduceMotion ? 0 : travelled * 0.22)) / Double(tileWidth)
                let y = CGFloat(profile.normalizedHeight(at: position)) * size.height
                JourneyAssetImage(
                    name: NightJourneyAssets.clueAssets[stableClueIndex(index)],
                    contentMode: .fit
                )
                .frame(width: index == 2 ? 58 : 42, height: index == 2 ? 58 : 42)
                .position(x: x, y: y - 18)
                .opacity(0.88)
            }
        }
        .accessibilityHidden(true)
    }

    private func stableClueIndex(_ index: Int) -> Int {
        let seed = run.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return (seed + index) % NightJourneyAssets.clueAssets.count
    }

    private func reachedClueCount(_ fraction: Double) -> Int {
        [0.20, 0.55, 0.82].filter { fraction >= $0 }.count
    }

    private func narrativeText(for journey: NightJourneyProgress) -> String {
        let count = reachedClueCount(journey.overallFraction)
        if journey.phaseFraction >= 0.82 { return "The gate is just ahead." }
        if count > 0 { return "\(count) clue\(count == 1 ? "" : "s") mapped." }
        return "A quiet trail, one step at a time."
    }

    private func remainingText(journey: NightJourneyProgress, at date: Date) -> String {
        guard let transition = journey.nextTransition else { return "TRAIL COMPLETE" }
        let seconds = max(0, Int(transition.timeIntervalSince(date)))
        if seconds >= 3600 {
            return "\(seconds / 3600)H \((seconds % 3600) / 60)M"
        }
        return "\(max(1, Int(ceil(Double(seconds) / 60)))) MIN"
    }

    private func destinationText(for journey: NightJourneyProgress) -> String {
        guard let plan = run.nightWatchPlan else { return "QUIET LEFT" }
        if plan.role == .additionalQuiet { return "QUIET LEFT" }
        switch journey.phase {
        case .windDown: return "TO BEDTIME"
        case .overnight: return "TO MORNING"
        case .morningQuiet: return "QUIET LEFT"
        case .complete: return "TRAIL NOTE READY"
        }
    }

    private func sceneBadge(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(pixelFont(.caption2))
                .foregroundStyle(.white.opacity(0.94))
            Text(detail)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 6)
        .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
    }

    private func ollieState(for segment: NightJourneySegment) -> OllieRitualState {
        switch segment {
        case .prairie, .mountain: return .guarding
        case .moonlit: return .overnight
        case .sunrise: return .morningQuiet
        }
    }

    private func atmosphereTint(for segment: NightJourneySegment) -> Color {
        switch segment {
        case .prairie: return .white.opacity(0.01)
        case .mountain: return AppColors.lavender.opacity(0.08)
        case .moonlit: return AppColors.ink.opacity(0.16)
        case .sunrise: return AppColors.amber.opacity(0.06)
        }
    }

    private func accessibilityLabel(for journey: NightJourneyProgress, at date: Date) -> String {
        let clues = reachedClueCount(journey.overallFraction)
        return "Ollie is following the \(journey.segment.title.lowercased()). \(Int(journey.phaseFraction * 100)) percent through this part. \(clues) clues mapped. \(remainingText(journey: journey, at: date)) \(destinationText(for: journey).lowercased())."
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
        JourneyAssetImage(name: NightJourneyAssets.ollieRunFrames[frame])
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct SheepWalkCycleView: View {
    let frame: Int
    let size: CGFloat

    var body: some View {
        JourneyAssetImage(name: NightJourneyAssets.companionSheepRunFrames[frame])
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct JourneyAssetImage: View {
    let name: String
    var contentMode: ContentMode = .fit

    var body: some View {
        if let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    LinearGradient(colors: [AppColors.sky, AppColors.grass], startPoint: .top, endPoint: .bottom)
                    Image(systemName: name.hasPrefix("dog/") ? "figure.walk" : name.hasPrefix("sheep/") ? "hare.fill" : "mountain.2.fill")
                    .foregroundStyle(.white.opacity(0.8))
                }
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
        reduceMotion: true,
        mappedBonusPercentagePoints: 3
    )
    .padding()
    .background(AppColors.paper)
}
