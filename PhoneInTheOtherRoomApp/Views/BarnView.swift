import SwiftUI

enum BarnFilter: String, CaseIterable, Identifiable {
    case all, favorites, ready, regrowing, common, uncommon, rare, legendary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All sheep"
        case .favorites: return "Favourites"
        case .ready: return "Ready to shear"
        case .regrowing: return "Regrowing"
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .legendary: return "Legendary"
        }
    }
}

struct FarmBarnView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var filter: BarnFilter
    @State private var contextualTip: CountingSheepContextualTip?

    init(initialFilter: BarnFilter = .all) {
        _filter = State(initialValue: initialFilter)
    }

    private var state: FarmState { viewModel.farmState }
    private var protectedNights: Int { viewModel.coordinator.progress.totalCompletedRuns }

    private var filteredSheep: [FlockSheep] {
        state.activeSheep.filter { sheep in
            switch filter {
            case .all: return true
            case .favorites: return sheep.isFavorite
            case .ready:
                return FarmEconomyRules.isWoolReady(for: sheep, protectedNightCount: protectedNights)
            case .regrowing:
                return !FarmEconomyRules.isWoolReady(for: sheep, protectedNightCount: protectedNights)
            case .common: return sheep.rarity == .common
            case .uncommon: return sheep.rarity == .uncommon
            case .rare: return sheep.rarity == .rare
            case .legendary: return sheep.rarity == .legendary
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                capacityCard
                    .contextualGuideTarget(.barnCapacity)
                if !state.pendingSheep.isEmpty { pendingSection }
                flockSection
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("The Barn")
        .navigationBarTitleDisplayMode(.inline)
        .farmActionAlert(viewModel: viewModel)
        .onAppear {
            guard state.isBarnFull || !state.pendingSheep.isEmpty else { return }
            contextualTip = viewModel.contextualTip(from: [.barnCapacity])
        }
        .contextualGuideOverlay(
            tip: $contextualTip,
            onAcknowledge: viewModel.acknowledgeContextualTip,
            onSkipAll: viewModel.disableContextualTips
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("THE BARN")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            Text("Manage your flock, wool, and pasture space.")
                .font(AppTypography.title)
                .fixedSize(horizontal: false, vertical: true)
            FarmBalanceBar(state: state)
        }
    }

    private var capacityCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("PASTURE SPACE")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Spacer()
                    Text("\(state.activeSheep.count) / \(state.activeCapacity)")
                        .font(PixelTypography.mono(.headline))
                }
                ProgressView(value: Double(state.activeSheep.count), total: Double(state.activeCapacity))
                    .tint(AppColors.grass)
                if state.barnCapacityLevel < FarmEconomyRules.maximumCapacityLevel {
                    NavigationLink {
                        FarmShopView(initialCategory: .barn)
                    } label: {
                        Label("Expand The Barn", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else {
                    Text("All four expansions are open. The Farm can hold 60 active sheep.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("WAITING AT THE GATE")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.amber)
            ForEach(state.pendingSheep) { sheep in
                NavigationLink {
                    BarnSheepDetailView(sheepID: sheep.id)
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        FarmSheepSprite(sheep: sheep, protectedNightCount: protectedNights, size: 62)
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(sheep.displayName).font(AppTypography.headline)
                            Text("Make room to welcome this sheep.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(AppColors.muted)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.md))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var flockSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("ACTIVE FLOCK")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Spacer()
                Picker("The Barn filter", selection: $filter) {
                    ForEach(BarnFilter.allCases) { option in Text(option.title).tag(option) }
                }
                .pickerStyle(.menu)
                .tint(AppColors.grass)
            }

            if filteredSheep.isEmpty {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Image(systemName: "house.lodge.fill")
                            .font(.title2)
                            .foregroundStyle(AppColors.grass)
                        Text(state.activeSheep.isEmpty ? "The Barn is ready." : "No sheep match this view.")
                            .font(AppTypography.headline)
                        Text(state.activeSheep.isEmpty
                            ? "Ollie’s first homecoming will settle here."
                            : "Choose another view of the flock.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 138, maximum: 190), spacing: AppSpacing.sm)],
                    spacing: AppSpacing.sm
                ) {
                    ForEach(filteredSheep) { sheep in
                        NavigationLink {
                            BarnSheepDetailView(sheepID: sheep.id)
                        } label: {
                            BarnSheepCard(sheep: sheep, protectedNightCount: protectedNights)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct BarnSheepCard: View {
    let sheep: FlockSheep
    let protectedNightCount: Int

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            FarmSheepSprite(sheep: sheep, protectedNightCount: protectedNightCount, size: 92)
            HStack(spacing: AppSpacing.xxs) {
                Text(sheep.displayName)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                if sheep.isFavorite {
                    Image(systemName: "heart.fill").foregroundStyle(AppColors.berry)
                }
            }
            Text(woolLabel)
                .font(AppTypography.caption)
                .foregroundStyle(woolReady ? AppColors.grass : AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 154)
        .padding(AppSpacing.sm)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.stroke.opacity(0.2), lineWidth: 1)
        }
    }

    private var woolReady: Bool {
        FarmEconomyRules.isWoolReady(for: sheep, protectedNightCount: protectedNightCount)
    }

    private var woolLabel: String {
        let remaining = FarmEconomyRules.remainingRegrowthNights(
            for: sheep,
            protectedNightCount: protectedNightCount
        )
        return woolReady ? "Ready to shear" : "Ready after \(remaining) more \(remaining == 1 ? "night" : "nights")"
    }
}

struct BarnSheepDetailView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let sheepID: UUID
    @State private var showTradeConfirmation = false

    private var sheep: FlockSheep? { viewModel.farmState.sheep.first { $0.id == sheepID } }
    private var protectedNights: Int { viewModel.coordinator.progress.totalCompletedRuns }

    var body: some View {
        ScrollView {
            if let sheep {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    sheepHeader(sheep)
                    lifecycleCard(sheep)
                    actionCard(sheep)
                }
                .padding(AppSpacing.md)
                .padding(.bottom, AppSpacing.xxl)
            } else {
                Text("This sheep is no longer in The Barn.")
                    .font(AppTypography.body)
                    .padding(AppSpacing.lg)
            }
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle(sheep?.displayName ?? "The Barn")
        .navigationBarTitleDisplayMode(.inline)
        .farmActionAlert(viewModel: viewModel)
        .alert(tradeTitle, isPresented: $showTradeConfirmation) {
            Button("Keep in The Barn", role: .cancel) {}
            Button("Trade for \(tradeValue) wool", role: .destructive) {
                viewModel.tradeFarmSheep(sheepID)
            }
        } message: {
            Text("This sheep will move to another farm. Its discovery and Search Journal history will stay recorded.")
        }
    }

    private func sheepHeader(_ sheep: FlockSheep) -> some View {
        PixelCard {
            VStack(spacing: AppSpacing.sm) {
                FarmSheepSprite(sheep: sheep, protectedNightCount: protectedNights, size: 176)
                Text(sheep.displayName)
                    .font(AppTypography.display(32))
                Text("\(sheep.rarity.title) · \(definition(for: sheep)?.breed.title ?? "Sheep")")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                if let story = definition(for: sheep)?.story {
                    Text(story)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                if sheep.status == .active {
                    Button {
                        viewModel.toggleFarmSheepFavorite(sheep.id)
                    } label: {
                        Label(sheep.isFavorite ? "Favourite sheep" : "Mark as favourite", systemImage: sheep.isFavorite ? "heart.fill" : "heart")
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: sheep.isFavorite))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func lifecycleCard(_ sheep: FlockSheep) -> some View {
        let remaining = FarmEconomyRules.remainingRegrowthNights(for: sheep, protectedNightCount: protectedNights)
        return PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("FLOCK LIFE")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                detail("Arrived", sheep.arrivedAt.formatted(date: .abbreviated, time: .omitted))
                detail("How they arrived", arrivalLabel(for: sheep))
                detail("Times sheared", "\(sheep.timesSheared)")
                detail("Wool", remaining == 0 ? "Ready to shear" : "Ready after \(remaining) more \(remaining == 1 ? "Wind Down" : "Wind Downs")")
                detail("Trade value now", "\(FarmEconomyRules.tradeWoolValue(for: sheep, protectedNightCount: protectedNights)) wool")
            }
        }
    }

    private func actionCard(_ sheep: FlockSheep) -> some View {
        PixelCard {
            VStack(spacing: AppSpacing.sm) {
                if sheep.status == .active {
                    if FarmEconomyRules.isWoolReady(for: sheep, protectedNightCount: protectedNights) {
                        Button {
                            viewModel.shearFarmSheep(sheep.id)
                        } label: {
                            Label("Shear for \(FarmEconomyRules.woolYield(for: sheep.rarity)) wool", systemImage: "scissors")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PixelPrimaryButtonStyle())
                    } else {
                        let remaining = FarmEconomyRules.remainingRegrowthNights(
                            for: sheep,
                            protectedNightCount: protectedNights
                        )
                        Label(
                            "Wool ready after \(remaining) more \(remaining == 1 ? "Wind Down" : "Wind Downs")",
                            systemImage: "leaf.fill"
                        )
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.sm)
                        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                } else if sheep.status == .pending {
                    Button {
                        viewModel.welcomePendingFarmSheep(sheep.id)
                    } label: {
                        Label("Welcome into The Barn", systemImage: "door.left.hand.open")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .disabled(viewModel.farmState.isBarnFull)
                }

                if sheep.status != .sold {
                    Button(role: .destructive) {
                        showTradeConfirmation = true
                    } label: {
                        Label("Trade for \(tradeValue) wool", systemImage: "arrow.left.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else {
                    Text("\(sheep.displayName) has moved to another pasture. The discovery remains in Search Journal.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            Spacer()
            Text(value).font(AppTypography.caption.weight(.bold)).multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func definition(for sheep: FlockSheep) -> SheepDefinition? {
        SheepCatalog.definition(for: sheep.definitionID)
    }

    private func arrivalLabel(for sheep: FlockSheep) -> String {
        let origin = viewModel.sheepSearchState.outcomes.first { $0.id == sheep.sourceOutcomeID }?.origin
            ?? (sheep.protectedNightNumber == 0 ? .starter : .windDown)
        return SheepSearchPresentation.barnArrivalLabel(for: origin)
    }

    private var tradeValue: Int {
        guard let sheep else { return 0 }
        return FarmEconomyRules.tradeWoolValue(for: sheep, protectedNightCount: protectedNights)
    }

    private var tradeTitle: String {
        guard let sheep else { return "Trade this sheep?" }
        return sheep.isFavorite ? "Trade favourite \(sheep.displayName)?" : "Trade \(sheep.displayName)?"
    }
}
