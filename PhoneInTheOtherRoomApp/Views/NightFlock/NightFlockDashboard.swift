import SwiftUI
import UIKit

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct NightFlockDashboard: View {
    @EnvironmentObject private var focusViewModel: FocusRunViewModel
    @ObservedObject var viewModel: NightFlockViewModel
    let snapshot: NightFlockSnapshot
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    @State private var showInstagramPicker = false
#endif

    private var mySetup: NightFlockMemberSetup? {
        snapshot.memberSetups.first(where: { $0.memberID == snapshot.myMemberID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            tonightGoal
            mySetupCard
            NightFlockRewardsCard(snapshot: snapshot)
            sevenNights
            routineIdeas
            ideasAndSources
            inviteCard
            NavigationLink {
                NightFlockSharingAccountView(viewModel: viewModel, snapshot: snapshot)
            } label: {
                Label("Sharing and account", systemImage: "lock.shield.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
        }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        .familyActivityPicker(
            headerText: "Choose the apps to shield during Wind Down. Confirm that Instagram is included.",
            footerText: "Apple keeps the selection on this iPhone. Counting Sheep does not receive the token or app list.",
            isPresented: $showInstagramPicker,
            selection: $focusViewModel.bedtimeActivitySelection
        )
        .onChange(of: focusViewModel.bedtimeActivitySelection) { _, _ in
            focusViewModel.saveScreenTimeSelection(.bedtime)
        }
#endif
    }

    private var tonightGoal: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("TONIGHT’S SHARED GOAL").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                if let goal = snapshot.challenge.sharedGoal {
                    Text(goal.title).font(AppTypography.title)
                    Text("Everyone chose this same goal. Your bedtime and routine can still be your own.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    NightFlockTipCallout(
                        viewModel: viewModel,
                        tip: .sharedGoal,
                        title: "Shared goal",
                        message: "Everyone chose this same goal. Your bedtime and routine can still be your own."
                    )
                    if snapshot.challenge.status == .pending {
                        Text("Lobby · " + String(snapshot.members.count) + " of 8 people").font(AppTypography.caption.weight(.semibold))
                    } else if let day = NightFlockChallengeDayRules.challengeDay(at: Date(), challenge: snapshot.challenge) {
                        Text("Night " + String(day) + " of 7").font(AppTypography.caption.weight(.semibold))
                    } else if snapshot.challenge.status == .completed {
                        Text("Seven nights complete").font(AppTypography.caption.weight(.semibold))
                    }
                }
            }
        }
    }

    private var mySetupCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("MY SETUP").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                Text(mySetup?.setupReady == true ? "Your shared-goal setup is ready." : "Set up the shared goal on this iPhone.")
                    .font(AppTypography.headline)
                Text("App choices stay here. Exact bedtime and wake time stay here too.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                NightFlockTipCallout(
                    viewModel: viewModel,
                    tip: .mySetup,
                    title: "My setup",
                    message: "Set up the shared goal on this iPhone. App choices stay here."
                )
                if snapshot.challenge.sharedGoal?.kind == .shieldInstagram {
                    Text(mySetup?.shieldingEvidence.title ?? "Choose Instagram locally, then confirm it here.")
                        .font(AppTypography.caption.weight(.semibold))
                    Button("Choose apps on this iPhone") {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
                        showInstagramPicker = true
#else
                        viewModel.commitmentDraft.shieldingEvidence = .unavailable
#endif
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    Text("You confirm Instagram is included. Counting Sheep can only report coarse app-shielding observation.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    Toggle("I confirmed Instagram is included", isOn: Binding(
                        get: { viewModel.commitmentDraft.shieldingEvidence == .observed },
                        set: {
                            viewModel.commitmentDraft.shieldingEvidence = $0 ? .observed : .partial
                        }
                    ))
                }
                if mySetup?.goalAccepted != true {
                    Button("Accept shared goal", action: viewModel.acceptSharedGoal)
                        .frame(maxWidth: .infinity).buttonStyle(PixelPrimaryButtonStyle())
                } else if mySetup?.setupReady != true {
                    Button("Mark setup ready", action: viewModel.saveSharedSetup)
                        .frame(maxWidth: .infinity).buttonStyle(PixelPrimaryButtonStyle())
                } else {
                    Label("Ready for the lobby", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.grass)
                }
            }
        }
    }

    private var sevenNights: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("OUR SEVEN NIGHTS").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                Text("Follow through together").font(AppTypography.headline)
                ForEach(snapshot.days) { day in
                    let progresses = day.memberProgress
                    HStack(alignment: .center, spacing: AppSpacing.sm) {
                        Text("Night \(day.day)").font(AppTypography.body.weight(.semibold)).frame(width: 68, alignment: .leading)
                        if progresses.isEmpty {
                            Text(snapshot.challenge.status == .pending ? "Waiting for the lobby" : "No update shared")
                                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        } else {
                            HStack(spacing: AppSpacing.xs) {
                                ForEach(progresses) { progress in
                                    Label(progress.status.title, systemImage: progress.status.symbolName)
                                        .font(AppTypography.caption)
                                        .labelStyle(.iconOnly)
                                        .foregroundStyle(statusColor(progress.status))
                                        .accessibilityLabel("\(memberName(progress.memberID)), \(progress.status.title)")
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44)
                }
                Text("No update shared is not counted as completion. There are no rankings.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                NavigationLink {
                    NightFlockMemberBoardView(snapshot: snapshot)
                } label: {
                    Label("Named progress", systemImage: "person.3.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                NightFlockTipCallout(
                    viewModel: viewModel,
                    tip: .groupProgress,
                    title: "Group progress",
                    message: "See how the group is following through and send a small cheer."
                )
                NavigationLink {
                    NightFlockSharedPastureView(viewModel: viewModel, snapshot: snapshot)
                } label: {
                    Label("Shared cheers", systemImage: "hands.clap.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                if snapshot.challenge.status == .pending && viewModel.isHost {
                    Button("Start seven nights", action: viewModel.startSharedParty)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PixelPrimaryButtonStyle())
                        .disabled(!viewModel.canStartSharedParty)
                    Text(viewModel.canStartSharedParty ? "Everyone is ready." : "Start when two or more people have accepted the goal and finished local setup.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    private var routineIdeas: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("WHAT HELPS OUR GROUP WIND DOWN").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                Text("Share routine ideas, if you want to").font(AppTypography.headline)
                Text("These are ideas, not checklists. Different routines are expected.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                NightFlockTipCallout(
                    viewModel: viewModel,
                    tip: .sharedRoutineIdeas,
                    title: "Shared routine ideas",
                    message: "Share the ideas that help you. Different routines are expected."
                )
                Toggle("Share my selected ideas", isOn: Binding(
                    get: { viewModel.commitmentDraft.sharing.shareRoutineIdeas },
                    set: {
                        viewModel.commitmentDraft.sharing.shareRoutineIdeas = $0
                        viewModel.saveSharingPreferences()
                    }
                ))
                ForEach(WindDownGuidanceLibrary.items.prefix(6)) { item in
                    Button {
                        if viewModel.commitmentDraft.sharedRoutineIDs.contains(item.id) {
                            viewModel.commitmentDraft.sharedRoutineIDs.removeAll { $0 == item.id }
                        } else if viewModel.commitmentDraft.sharedRoutineIDs.count < 3 {
                            viewModel.commitmentDraft.sharedRoutineIDs.append(item.id)
                        }
                        viewModel.saveSharedRoutineIdeas()
                    } label: {
                        Label(item.title, systemImage: viewModel.commitmentDraft.sharedRoutineIDs.contains(item.id) ? "checkmark.square.fill" : "square")
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var ideasAndSources: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            NavigationLink {
                NightFlockIdeasView()
            } label: {
                Label("Ideas and sources", systemImage: "book.closed.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
            NightFlockTipCallout(
                viewModel: viewModel,
                tip: .evidenceAndSources,
                title: "Evidence and sources",
                message: "These are general sleep-health ideas from Counting Sheep’s source library."
            )
        }
    }

    private var inviteCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("INVITE PEOPLE").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
                if let code = viewModel.latestInviteCode {
                    Text(code).font(.system(.title2, design: .monospaced).weight(.bold)).textSelection(.enabled)
                        .accessibilityLabel("Party code \(code.map(String.init).joined(separator: " "))")
                    Text("Use this code until the lobby starts, expires, or reaches eight people.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    HStack {
                        Button("Copy code") { UIPasteboard.general.string = code }
                        ShareLink(item: code) { Label("Share code", systemImage: "square.and.arrow.up") }
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else {
                    Text("Invite people you know. The seven nights begin after everyone joins, accepts the goal, and the host starts.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                    NightFlockTipCallout(
                        viewModel: viewModel,
                        tip: .invitingPeople,
                        title: "Inviting people",
                        message: "Invite people you know. The seven nights begin after everyone has joined, accepted the goal, and the host starts."
                    )
                    Button("Create a reusable code", action: viewModel.createReusableInvite)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
            }
        }
    }

    private func statusColor(_ status: NightFlockMemberNightStatus) -> Color {
        switch status {
        case .morningQuietCompleted: return AppColors.amber
        case .sharedGoalCompleted: return AppColors.grass
        case .partiallyCompleted: return AppColors.lavender
        case .privateNoUpdate: return AppColors.muted
        default: return AppColors.ink
        }
    }

    private func memberName(_ id: UUID) -> String {
        snapshot.members.first(where: { $0.id == id })?.alias ?? "A group member"
    }
}
