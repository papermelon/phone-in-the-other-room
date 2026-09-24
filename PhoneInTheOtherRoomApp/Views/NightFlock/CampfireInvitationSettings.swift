import SwiftUI

struct CampfireInvitationSettings: View {
    @ObservedObject var social: NightFlockViewModel
    let partyID: UUID
    @State private var quietStart = 23
    @State private var quietEnd = 7
    private var enabled: Bool { social.v4ObservedPartyDetail(for: partyID)?.pasture?.campfire?.buddies?.startAlerts == true }
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Party and buddy notifications").font(AppTypography.headline)
            if enabled {
                Button("Turn off party notifications") { social.setCampfireAlerts(false, partyID: partyID) }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
            } else {
                Button("Notify me about starts and buddy check-ins") { social.enableCampfireInvitations(partyID: partyID) }
                    .buttonStyle(PixelPrimaryButtonStyle())
            }
            Stepper("Quiet from \(hour(quietStart))", value: $quietStart, in: 0...23)
            Stepper("Until \(hour(quietEnd))", value: $quietEnd, in: 0...23)
            Text("Uses this phone’s time zone. Matching hours means no scheduled quiet hours. Active sessions still silence invitations when their quiet time has synced.")
                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            Button("Save quiet hours") {
                guard let owner = social.pastureOwner else { return }
                let prefix = "ollie.campfire.\(owner.uuidString)."
                UserDefaults.standard.set(quietStart, forKey: prefix + "quietStart")
                UserDefaults.standard.set(quietEnd, forKey: prefix + "quietEnd")
                social.syncCampfirePush()
            }.buttonStyle(PixelChipButtonStyle(isSelected: false))
            if !social.campfirePushStatus.isEmpty {
                Text(social.campfirePushStatus).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            if enabled {
                Button("Retry phone registration") { social.enableCampfireInvitations(partyID: partyID) }
                    .font(AppTypography.caption).frame(minHeight: 44)
            }
        }
        .task {
            guard let owner = social.pastureOwner else { return }
            let prefix = "ollie.campfire.\(owner.uuidString)."
            quietStart = UserDefaults.standard.object(forKey: prefix + "quietStart") as? Int ?? 23
            quietEnd = UserDefaults.standard.object(forKey: prefix + "quietEnd") as? Int ?? 7
        }
    }
    private func hour(_ value: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: value)) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
