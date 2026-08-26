import SwiftUI

struct AppShieldExplainerSheet: View {
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        Text("About app limits")
                            .font(AppTypography.display(30))
                        explainerRow(
                            icon: "square.stack.3d.up.fill",
                            title: "Apps and categories you choose",
                            detail: "App protection covers only the private app and category selection you make in Apple’s picker. Websites and anything unselected remain available."
                        )
                        explainerRow(
                            icon: "pawprint.fill",
                            title: "Counting Sheep stays open",
                            detail: "You can return to it whenever you need."
                        )
                        explainerRow(
                            icon: "door.left.hand.open",
                            title: "You’re never locked in",
                            detail: "Emergency exit lifts app limits immediately and ends that Wind Down early."
                        )
                        explainerRow(
                            icon: "clock.arrow.circlepath",
                            title: "Brief Access is deliberate",
                            detail: "A short pause is counted factually. It does not reduce Screen-Free Morning minutes."
                        )
                        explainerRow(
                            icon: "dot.radiowaves.left.and.right",
                            title: "NFC is optional",
                            detail: "A paired tag can start Wind Down and is the normal way to end it. The ritual still begins by putting the phone in its other room."
                        )
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle("About app limits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }

    private func explainerRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.grass)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.headline)
                Text(detail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("App limits · ready") {
    WindDownProtectionPicker(
        selectedKind: .honorTimer,
        isNFCTagReady: true,
        shieldingReadiness: .ready,
        selectedAppsSummary: "2 apps, 1 category",
        onSelect: { _ in },
        onAllowScreenTime: {},
        onChooseApps: {},
        onSetUpNFCTag: {},
        onShowAppShieldInfo: {}
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Screen Time selection missing") {
    WindDownProtectionPicker(
        selectedKind: .honorTimer,
        isNFCTagReady: true,
        shieldingReadiness: .noSelection,
        selectedAppsSummary: nil,
        onSelect: { _ in },
        onAllowScreenTime: {},
        onChooseApps: {},
        onSetUpNFCTag: {},
        onShowAppShieldInfo: {}
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("NFC selected · tag missing") {
    WindDownProtectionPicker(
        selectedKind: .nfcTag,
        isNFCTagReady: false,
        shieldingReadiness: .authorizationRequired,
        selectedAppsSummary: nil,
        onSelect: { _ in },
        onAllowScreenTime: {},
        onChooseApps: {},
        onSetUpNFCTag: {},
        onShowAppShieldInfo: {}
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("App limits · dark mode") {
    WindDownProtectionPicker(
        selectedKind: .honorTimer,
        isNFCTagReady: true,
        shieldingReadiness: .ready,
        selectedAppsSummary: "1 app",
        onSelect: { _ in },
        onAllowScreenTime: {},
        onChooseApps: {},
        onSetUpNFCTag: {},
        onShowAppShieldInfo: {}
    )
    .padding()
    .background(AppColors.paper)
    .preferredColorScheme(.dark)
}

#Preview("App limits · accessibility text") {
    WindDownProtectionPicker(
        selectedKind: .honorTimer,
        isNFCTagReady: true,
        shieldingReadiness: .ready,
        selectedAppsSummary: "2 apps, 1 category",
        onSelect: { _ in },
        onAllowScreenTime: {},
        onChooseApps: {},
        onSetUpNFCTag: {},
        onShowAppShieldInfo: {}
    )
    .padding()
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("About app limits") {
    AppShieldExplainerSheet(onDone: {})
        .presentationDetents([.medium, .large])
}

#Preview("Wind Down tags · paired") {
    let viewModel = FocusRunViewModel(startsExternalServices: false)
    viewModel.phoneBedTagLibrary = PhoneBedTagLibrary(tags: [
        NamedPhoneBedTagRegistration(
            name: "Fridge",
            tokenDigest: "preview-primary",
            registeredAt: Date(),
            role: .primary,
            purposes: [.windDown, .phoneAway]
        ),
        NamedPhoneBedTagRegistration(
            name: "Living Room",
            tokenDigest: "preview-backup",
            registeredAt: Date(),
            role: .backup,
            purposes: [.windDown]
        )
    ])
    return WindDownTagManagementCard()
        .environmentObject(viewModel)
        .padding()
        .background(AppColors.paper)
        .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Wind Down tags · empty") {
    let viewModel = FocusRunViewModel(startsExternalServices: false)
    viewModel.phoneBedTagLibrary = PhoneBedTagLibrary()
    return WindDownTagManagementCard()
        .environmentObject(viewModel)
        .padding()
        .background(AppColors.paper)
}
