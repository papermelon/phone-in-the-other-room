import SwiftUI

struct NightFlockDashboard: View {
    @ObservedObject var viewModel: NightFlockViewModel
    let snapshot: NightFlockSnapshot
    @State private var showLeaveConfirmation = false
    @State private var showDataDeletionConfirmation = false
    @State private var showAccountDeletionConfirmation = false

    private var challengeDay: Int? {
        NightFlockChallengeDayRules.challengeDay(at: Date(), challenge: snapshot.challenge)
    }

    private var currentSummary: NightFlockDaySummary? {
        challengeDay.flatMap { value in snapshot.days.first(where: { $0.day == value }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            identityCard
            NightFlockChallengeTrail(snapshot: snapshot)
            aggregateCard
            NavigationLink {
                NightFlockSharedPastureView(viewModel: viewModel, snapshot: snapshot)
            } label: {
                Label("Open the shared pasture", systemImage: "sunrise.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PixelPrimaryButtonStyle())

            inviteCard
            memberRoster
            privacyControls
        }
        .confirmationDialog("Leave this Slumber Party?", isPresented: $showLeaveConfirmation) {
            Button("Leave Slumber Party", role: .destructive, action: viewModel.leave)
        } message: {
            Text("Shared pasture access ends immediately. Your local nights and Farm stay unchanged.")
        }
        .confirmationDialog("Delete your Slumber Party data?", isPresented: $showDataDeletionConfirmation) {
            Button("Delete Slumber Party data", role: .destructive, action: viewModel.deleteNightFlockData)
        } message: {
            Text("This removes your membership, check-ins, reactions, invites, and profile from Slumber Party.")
        }
        .confirmationDialog("Delete the full online account?", isPresented: $showAccountDeletionConfirmation) {
            Button("Delete online account", role: .destructive, action: viewModel.deleteOnlineAccount)
        } message: {
            Text("This deletes the Supabase account and all online rows it owns. Local Counting Sheep data stays on this phone.")
        }
    }

    private var identityCard: some View {
        PixelCard {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: snapshot.identity.symbolName)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColors.lavender)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(snapshot.identity.title)
                        .font(AppTypography.title)
                    Text(snapshot.challenge.status == .pending
                        ? "Seven quiet nights begin when a second person joins."
                        : "Day \(challengeDay ?? 7) of seven · \(snapshot.members.count) members")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    private var aggregateCard: some View {
        let presentation = NightFlockAggregatePresentation.nighttime(
            positiveCount: currentSummary?.phoneTuckedCount ?? 0,
            memberCount: snapshot.members.count
        )
        return NightFlockStatusCard(
            symbol: "iphone.slash",
            title: presentation.title,
            detail: presentation.detail
        )
    }

    private var inviteCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("INVITE")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                if let code = viewModel.latestInviteCode {
                    Text(code)
                        .font(.system(.title2, design: .monospaced).weight(.bold))
                        .textSelection(.enabled)
                        .accessibilityLabel("Invite code \(code.map(String.init).joined(separator: " "))")
                    Text("This one-use code expires in seven days.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    Button("Revoke code", role: .destructive, action: viewModel.revokeLatestInvite)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else {
                    Text("Invite one person at a time with a short code. No contacts access is needed.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    Button("Make an invite code", action: viewModel.createInvite)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        .disabled(snapshot.members.count >= 8)
                }
            }
        }
    }

    private var memberRoster: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("FLOCK ROSTER")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                ForEach(snapshot.members) { member in
                    HStack {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(member.alias)
                                .font(AppTypography.body.weight(.semibold))
                            Text(member.id == snapshot.myMemberID
                                ? "You"
                                : (member.role == .keeper ? "Pasture keeper" : "Flock member"))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        Spacer()
                        if member.id != snapshot.myMemberID {
                            memberSafetyMenu(member)
                        }
                    }
                    .frame(minHeight: 44)
                }
            }
        }
    }

    private func memberSafetyMenu(_ member: NightFlockMember) -> some View {
        Menu {
            ForEach(NightFlockReportReason.allCases) { reason in
                Button("Report: \(reason.title)") {
                    viewModel.report(member, reason: reason)
                }
            }
            Button("Block and leave", role: .destructive) {
                viewModel.block(member)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Safety options for \(member.alias)")
    }

    private var privacyControls: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("PRIVACY & ACCOUNT")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Toggle("Allow positive check-ins", isOn: Binding(
                    get: { snapshot.sharingEnabled },
                    set: viewModel.setSharingEnabled
                ))
                    .tint(AppColors.grass)
                Text("Only positive check-ins are shared. Routine steps, schedules, absence, missed nights, health data, app choices, and private details stay here.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                Button("Leave Slumber Party") { showLeaveConfirmation = true }
                Button("Delete my Slumber Party data") { showDataDeletionConfirmation = true }
                Button("Delete full online account", role: .destructive) {
                    showAccountDeletionConfirmation = true
                }
            }
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
        }
    }
}

struct NightFlockChallengeTrail: View {
    let snapshot: NightFlockSnapshot

    private var sharedDays: [NightFlockDaySummary] {
        snapshot.days.filter {
            $0.phoneTuckedCount > 0 || $0.morningQuietCompletedCount > 0
        }
    }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(snapshot.challenge.status == .completed ? "SEVEN-NIGHT RESULT" : "SHARED MOMENTS")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                if sharedDays.isEmpty {
                    Text("Shared moments will appear here when someone chooses to share.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                } else {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(sharedDays) { summary in
                            let day = summary.day
                            VStack(spacing: AppSpacing.xxs) {
                                Image(systemName: trailSymbol(for: summary))
                                    .foregroundStyle(trailColor(summary: summary))
                                Text("Day \(day)")
                                    .font(pixelFont(.caption2))
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(accessibilityLabel(day: day, summary: summary))
                        }
                    }
                }
                if snapshot.challenge.status == .completed {
                    Text("Seven nights made room for shared moments. There is no rank or reward.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    private func trailSymbol(for summary: NightFlockDaySummary) -> String {
        summary.morningQuietCompletedCount > 0 ? "sun.max.fill" : "moon.fill"
    }

    private func trailColor(summary: NightFlockDaySummary) -> Color {
        summary.morningQuietCompletedCount > 0 ? AppColors.amber : AppColors.lavender
    }

    private func accessibilityLabel(day: Int, summary: NightFlockDaySummary) -> String {
        summary.morningQuietCompletedCount > 0
            ? "Day \(day), quiet morning shared"
            : "Day \(day), phone tucked shared"
    }
}
