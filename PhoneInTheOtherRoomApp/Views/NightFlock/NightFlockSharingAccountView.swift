import SwiftUI

struct NightFlockSharingAccountView: View {
    @ObservedObject var viewModel: NightFlockViewModel
    let snapshot: NightFlockSnapshot
    @State private var showLeaveConfirmation = false
    @State private var showPartyDeletionConfirmation = false
    @State private var showAccountDeletionConfirmation = false
    @State private var showGuide = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Sharing and account").font(AppTypography.display(27))
                Text("You control what the group sees. Slumber Party sharing and optional impact sharing are separate choices.")
                    .font(AppTypography.body).foregroundStyle(AppColors.secondaryText)
                NightFlockTipCallout(
                    viewModel: viewModel,
                    tip: .sharingControls,
                    title: "Sharing controls",
                    message: "You control what is shared with the group. Impact sharing is a separate choice."
                )
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("SHARING WITH THIS GROUP").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                        Toggle("Share goal progress", isOn: Binding(
                            get: { viewModel.commitmentDraft.sharing.shareGoalProgress },
                            set: {
                                viewModel.commitmentDraft.sharing.shareGoalProgress = $0
                                viewModel.saveSharingPreferences()
                            }
                        ))
                        Toggle("Share selected routine ideas", isOn: Binding(
                            get: { viewModel.commitmentDraft.sharing.shareRoutineIdeas },
                            set: {
                                viewModel.commitmentDraft.sharing.shareRoutineIdeas = $0
                                viewModel.saveSharingPreferences()
                            }
                        ))
                        Text("Names, group progress, and shared routine ideas stay inside this invited group. Exact schedules, app choices, and private routines stay on your iPhone.")
                            .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    }
                }
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("OPTIONAL IMPACT SHARING").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                        Text("Impact sharing is a separate Counting Sheep setting.").font(AppTypography.headline)
                        Text("Sleep outcomes, restfulness, HealthKit-derived values, and research-style records are not shared with this group.")
                            .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        Text("Change this separately in Settings → Connections.")
                            .font(AppTypography.caption.weight(.semibold))
                    }
                }
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("SAFETY").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                        Text("You can leave at any time. Blocking removes mutual visibility.")
                            .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        Button("Leave Slumber Party") { showLeaveConfirmation = true }
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    }
                }
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("DELETE ONLINE DATA").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                        Button("Delete Slumber Party data") { showPartyDeletionConfirmation = true }
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        Button("Delete full online account") { showAccountDeletionConfirmation = true }
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        Text("These controls do not erase local Wind Down, Nights, Farm, or rewards.")
                            .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    }
                }
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Sharing and account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Replay guide") {
                    viewModel.replayNightFlockOrientation()
                    showGuide = true
                }
            }
        }
        .sheet(isPresented: $showGuide) {
            NightFlockOrientationView(viewModel: viewModel)
        }
        .confirmationDialog("Leave Slumber Party?", isPresented: $showLeaveConfirmation) {
            Button("Leave Slumber Party", role: .destructive, action: viewModel.leave)
        } message: {
            Text("Your local Counting Sheep data stays on this iPhone.")
        }
        .confirmationDialog("Delete Slumber Party data?", isPresented: $showPartyDeletionConfirmation) {
            Button("Delete Slumber Party data", role: .destructive, action: viewModel.deleteNightFlockData)
        } message: {
            Text("This removes your group membership, shared updates, reactions, and invitations.")
        }
        .confirmationDialog("Delete full online account?", isPresented: $showAccountDeletionConfirmation) {
            Button("Delete full online account", role: .destructive, action: viewModel.deleteOnlineAccount)
        } message: {
            Text("Your local Wind Down, Nights, Farm, and rewards stay on this iPhone.")
        }
    }
}
