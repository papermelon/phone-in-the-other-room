import SwiftUI

struct WindDownProtectionPicker: View {
    let selectedKind: SessionGuardKind
    let isNFCTagReady: Bool
    let onSelect: (WindDownProtectionChoice) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("HOW WILL YOU START?")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                Text("Choose how apps rest")
                        .font(AppTypography.headline)
                }

                LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                    ForEach(WindDownProtectionChoice.allCases) { choice in
                        methodButton(choice)
                    }
                }

                Text(methodDetail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func methodButton(_ choice: WindDownProtectionChoice) -> some View {
        let isSelected = selectedKind == choice.guardKind
        return Button {
            onSelect(choice)
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: choice.systemImage)
                    .frame(width: 22)
                Text(choice.title)
                    .font(AppTypography.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? AppColors.paper : AppColors.ink)
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(
                isSelected ? AppColors.grass : AppColors.surfaceMuted,
                in: RoundedRectangle(cornerRadius: AppRadius.md)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColors.stroke, lineWidth: isSelected ? 3 : 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(choice.title), \(isSelected ? "selected" : "not selected")")
        .accessibilityHint(choice.detail)
    }

    private var methodDetail: String {
        if selectedKind == .nfcTag, !isNFCTagReady {
            return "NFC needs a registered Wind Down tag. Set one up below before your first night."
        }
        return WindDownProtectionChoice.from(guardKind: selectedKind).detail
    }
}

#Preview("NFC selected") {
    WindDownProtectionPicker(
        selectedKind: .nfcTag,
        isNFCTagReady: true,
        onSelect: { _ in }
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("NFC setup needed") {
    WindDownProtectionPicker(
        selectedKind: .nfcTag,
        isNFCTagReady: false,
        onSelect: { _ in }
    )
    .padding()
    .background(AppColors.paper)
}
