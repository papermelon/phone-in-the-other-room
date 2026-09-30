#if DEBUG
import SwiftUI

@MainActor
enum SocialInboxFixtures {
    static let source = SocialSource(kind: "activity", id: UUID(uuidString: "91000000-0000-4000-8000-000000000099")!, partyID: SlumberPartySharedFarmFixtures.partyID)
    static func model() -> NightFlockViewModel {
        let model = NightFlockViewModel(featureEnabled: false, previewPhase: .ready, previewAccountState: .linked)
        let party = SlumberPartySharedFarmFixtures.party
        model.v4ListState = .init(parties: [party.summary])
        model.v4ListState?.socialInboxVersion = 1
        model.socialUnreadCount = 3
        model.socialInboxEvents = [
            .init(id: "support:one", kind: "cheer", source: source, partyID: party.summary.partyID, partyName: party.summary.name,
                  senderName: "Moss", messageID: "niceWork", context: "Wind Down", occurredAt: .now.addingTimeInterval(-86400),
                  arrivedAt: .now.addingTimeInterval(-480), isRead: false, count: 1),
            .init(id: "support:two", kind: "cheer", source: .init(kind: "global", id: source.id), messageID: "restWell", context: "Wind Down",
                  occurredAt: .now.addingTimeInterval(-3600), arrivedAt: .now.addingTimeInterval(-600), isRead: false, count: 3),
            .init(id: "support:three", kind: "cheer", source: source, partyID: party.summary.partyID, partyName: party.summary.name,
                  senderName: "Fern", messageID: "rootingForYou", context: "Phone Away", occurredAt: .now.addingTimeInterval(-7200),
                  arrivedAt: .now.addingTimeInterval(-1800), isRead: true, count: 1)
        ]
        model.supportDetails[source] = .init(source: source, name: "Moss", context: "Wind Down", occurredAt: .now,
            messages: ["niceWork", "highFive", "lovelyProgress", "rootingForYou", "cheeringYouOn"], removed: false)
        return model
    }
}

struct SocialInboxNativeFixture: View {
    @StateObject private var model = SocialInboxFixtures.model()
    private var picker: Bool { ProcessInfo.processInfo.arguments.contains("--cheer-picker") }
    var body: some View {
        NavigationStack {
            if picker {
                ScrollView {
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Moss’s Wind Down").font(AppTypography.title)
                            Text("Shared yesterday · Moonfield").font(AppTypography.body)
                            SupportMessageControl(social: model, source: SocialInboxFixtures.source)
                        }
                    }.padding(AppSpacing.md)
                }.background(AppColors.paper)
            } else { SocialInboxView(social: model) }
        }
        .environment(\.dynamicTypeSize, ProcessInfo.processInfo.arguments.contains("--social-large-text") ? .accessibility3 : .large)
    }
}

#Preview("Inbox · received messages") { SocialInboxNativeFixture() }
#endif
