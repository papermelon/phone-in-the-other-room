import SwiftUI

struct CampfireProfileView: View {
    @ObservedObject var social: NightFlockViewModel
    var participantID: UUID? = nil
    var memberID: UUID? = nil
    @State private var snapshot: CampfireProfileSnapshot?
    @State private var message: String?
    @State private var loading = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if loading { SheepLoadingView("Opening profile…") }
            if let snapshot {
                CampfireProfileContents(snapshot: snapshot)
            } else if let message {
                Text(message).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                Button("Try again") { Task { await refresh() } }.frame(minHeight: 44)
            }
        }
        .task(id: social.pastureOwner) {
            snapshot = nil
            repeat {
                await refresh()
                do { try await Task.sleep(for: .seconds(20)) } catch { return }
            } while !Task.isCancelled
        }
        .onChange(of: social.campfireDocument.commands) { _, commands in
            if commands.contains(where: { $0.command == "block" }) { snapshot = nil }
        }
    }

    @MainActor private func refresh() async {
        guard let service = social.service, let owner = social.pastureOwner, social.permitsNightFlockNetwork else {
            snapshot = nil; loading = false; message = "This profile isn’t available right now."; return
        }
        do {
            let result = try await service.campfireProfile(participantID: participantID, memberID: memberID)
            guard !Task.isCancelled, owner == social.pastureOwner, social.permitsNightFlockNetwork else { return }
            snapshot = result.profile
            message = result.profile == nil ? "This profile isn’t available right now." : nil
        } catch {
            guard !Task.isCancelled, owner == social.pastureOwner else { return }
            snapshot = nil; message = "The profile couldn’t be refreshed."
        }
        loading = false
    }
}

struct CampfireProfileContents: View {
    let snapshot: CampfireProfileSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if !snapshot.intention.isEmpty { section("Intention", [snapshot.intention]) }
            if !snapshot.tasks.isEmpty { section("Tasks", snapshot.tasks) }
            if !snapshot.routines.isEmpty { section("Wind Down routines", snapshot.routines) }
            DisclosureGroup {
                section("Current session", snapshot.session)
                if !snapshot.partyNames.isEmpty { section("Slumber Parties", snapshot.partyNames) }
            } label: { Text("Session details").frame(minHeight: 44) }
            DisclosureGroup {
                FarmPastureView(state: snapshot.farm, protectedNightCount: 0, layoutSeed: 1, onSelectSheep: { _ in }, isReadOnly: true)
                section("Farm inventory", snapshot.inventory.map { FarmShopCatalog.item(for: $0)?.title ?? $0 })
                section("Sheep", snapshot.sheep.map { "\($0.name) · \($0.status)" })
            } label: { Text("Farm & sheep").frame(minHeight: 44) }
            DisclosureGroup {
                section("Recorded history", snapshot.history)
            } label: { Text("Recorded history").frame(minHeight: 44) }
        }.font(AppTypography.body).tint(AppColors.grass)
    }
    private func section(_ title: String, _ values: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title).font(AppTypography.headline)
            if values.isEmpty { Text("Nothing here yet").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText) }
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in Text(value).font(AppTypography.body) }
        }
    }
}

#Preview("Campfire profile · empty Farm") {
    ScrollView {
        CampfireProfileContents(snapshot: .init(session: ["Phone Away · Active"], tasks: ["Read a chapter"], routines: [], intention: "A quieter evening",
            history: [], partyNames: [], inventory: [], sheep: [], appearance: .init(),
            decorations: [:], collectibles: [:], ollieAccessory: "none", barnCapacityLevel: 0)).padding()
    }.background(AppColors.paper)
}
