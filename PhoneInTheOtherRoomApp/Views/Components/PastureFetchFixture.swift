#if DEBUG
import SwiftUI

/// Runs the production Farm card with disposable residents and no connected services.
struct PastureFetchNativeFixture: View {
    @MainActor static func runReview(_ scene: PastureSceneController) async {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--fetch-review") else { return }
        if args.contains("--fetch-resting") {
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
        }
        scene.fetch()
        if args.contains("--fetch-aim") {
            scene.fetchGame.updateAim(release: .init(x: 0.6, y: 0.7), predicted: .init(x: 0.8, y: 0.6))
        } else if !args.contains("--fetch-ready") {
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            scene.fetchGame.throwBall(at: .init(x: 0.2, y: 0.62))
        }
    }

    private var farm: FarmState {
        var farm = FarmState.empty
        farm.sheep = ["mabel", "bramble", "juniper"].enumerated().map { index, name in
            FlockSheep(id: UUID(uuidString: String(format: "96000000-0000-4000-8000-%012d", index + 1))!,
                      definitionID: name, displayName: name.capitalized,
                      arrivedAt: Date(timeIntervalSince1970: 1000), protectedNightNumber: 0, rarity: .common)
        }
        farm.equipment.ollieAccessoryItemID = "ollie_moss_bandana"
        return farm
    }
    private var snapshot: PastureSceneSnapshot {
        var entries = farm.activeSheep.enumerated().map { index, sheep in
            PastureSceneStoredPosition(entityID: .sheep(sheep.id, pastureIndex: 0),
                                       point: .init(x: 0.32 + Double(index) * 0.14, y: 0.65))
        }
        entries += [.init(entityID: .ollie(pastureIndex: 0), point: .init(x: 0.80, y: 0.75)),
                    .init(entityID: .shepherd(pastureIndex: 0), point: .init(x: 0.48, y: 0.79))]
        return .init(positions: entries)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Fetch with Ollie").font(AppTypography.title)
                FarmPastureView(state: farm, protectedNightCount: 0, layoutSeed: 47,
                                onSelectSheep: { _ in }, shepherdDisplayName: "Tommy", persistedScene: snapshot)
            }.padding(AppSpacing.md)
        }
        .background(AppColors.background.ignoresSafeArea())
    }
}

#Preview("Fetch · small pasture") { PastureFetchNativeFixture() }
#endif
