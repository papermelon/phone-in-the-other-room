import SwiftUI
import Observation

@MainActor @Observable
final class CampfireSeatingController: PastureInteractionControlling {
    var seating = CampfireSeating()
    private var drag: (id: UUID, origin: PastureScenePoint, point: PastureScenePoint)?
    private var suppressedTapUntil = Date.distantPast

    func position(_ id: UUID) -> PastureScenePoint {
        if let drag, drag.id == id { return drag.point }
        return seating.position(id)
    }
    func behavior(for entity: UUID) -> PastureSceneBehavior { drag?.id == entity ? .dragging : .idle }
    func beginDrag(_ entity: UUID) {
        guard seating.slots[entity] != nil, drag == nil else { return }
        let point = seating.position(entity)
        drag = (entity, point, point)
    }
    func updateDrag(_ entity: UUID, translation: PastureScenePoint) {
        guard var value = drag, value.id == entity, translation.x.isFinite, translation.y.isFinite else { return }
        value.point = .init(x: min(0.85, max(0.15, value.origin.x + translation.x)),
                            y: min(0.91, max(0.15, value.origin.y + translation.y)))
        drag = value
    }
    func finishDrag(_ entity: UUID) {
        guard let drag, drag.id == entity else { return }
        seating.move(entity, to: drag.point)
        self.drag = nil
        suppressedTapUntil = Date().addingTimeInterval(0.3)
    }
    func cancelInteraction() { drag = nil }
    func shouldAcceptTap(for entity: UUID) -> Bool { drag == nil && Date() >= suppressedTapUntil }
}

struct CampfireSceneView: View {
    var people: [CampfireScenePerson]
    var notice: String? = nil
    var detail: String? = nil
    var isUpdating = false
    var retry: (() -> Void)? = nil
    var onSelect: (UUID) -> Void
    @State private var controller = CampfireSeatingController()
    @ScaledMetric(relativeTo: .body) private var statusClearance = CampfireSceneLayout.statusClearance
    private var extraClearance: CGFloat { max(0, statusClearance - CampfireSceneLayout.statusClearance) }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var ids: [UUID] { people.prefix(8).map(\.placementID) }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ZStack(alignment: .top) {
                Color.clear.frame(height: CampfireSceneLayout.height + extraClearance).allowsHitTesting(false).accessibilityHidden(true)
                if let notice {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        if isUpdating { SheepLoadingView(notice) }
                        else { Text(notice).font(AppTypography.headline) }
                        if let detail {
                            Text(detail).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        }
                        if let retry {
                            Button(action: retry) {
                                Text("Try again").frame(minHeight: 44)
                            }.font(AppTypography.body).tint(AppColors.grass)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.sm)
                    .background(AppColors.paper.opacity(0.96), in: RoundedRectangle(cornerRadius: AppRadius.md))
                    .padding(AppSpacing.sm)
                    .accessibilityElement(children: .contain)
                }
            }
            .background {
                GeometryReader { geometry in
                    ZStack {
                        Image(AssetSlot.Farm.sharedMeadowDusk).resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                            .scaleEffect(1.35, anchor: .bottom).accessibilityHidden(true)
                        PaperCampfire(animated: true).frame(width: CampfireSceneLayout.fireSize, height: CampfireSceneLayout.fireSize)
                            .position(x: geometry.size.width * 0.5, y: extraClearance + CampfireSceneLayout.height * CampfireSceneLayout.fireY)
                            .accessibilityHidden(true)
                        ForEach(Array(people.prefix(8))) { person in
                            let point = controller.position(person.placementID)
                            let width = min(CampfireSceneLayout.bubbleMaxWidth, geometry.size.width * CampfireSceneLayout.bubbleWidthFraction)
                            PastureCharacterHitTarget(entity: person.placementID, controller: controller,
                                canvasSize: CGSize(width: geometry.size.width, height: CampfireSceneLayout.height), coordinateSpace: "campfire-seats", reduceMotion: reduceMotion,
                                label: "\(person.name), \(CampfirePlanText.normalized(person.thought) ?? person.detail), \(person.pose.accessibilityDescription)\(person.buddyCue.map { ", \($0)" } ?? "")",
                                hint: "Tap for their tasks, routines, history and Farm. Hold and drag to choose a seat on this device.",
                                actionTitle: "Open session", accessibleStep: 0.3, action: { onSelect(person.id) }) {
                                    VStack(spacing: AppSpacing.xxs) {
                                        CampfirePlanBubble(thought: person.thought, activity: person.detail)
                                        CampfireShepherdView(presentation: person.appearance, pose: person.pose,
                                            size: CampfireSceneLayout.shepherdSize, seated: true,
                                            facesLeft: controller.seating.position(person.placementID).x > 0.5)
                                            .overlay(alignment: .topTrailing) {
                                                if person.buddyCue != nil {
                                                    Image(systemName: "person.2.fill").font(AppTypography.caption)
                                                        .dynamicTypeSize(...DynamicTypeSize.large)
                                                        .foregroundStyle(AppColors.grass).padding(2)
                                                        .background(AppColors.paper, in: Circle())
                                                }
                                            }
                                        Text(person.name).font(AppTypography.caption).dynamicTypeSize(...DynamicTypeSize.large)
                                            .lineLimit(1).padding(.horizontal, AppSpacing.xxs)
                                            .background(AppColors.paper.opacity(0.94), in: Capsule())
                                    }.frame(width: width).accessibilityHidden(true)
                                }
                                .position(x: geometry.size.width * point.x, y: extraClearance + CampfireSceneLayout.height * point.y)
                                .zIndex(point.y)
                        }
                    }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        .coordinateSpace(name: "campfire-seats")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Text(people.isEmpty ? "Your visibility stays the same." : "Tap a Shepherd to look around · hold and drag to move a seat")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !people.isEmpty {
                    Menu {
                        Button("Reset seats") {
                            controller.cancelInteraction()
                            controller.seating = CampfireSeating()
                            controller.seating.reconcile(ids)
                        }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44)
                    }.tint(AppColors.grass).accessibilityLabel("Seating options")
                }
            }

        }
        .onAppear { controller.seating.reconcile(ids) }
        .onChange(of: ids) { _, value in
            controller.cancelInteraction()
            controller.seating.reconcile(value)
        }
    }
}

/// Fit the complete plan or offer a deliberate full-text destination; never ellipsize it.
private struct CampfirePlanBubble: View {
    let thought: String?
    let activity: String

    var body: some View {
        ViewThatFits(in: .vertical) {
            bubble {
                Text(CampfirePlanText.normalized(thought) ?? activity)
                    .fixedSize(horizontal: false, vertical: true)
            }
            bubble {
                VStack(spacing: AppSpacing.xxs) {
                    Text(activity).fixedSize(horizontal: false, vertical: true)
                    Text("View plan").foregroundStyle(AppColors.grass)
                }
            }
        }
        .font(AppTypography.caption).dynamicTypeSize(...DynamicTypeSize.large)
        .multilineTextAlignment(.center)
        .frame(height: CampfireSceneLayout.bubbleTextHeight + AppSpacing.xxs * 2, alignment: .bottom)
    }

    private func bubble<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().frame(maxWidth: .infinity)
            .padding(AppSpacing.xxs)
            .background(AppColors.paper, in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }
}
