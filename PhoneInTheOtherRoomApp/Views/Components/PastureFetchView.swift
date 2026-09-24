import SwiftUI

struct PastureFetchOverlay: View {
    let game: PastureFetchViewModel
    let size: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @GestureState private var isDragging = false

    var body: some View {
        ZStack {
            Group {
                if let aim = game.aim {
                    Path { path in
                        path.move(to: screen(game.origin))
                        path.addQuadCurve(to: screen(aim), control: CGPoint(
                            x: size.width * (game.origin.x + aim.x) / 2,
                            y: size.height * (min(game.origin.y, aim.y) - (reduceMotion ? 0 : 0.2))))
                    }
                    .stroke(AppColors.ink.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                    Circle().stroke(AppColors.ink, lineWidth: 2).frame(width: 24, height: 12)
                        .position(screen(aim))
                }
                let sample = game.frame
                let ball = game.isReady ? game.origin : sample?.ball ?? game.origin
                let lift = game.isReady ? 0 : sample?.lift ?? 0
                let mouth = mouthOffset
                Ellipse().fill(AppColors.bark.opacity(0.28)).frame(width: 13, height: 5)
                    .position(x: size.width * ball.x, y: size.height * ball.y + 31)
                Image(systemName: "tennisball.fill")
                    .resizable().scaledToFit().foregroundStyle(AppColors.amber)
                    .frame(width: game.isReady ? 24 : 12, height: game.isReady ? 24 : 12)
                    .rotationEffect(.degrees(reduceMotion || game.isReady ? 0 : game.elapsed * 240))
                    .position(x: size.width * ball.x + mouth.width,
                              y: size.height * (ball.y - lift) + mouth.height)
            }
            .allowsHitTesting(false)
            if game.isReady {
                // Only the ball captures touches; the rest of the pasture can still scroll.
                Color.clear
                    .frame(width: 64, height: 64)
                    .contentShape(Circle())
                    .position(screen(game.origin))
                    .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("fetch-field"))
                        .updating($isDragging) { _, dragging, _ in dragging = true }
                        .onChanged { value in
                            game.updateAim(translation: translation(value.translation),
                                           predictedTranslation: translation(value.predictedEndTranslation))
                        }
                        .onEnded { value in
                            game.flickBall(translation: translation(value.translation),
                                           predictedTranslation: translation(value.predictedEndTranslation))
                        })
            }
        }
        .frame(width: size.width, height: size.height)
        .coordinateSpace(name: "fetch-field")
        .onChange(of: isDragging) { _, dragging in
            if !dragging { game.cancelAim() }
        }
        .accessibilityHidden(true)
    }

    // The ball rises into the muzzle at pickup and lowers into the player's court on delivery.
    private var mouthOffset: CGSize {
        guard !game.isReady, let frame = game.frame else { return CGSize(width: 0, height: 28) }
        return CGSize(width: (frame.facesLeft ? -30 : 30) * frame.carryFraction,
                      height: 28 - 25 * frame.carryFraction)
    }

    private func translation(_ value: CGSize) -> PastureScenePoint {
        .init(x: value.width / max(1, size.width), y: value.height / max(1, size.height))
    }
    private func screen(_ value: PastureScenePoint) -> CGPoint {
        .init(x: value.x * size.width, y: value.y * size.height + 28)
    }
}

struct PastureFetchActions: View {
    let game: PastureFetchViewModel
    let onDone: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(game.message).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("fetch-status")
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xs) { done; throwMenu }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack { throwMenu; Spacer(); done }.fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: AppSpacing.xs) { done; throwMenu }
                }
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.bordered)
        .tint(AppColors.grass)
        .background(AppColors.paper, in: RoundedRectangle(cornerRadius: AppRadius.md))
        .onChange(of: game.isReady) { _, ready in
            if ready, UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement, argument: game.message)
            }
        }
    }

    private var throwMenu: some View {
        Menu {
            Button("Far left") { game.throwBall(at: PastureFetchRound.targetMinimum) }
            Button("Far right") { game.throwBall(at: .init(x: 0.96, y: 0.36)) }
            Button("Near left") { game.throwBall(at: .init(x: 0.04, y: 0.86)) }
            Button("Near right") { game.throwBall(at: PastureFetchRound.targetMaximum) }
            Button("Throw ahead") { game.throwBall(at: .init(x: 0.50, y: 0.5)) }
        } label: {
            Label("Throw options", systemImage: "tennisball")
                .font(AppTypography.caption).fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
        }
        .disabled(!game.isReady)
        .accessibilityHint("Choose a direction without swiping the ball")
    }

    private var done: some View {
        Button(action: onDone) {
            Text("Done playing").font(AppTypography.caption)
                .fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
        }
    }
}

struct PastureFetchOllie: View {
    let game: PastureFetchViewModel
    let accessoryItemID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let running = !game.isReady && game.wakeAssetName == nil
        let frames = NightJourneyAssets.ollieRunFrames
        let index = reduceMotion || game.frame?.isRunning != true ? 0 : Int(game.elapsed / 0.1) % frames.count
        let asset = game.wakeAssetName ?? (running ? frames[index] : NightJourneyAssets.ollieHomeIdleFrames[0])
        OllieDressedSprite(assetName: asset, accessoryItemID: accessoryItemID)
            .frame(width: 72, height: 72)
            .scaleEffect(x: game.frame?.facesLeft == true ? -1 : 1, y: 1)
            .offset(y: running ? 68 - 72 * NightJourneyAssets.ollieRunGroundAnchors[index] : 0)
    }
}

#Preview("Fetch · accessible controls") {
    PastureFetchActions(game: PastureFetchViewModel(), onDone: {})
        .environment(\.dynamicTypeSize, .accessibility3)
}
