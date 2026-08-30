import SwiftUI

/// A member's one deliberately selected social identity. The renderer accepts
/// only the bounded presentation contract and falls back to the Shepherd for
/// legacy or malformed values.
struct SlumberPartySocialAvatarView: View {
    let presentation: CountingSheepPublicPresentation
    let avatarID: String
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.grassLight.opacity(0.48))
            avatarContent
                .padding(AppSpacing.xxs)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.title(for: avatarID))
    }

    @ViewBuilder
    private var avatarContent: some View {
        switch avatarID {
        case "ollie":
            OllieFarmAvatar(accessoryItemID: ollieAccessoryID, size: size - AppSpacing.sm)
        case let value where value.hasPrefix("sheep:"):
            if let sheep = SheepCatalog.definition(for: String(value.dropFirst("sheep:".count))) {
                PixelAssetImage(name: sheep.assetName)
                    .frame(width: size - AppSpacing.sm, height: size - AppSpacing.sm)
                    .accessibilityHidden(true)
            } else {
                shepherd
            }
        case "shepherd":
            shepherd
        default:
            shepherd
        }
    }

    private var shepherd: some View {
        ShepherdAvatarView(profile: shepherdProfile, size: size - AppSpacing.sm)
            .accessibilityHidden(true)
    }

    private var shepherdProfile: ShepherdProfile {
        let source = presentation.isAllowlisted() ? presentation : .defaultValue
        return ShepherdProfile(
            skinTone: ShepherdSkinTone(rawValue: source.skinToneID) ?? .warm,
            hairStyle: ShepherdHairStyle(rawValue: source.hairStyleID) ?? .waves,
            outfitItemID: source.shepherdOutfitID == "none" ? nil : source.shepherdOutfitID,
            accessoryItemID: source.shepherdAccessoryID == "none" ? nil : source.shepherdAccessoryID
        )
    }

    private var ollieAccessoryID: String? {
        let source = presentation.isAllowlisted() ? presentation : .defaultValue
        return source.ollieOrnamentID == "none" ? nil : source.ollieOrnamentID
    }

    static func title(for avatarID: String) -> String {
        switch avatarID {
        case "shepherd": return "Shepherd"
        case "ollie": return "Ollie"
        case let value where value.hasPrefix("sheep:"):
            return SheepCatalog.definition(for: String(value.dropFirst("sheep:".count)))?.name ?? "Shepherd"
        default: return "Shepherd"
        }
    }
}

struct SlumberPartySocialAvatarPicker: View {
    @EnvironmentObject private var appViewModel: FocusRunViewModel
    let presentation: CountingSheepPublicPresentation
    @State private var previewAvatarID: String
    @State private var feedback: String?

    init(presentation: CountingSheepPublicPresentation, initialAvatarID: String) {
        self.presentation = presentation
        _previewAvatarID = State(initialValue: initialAvatarID)
    }

    private var choices: [String] {
        appViewModel.availableSocialAvatarIDs.filter {
            $0 == "shepherd"
                || $0 == "ollie"
                || ($0.hasPrefix("sheep:")
                    && SheepCatalog.definition(for: String($0.dropFirst("sheep:".count))) != nil)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("YOUR GROUP IDENTITY")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("Choose one familiar face")
                        .font(AppTypography.display(30))
                    Text("This one identity appears across your Slumber Parties. Your Home Ollie stays just as it is.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                selectedPreview
                availabilityNote

                VStack(spacing: AppSpacing.xs) {
                    ForEach(choices, id: \.self) { avatarID in
                        choiceRow(avatarID)
                    }
                }
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Group identity")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedPreview: some View {
        PixelCard {
            HStack(spacing: AppSpacing.md) {
                SlumberPartySocialAvatarView(
                    presentation: presentation,
                    avatarID: previewAvatarID,
                    size: 80
                )
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("YOUR PREVIEW")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(SlumberPartySocialAvatarView.title(for: previewAvatarID))
                        .font(AppTypography.headline)
                    Text("Shepherd and Ollie keep their existing customization. Sheep appear as themselves.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func choiceRow(_ avatarID: String) -> some View {
        Button {
            choose(avatarID)
        } label: {
            HStack(spacing: AppSpacing.sm) {
                SlumberPartySocialAvatarView(
                    presentation: presentation,
                    avatarID: avatarID,
                    size: 56
                )
                Text(SlumberPartySocialAvatarView.title(for: avatarID))
                    .font(AppTypography.body.weight(.semibold))
                    .foregroundStyle(AppColors.ink)
                Spacer(minLength: AppSpacing.sm)
                if previewAvatarID == avatarID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.grass)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        }
        .buttonStyle(PixelChipButtonStyle(isSelected: previewAvatarID == avatarID))
        .accessibilityLabel("Use \(SlumberPartySocialAvatarView.title(for: avatarID)) as your group identity")
        .accessibilityValue(previewAvatarID == avatarID ? "Selected" : "")
    }

    @ViewBuilder
    private var availabilityNote: some View {
        if let feedback {
            Text(feedback)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        } else if let syncMessage = appViewModel.socialAvatarSyncMessage {
            Text(syncMessage)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        } else if !appViewModel.socialAvatarSharingAvailable {
            Text("Sharing this choice needs group service support. You can preview it here; your group keeps its current identity for now.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func choose(_ avatarID: String) {
        guard choices.contains(avatarID) else { return }
        if let validationMessage = appViewModel.selectSocialAvatar(avatarID) {
            feedback = validationMessage
        } else {
            previewAvatarID = avatarID
            feedback = nil
        }
    }
}

#Preview("Social identity renderer · safe fallback") {
    HStack(spacing: AppSpacing.md) {
        SlumberPartySocialAvatarView(
            presentation: .defaultValue,
            avatarID: "shepherd"
        )
        SlumberPartySocialAvatarView(
            presentation: .defaultValue,
            avatarID: "unknown"
        )
    }
    .padding()
    .background(AppColors.paper)
}

#Preview("Social identity picker") {
    NavigationStack {
        SlumberPartySocialAvatarPicker(
            presentation: .defaultValue,
            initialAvatarID: "shepherd"
        )
        .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
}
