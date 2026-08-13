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
            NightFlockChallengeTrail(snapshot: snapshot, currentDay: challengeDay)
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
                        ? "The seven-night trail begins when a second member joins."
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
                Text("No exact times, durations, missed nights, early endings, health data, app selections, or Farm data are shared.")
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
    let currentDay: Int?

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(snapshot.challenge.status == .completed ? "GROUP TRAIL NOTE" : "SEVEN-NIGHT TRAIL")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                HStack(spacing: AppSpacing.xs) {
                    ForEach(1...7, id: \.self) { day in
                        let summary = snapshot.days.first(where: { $0.day == day })
                        VStack(spacing: AppSpacing.xxs) {
                            Image(systemName: trailSymbol(for: summary))
                                .foregroundStyle(trailColor(day: day, summary: summary))
                            Text("\(day)")
                                .font(pixelFont(.caption2))
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(accessibilityLabel(day: day, summary: summary))
                    }
                }
                if snapshot.challenge.status == .completed {
                    Text("Seven nights passed through this pasture. There is no rank or reward.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    private func trailSymbol(for summary: NightFlockDaySummary?) -> String {
        if (summary?.morningQuietCompletedCount ?? 0) > 0 { return "sun.max.fill" }
        if (summary?.phoneTuckedCount ?? 0) > 0 { return "moon.fill" }
        return "circle"
    }

    private func trailColor(day: Int, summary: NightFlockDaySummary?) -> Color {
        if (summary?.morningQuietCompletedCount ?? 0) > 0 { return AppColors.amber }
        if (summary?.phoneTuckedCount ?? 0) > 0 { return AppColors.lavender }
        return day == currentDay ? AppColors.grass : AppColors.stroke
    }

    private func accessibilityLabel(day: Int, summary: NightFlockDaySummary?) -> String {
        if (summary?.morningQuietCompletedCount ?? 0) > 0 { return "Day \(day), quiet morning shared" }
        if (summary?.phoneTuckedCount ?? 0) > 0 { return "Day \(day), phone tucked shared" }
        return "Day \(day), no shared note"
    }
}
