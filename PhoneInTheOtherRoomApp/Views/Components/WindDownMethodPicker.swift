import SwiftUI
import UIKit

struct WindDownProtectionPicker: View {
    let selectedKind: SessionGuardKind
    let isNFCTagReady: Bool
    let shieldingReadiness: ShieldingReadiness
    let selectedAppsSummary: String?
    let onSelect: (WindDownProtectionChoice) -> Void
    let onAllowScreenTime: () -> Void
    let onChooseApps: () -> Void
    let onSetUpNFCTag: () -> Void
    let onShowAppShieldInfo: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                header
                methodRows
                shieldingStatus
                if selectedKind == .nfcTag, !isNFCTagReady {
                    nfcSetupRow
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("App limits")
                    .font(AppTypography.headline)
                Text("Selected apps are paused for Wind Down and the linked Screen-Free Morning.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            Spacer(minLength: AppSpacing.xs)
            Button(action: onShowAppShieldInfo) {
                Image(systemName: "questionmark")
                    .font(.body.weight(.bold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(AppColors.ink)
                    .background(AppColors.surfaceMuted, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("About app limits")
            .accessibilityHint("Learn how selected apps are limited during Wind Down.")
        }
    }

    private var methodRows: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("START METHOD")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            ForEach(WindDownProtectionChoice.allCases) { choice in
                methodButton(choice)
            }
        }
    }

    private func methodButton(_ choice: WindDownProtectionChoice) -> some View {
        let isSelected = selectedKind == choice.guardKind
        return Button {
            onSelect(choice)
        } label: {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: choice.systemImage)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(choice.startMethodTitle)
                        .font(AppTypography.body.weight(.semibold))
                    Text(choice.startMethodDetail)
                        .font(AppTypography.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.92) : AppColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: AppSpacing.xs)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.bold))
                }
            }
            .foregroundStyle(isSelected ? Color.white : AppColors.ink)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(
                isSelected ? AppColors.grass : AppColors.surfaceMuted,
                in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(
                        isSelected ? AppColors.grass : AppColors.stroke.opacity(0.35),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.startMethodTitle)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(choice.startMethodDetail)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var shieldingStatus: some View {
        switch shieldingReadiness {
        case .ready:
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColors.grass)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(selectedAppsSummary ?? "Selected apps")
                        .font(AppTypography.caption.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Ready for Wind Down")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                Spacer(minLength: AppSpacing.xs)
                Button("Change", action: onChooseApps)
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.grass)
                    .frame(minHeight: 44)
            }
        case .authorizationRequired:
            statusActionRow(
                icon: "lock.shield",
                title: "Allow Screen Time access",
                actionLabel: "Allow",
                action: onAllowScreenTime
            )
        case .noSelection:
            statusActionRow(
                icon: "square.stack.3d.up",
                title: "Choose apps to limit",
                actionLabel: "Choose",
                action: onChooseApps
            )
        case .denied, .revoked, .runtimeFailure:
            statusActionRow(
                icon: "lock.open",
                title: "Repair app protection",
                actionLabel: "Review",
                action: onChooseApps
            )
        case .unavailable:
            statusTextRow(
                icon: "iphone.slash",
                title: "App limits are unavailable here.",
                detail: "A new Wind Down needs app protection before it can start."
            )
        }
    }

    private var nfcSetupRow: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(AppColors.grass)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("NFC tag not paired")
                    .font(AppTypography.caption.weight(.semibold))
                Text("Pair a tag to use this start method.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            Spacer(minLength: AppSpacing.xs)
            Button("Set up NFC tag", action: onSetUpNFCTag)
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.grass)
                .frame(minHeight: 44)
        }
    }

    private func statusActionRow(
        icon: String,
        title: String,
        actionLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(AppTypography.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.xs)
                Text(actionLabel)
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.grass)
                    .frame(minHeight: 44)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Double tap to continue.")
    }

    private func statusTextRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.muted)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.caption.weight(.semibold))
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private extension WindDownProtectionChoice {
    var startMethodTitle: String {
        switch self {
        case .appShielding: return "Start in Counting Sheep"
        case .nfcAndAppShielding: return "Start with an NFC tag"
        }
    }

    var startMethodDetail: String {
        switch self {
        case .appShielding: return "One tap. No tag needed."
        case .nfcAndAppShielding: return "Tap your paired tag."
        }
    }
}
