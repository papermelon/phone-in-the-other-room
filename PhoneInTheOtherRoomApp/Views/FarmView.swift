import SwiftUI

struct FarmView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var selectedSheepID: UUID?
    @State private var contextualTip: CountingSheepContextualTip?
    let pastureVisitSeed: UInt64
    @Binding var opensNightFlock: Bool

    init(pastureVisitSeed: UInt64, opensNightFlock: Binding<Bool> = .constant(false)) {
        self.pastureVisitSeed = pastureVisitSeed
        _opensNightFlock = opensNightFlock
    }

    var body: some View {
        FarmDashboardContent(
            state: viewModel.farmState,
            searchState: viewModel.sheepSearchState,
            protectedNightCount: viewModel.coordinator.progress.totalCompletedRuns,
            isWindDownActive: viewModel.isRunning,
            pastureVisitSeed: pastureVisitSeed,
            nightFlockSummary: viewModel.nightFlockViewModel.homeSummary,
            onOpenNightFlock: { opensNightFlock = true },
            onSelectSheep: { selectedSheepID = $0.id }
        )
        .navigationDestination(isPresented: Binding(
            get: { selectedSheepID != nil },
            set: { if !$0 { selectedSheepID = nil } }
        )) {
            if let selectedSheepID {
                BarnSheepDetailView(sheepID: selectedSheepID)
                    .environmentObject(viewModel)
            }
        }
        .navigationDestination(isPresented: $opensNightFlock) {
            NightFlockHubView(viewModel: viewModel.nightFlockViewModel)
        }
        .farmActionAlert(viewModel: viewModel)
        .onAppear {
            viewModel.markOrientation(.farmExplored)
            contextualTip = viewModel.farmState.isBarnFull || !viewModel.farmState.pendingSheep.isEmpty
                ? nil
                : viewModel.contextualTip(from: [.farm])
        }
        .contextualGuideOverlay(
            tip: $contextualTip,
            onAcknowledge: viewModel.acknowledgeContextualTip,
            onSkipAll: viewModel.disableContextualTips
        )
    }
}

struct FarmDashboardContent: View {
    let state: FarmState
    let searchState: SheepSearchState
    let protectedNightCount: Int
    let isWindDownActive: Bool
    var pastureVisitSeed: UInt64 = 0
    var nightFlockSummary: NightFlockHomeSummary? = nil
    var onOpenNightFlock: () -> Void = {}
    let onSelectSheep: (FlockSheep) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var latestOutcome: SheepSearchOutcome? { searchState.outcomes.last }
    private var readyCount: Int {
        state.activeSheep.filter {
            FarmEconomyRules.isWoolReady(for: $0, protectedNightCount: protectedNightCount)
        }.count
    }
    private var searchableCount: Int {
        let known = Set(state.discoveries.map(\.definitionID))
        return SheepCatalog.eligible(for: max(1, protectedNightCount)).filter { !known.contains($0.id) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                FarmPastureView(
                    state: state,
                    protectedNightCount: protectedNightCount,
                    layoutSeed: pastureVisitSeed,
                    onSelectSheep: onSelectSheep
                )
                .contextualGuideTarget(.farm)
                .orientationTourTarget(.farmPasture)
                priorityCard
                FarmKeepsakeDisplay(state: state)
                FarmBalanceBar(state: state, linksEnabled: true)
                    .orientationTourTarget(.farmWool)
                    .orientationTourTarget(.farmCapacity)
                if let nightFlockSummary, !isWindDownActive {
                    NightFlockHomeCard(summary: nightFlockSummary, action: onOpenNightFlock)
                }
                destinationGrid
                recentStory
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColors.paper.ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(AppCopy.Farm.eyebrow.value)
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            Text(AppCopy.Farm.title.value)
                .font(AppTypography.display(27))
                .foregroundStyle(AppColors.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(AppCopy.Farm.detail.value)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var priorityCard: some View {
        if isWindDownActive {
            priorityLabel(
                icon: "moon.stars.fill",
                eyebrow: "OLLIE IS ON THE TRAIL",
                title: "Wind Down is still moving.",
                detail: "Return to Home when you’re ready to see the live journey.",
                showsDisclosure: false
            )
        } else if let pending = state.pendingSheep.first {
            NavigationLink {
                FarmBarnView()
            } label: {
                priorityLabel(
                    icon: "door.left.hand.open",
                    eyebrow: "ARRIVAL AT THE GATE",
                    title: "\(pending.displayName) needs room in The Barn.",
                    detail: "Trade a sheep to another farm, or open a new pasture."
                )
            }
            .buttonStyle(.plain)
        } else if state.isBarnFull {
            NavigationLink {
                FarmBarnView()
            } label: {
                priorityLabel(
                    icon: "house.lodge.fill",
                    eyebrow: "THE BARN IS FULL",
                    title: "Choose what the next pasture is for.",
                    detail: "Keep collecting by expanding, or trade from the current flock."
                )
            }
            .buttonStyle(.plain)
        } else if readyCount > 0 {
            NavigationLink {
                FarmBarnView(initialFilter: .ready)
            } label: {
                priorityLabel(
                    icon: "scissors",
                    eyebrow: "WOOL READY",
                    title: "\(readyCount) sheep are ready to shear.",
                    detail: "Shear them when you want wool. Their fleece grows back over future Wind Downs."
                )
            }
            .buttonStyle(.plain)
        } else if let latestOutcome {
            NavigationLink {
                TrailNotesArchiveView()
            } label: {
                priorityLabel(
                    icon: "note.text",
                    eyebrow: "LATEST SEARCH JOURNAL ENTRY",
                    title: latestOutcome.result == .found
                        ? SheepSearchPresentation.foundHeadline(for: latestOutcome.origin)
                        : SheepSearchPresentation.trailHeadline(for: latestOutcome.origin),
                    detail: "Open Search Journal for the full note."
                )
            }
            .buttonStyle(.plain)
        } else if searchableCount > 0 {
            NavigationLink {
                TrailBoardView()
            } label: {
                priorityLabel(
                    icon: "map.fill",
                    eyebrow: "OLLIE’S SEARCH",
                    title: "Ollie’s Search is ready.",
                    detail: "Choose one missing sheep for Ollie to favour."
                )
            }
            .buttonStyle(.plain)
        } else {
            priorityLabel(
                icon: "pawprint.fill",
                eyebrow: "THE PASTURE",
                title: "The pasture is ready.",
                detail: "Finish Wind Down and Ollie may bring a missing sheep home.",
                showsDisclosure: false
            )
        }
    }

    private func priorityLabel(
        icon: String,
        eyebrow: String,
        title: String,
        detail: String,
        showsDisclosure: Bool = true
    ) -> some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 36, height: 36)
                    .background(AppColors.grass.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.sm))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(eyebrow)
                        .font(pixelFont(.caption2))
                        .foregroundStyle(AppColors.grass)
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if showsDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    @ViewBuilder
    private var destinationGrid: some View {
        let columns = destinationColumns
        Grid(horizontalSpacing: AppSpacing.sm, verticalSpacing: AppSpacing.sm) {
            if columns.count == 1 {
                GridRow { destination("The Barn", detail: "Manage flock & wool", badge: "\(state.activeSheep.count) / \(state.activeCapacity)", icon: "house.lodge.fill", tourTarget: .farmCapacity) { FarmBarnView() } }
                GridRow { destination("Ollie’s Search", detail: "Find missing sheep", badge: "\(searchableCount) available", icon: "map.fill", tourTarget: .farmSearch) { TrailBoardView() } }
                GridRow { destination("Farm Shop", detail: "Spend wool on the Farm", badge: "\(state.woolBalance) wool", icon: "storefront.fill", tourTarget: .farmShop) { FarmShopView() } }
                GridRow { destination("Search Journal", detail: "Past arrivals & clues", badge: "\(searchState.outcomes.count) entries", icon: "note.text") { TrailNotesArchiveView() } }
            } else {
                GridRow {
                    destination("The Barn", detail: "Manage flock & wool", badge: "\(state.activeSheep.count) / \(state.activeCapacity)", icon: "house.lodge.fill", tourTarget: .farmCapacity) { FarmBarnView() }
                    destination("Ollie’s Search", detail: "Find missing sheep", badge: "\(searchableCount) available", icon: "map.fill", tourTarget: .farmSearch) { TrailBoardView() }
                }
                GridRow {
                    destination("Farm Shop", detail: "Spend wool on the Farm", badge: "\(state.woolBalance) wool", icon: "storefront.fill", tourTarget: .farmShop) { FarmShopView() }
                    destination("Search Journal", detail: "Past arrivals & clues", badge: "\(searchState.outcomes.count) entries", icon: "note.text") { TrailNotesArchiveView() }
                }
            }
        }
    }

    private var destinationColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private func destination<Destination: View>(
        _ title: String,
        detail: String,
        badge: String,
        icon: String,
        tourTarget: OrientationTourTarget? = nil,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            destinationLabel(title, detail: detail, badge: badge, icon: icon)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail). \(badge)")
        .modifier(OptionalOrientationTarget(target: tourTarget))
    }

    private func destinationLabel(
        _ title: String,
        detail: String,
        badge: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.grass)
                Spacer(minLength: 0)
                Text(badge)
                    .font(pixelFont(.caption2))
                    .foregroundStyle(AppColors.grass)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.grass)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(AppSpacing.md)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.stroke.opacity(0.2), lineWidth: 1)
        }
    }

    private var recentStory: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("RECENT EVENTS")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                if let transaction = state.transactions.last {
                    Text(storyTitle(for: transaction))
                        .font(AppTypography.headline)
                    Text(storyDetail(for: transaction))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                } else if let sheep = state.sheep.max(by: { $0.arrivedAt < $1.arrivedAt }) {
                    Text(fallbackStoryTitle(for: sheep))
                        .font(AppTypography.headline)
                    Text(fallbackStoryDetail(for: sheep))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                } else {
                    Text("Ollie is watching the empty gate.")
                        .font(AppTypography.headline)
                    Text("The first completed Wind Down will start the Farm story.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fallbackStoryTitle(for sheep: FlockSheep) -> String {
        switch sheep.status {
        case .active: return sheep.displayName + " is settling into the flock."
        case .pending: return sheep.displayName + " is waiting at The Barn gate."
        case .sold: return sheep.displayName + " set off for another pasture."
        }
    }

    private func fallbackStoryDetail(for sheep: FlockSheep) -> String {
        switch sheep.status {
        case .active: return "Ollie has made room for this homecoming."
        case .pending: return "Make room in The Barn to welcome this sheep home."
        case .sold: return "The discovery remains safe in Search Journal."
        }
    }

    private func storyTitle(for transaction: FarmTransaction) -> String {
        switch transaction.kind {
        case .arrival:
            if let sheepID = transaction.sheepID,
               let sheep = state.sheep.first(where: { $0.id == sheepID }) {
                return "\(sheep.displayName) came home."
            }
            return "A sheep came through the gate."
        case .shearing: return "Fresh wool reached the store room."
        case .sale: return "A sheep set off for another pasture."
        case .purchase: return "Something new arrived from the Farm Shop."
        case .capacityUpgrade: return "The Barn opened another pasture."
        case .currencyConsolidation: return "The Farm now keeps one wool balance."
        case .starterGrant: return "Ollie left a welcome gift in the pasture."
        case .welcomeGift: return "A welcome gift is waiting to be tried on."
        case .onboardingPracticeArrival: return "Practice brought a welcome gift home."
        }
    }

    private func storyDetail(for transaction: FarmTransaction) -> String {
        if transaction.kind == .currencyConsolidation {
            return "\(transaction.woolDelta) wool carried over from your earlier Farm balance."
        }
        if let sheepID = transaction.sheepID,
           let sheep = state.sheep.first(where: { $0.id == sheepID }) {
            return sheep.displayName + " · " + transaction.createdAt.formatted(date: .abbreviated, time: .omitted)
        }
        if let itemID = transaction.itemID, let item = FarmShopCatalog.item(for: itemID) {
            return item.title + " · " + transaction.createdAt.formatted(date: .abbreviated, time: .omitted)
        }
        return transaction.createdAt.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview("Farm · empty · Slumber Party disabled") {
    NavigationStack {
        FarmDashboardContent(
            state: .empty,
            searchState: .empty,
            protectedNightCount: 0,
            isWindDownActive: false,
            onSelectSheep: { _ in }
        )
    }
}

#Preview("Farm · active search") {
    NavigationStack {
        FarmDashboardContent(
            state: .empty,
            searchState: FarmPreviewData.activeSearchState,
            protectedNightCount: 3,
            isWindDownActive: false,
            onSelectSheep: { _ in }
        )
    }
}

#Preview("Farm · wool ready") {
    NavigationStack {
        FarmDashboardContent(
            state: FarmPreviewData.oneSheepState,
            searchState: FarmPreviewData.searchState,
            protectedNightCount: 18,
            isWindDownActive: false,
            onSelectSheep: { _ in }
        )
    }
}

#Preview("Farm · Slumber Party invitation") {
    NavigationStack {
        FarmDashboardContent(
            state: FarmPreviewData.fullState,
            searchState: FarmPreviewData.searchState,
            protectedNightCount: 18,
            isWindDownActive: false,
            nightFlockSummary: .invitation,
            onSelectSheep: { _ in }
        )
    }
}

#Preview("Farm · Slumber Party active") {
    NavigationStack {
        FarmDashboardContent(
            state: FarmPreviewData.fullState,
            searchState: FarmPreviewData.searchState,
            protectedNightCount: 18,
            isWindDownActive: false,
            nightFlockSummary: NightFlockHomeSummary(
                title: "Someone in the flock has tucked in.",
                detail: "Only shared tuck-ins appear here.",
                challengeDay: 3
            ),
            onSelectSheep: { _ in }
        )
    }
}

#Preview("Farm · accessibility Dynamic Type") {
    NavigationStack {
        FarmDashboardContent(
            state: FarmPreviewData.fullState,
            searchState: FarmPreviewData.searchState,
            protectedNightCount: 18,
            isWindDownActive: false,
            onSelectSheep: { _ in }
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Farm · one sheep") {
    NavigationStack {
        FarmDashboardContent(
            state: FarmPreviewData.oneSheepState,
            searchState: FarmPreviewData.searchState,
            protectedNightCount: 1,
            isWindDownActive: false,
            onSelectSheep: { _ in }
        )
    }
}

#Preview("Farm · sixty sheep") {
    NavigationStack {
        FarmDashboardContent(
            state: FarmPreviewData.sixtySheepState,
            searchState: FarmPreviewData.searchState,
            protectedNightCount: 60,
            isWindDownActive: false,
            onSelectSheep: { _ in }
        )
    }
}
