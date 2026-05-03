import Foundation

@MainActor
final class RewardShelfViewModel: ObservableObject {
    @Published var rewards: [RewardItem] = PersistenceService.shared.rewards
}

