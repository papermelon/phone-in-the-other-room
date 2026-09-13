import SwiftUI

struct PaperCampfire: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 100, size.height / 100)
            context.scaleBy(x: scale, y: scale)
            context.fill(Path(ellipseIn: CGRect(x: 4, y: 65, width: 92, height: 29)), with: .color(AppColors.amber.opacity(0.14)))
            for (x, y, angle) in [(25.0, 76.0, -0.3), (27.0, 70.0, 0.3)] {
                var log = context
                log.translateBy(x: x, y: y); log.rotate(by: .radians(angle))
                log.fill(Path(roundedRect: CGRect(x: 0, y: 0, width: 52, height: 12), cornerRadius: 5), with: .color(ShepherdStudyPalette.boots))
                log.stroke(Path(CGRect(x: 5, y: 4, width: 42, height: 1)), with: .color(ShepherdStudyPalette.hatBand), lineWidth: 1)
            }
            var flame = Path()
            flame.move(to: CGPoint(x: 49, y: 78))
            flame.addCurve(to: CGPoint(x: 42, y: 14), control1: CGPoint(x: 8, y: 66), control2: CGPoint(x: 47, y: 39))
            flame.addCurve(to: CGPoint(x: 65, y: 48), control1: CGPoint(x: 68, y: 26), control2: CGPoint(x: 49, y: 42))
            flame.addQuadCurve(to: CGPoint(x: 70, y: 36), control: CGPoint(x: 70, y: 43))
            flame.addCurve(to: CGPoint(x: 49, y: 78), control1: CGPoint(x: 87, y: 66), control2: CGPoint(x: 72, y: 79))
            context.fill(flame, with: .color(ShepherdStudyPalette.hatBand))
            var core = Path()
            core.move(to: CGPoint(x: 49, y: 77))
            core.addQuadCurve(to: CGPoint(x: 53, y: 44), control: CGPoint(x: 32, y: 67))
            core.addQuadCurve(to: CGPoint(x: 49, y: 77), control: CGPoint(x: 72, y: 70))
            context.fill(core, with: .color(ShepherdStudyPalette.cream))
            var texture = context
            texture.clip(to: flame)
            for i in 0..<170 {
                let x = Double((i * 47) % 87), y = Double((i * 31) % 89)
                texture.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.3, height: 1.8)),
                             with: .color(ShepherdStudyPalette.masterPaper.opacity(0.14)))
            }
        }.accessibilityHidden(true)
    }
}

struct CampfireSharingSheet: View {
    @ObservedObject var social: NightFlockViewModel
    let partyID: UUID
    @Environment(\.dismiss) private var dismiss
    private var state: CampfireState? { social.v4ObservedPartyDetail(for: partyID)?.pasture?.campfire }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    PaperCampfire().frame(width: 110, height: 110).frame(maxWidth: .infinity)
                    Text("A little company, phone away").font(AppTypography.title)
                    Text("The campfire is here from your first day. Your Shepherd wears your chosen outfit here. Sheep visits and the earned lantern keep their own place in the meadow.").font(AppTypography.body)
                    if state?.isSupported == true {
                        Text("CAMPFIRE SHARING · VERSION 1").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                        Text("When you enable sharing with this party, new Wind Down and Phone Away sessions bring your Shepherd to the fire. Members can see the session type, start and planned end, and an optional Phone Away intention.").font(AppTypography.body)
                        Text("Wind Down stays until the planned wake time. A private Wind Down stays private. Custom task titles aren’t shared. Joining another party needs its own choice.").font(AppTypography.body)
                        Text("These are app-reported sessions, not proof of sleep or offline activity. You can close the app. If an early end can’t sync, the last shared session may remain until its planned end.").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        if state?.agreement?.permitsSharing == true {
                            Text("Sharing is enabled for new sessions.").font(AppTypography.body)
                            Button("Turn off campfire sharing") { social.setCampfireSharing(false, partyID: partyID) }
                                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        } else {
                            Button("Enable sharing with this party") { social.setCampfireSharing(true, partyID: partyID) }
                                .buttonStyle(PixelPrimaryButtonStyle())
                        }
                        Text("Turning this off removes your campfire presence when the change syncs. Your timer and other agreed Slumber Party sharing continue.").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        SharedPastureSaveFeedback(social: social, partyID: partyID)
                    } else {
                        Text("Live campfire sharing isn’t available on this server yet. The meadow and shared updates are still here.").font(AppTypography.body)
                    }
                }.padding(AppSpacing.md)
            }.background(AppColors.paper.ignoresSafeArea())
                .navigationTitle("Campfire").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

#Preview("Campfire · paper illustration") { PaperCampfire().frame(width: 180, height: 180).padding().background(AppColors.paper) }
#Preview("Campfire · server unavailable") { CampfireSharingSheet(social: NightFlockViewModel(featureEnabled: false), partyID: UUID()) }
