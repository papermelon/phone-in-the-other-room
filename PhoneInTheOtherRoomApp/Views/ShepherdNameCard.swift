import SwiftUI

/// A local Farm identity editor. It deliberately makes the real editor fully
/// Dynamic Type capable; the compact pasture nameplate is only decorative.
struct ShepherdNameCard: View {
    let profile: CountingSheepUserProfile
    @Binding var draftName: String
    @Binding var feedback: String?
    let onSave: (String) -> String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isRenaming = false
    @FocusState private var nameFieldIsFocused: Bool

    private var hasName: Bool {
        profile.hasEstablishedDisplayName && !profile.displayName.isEmpty
    }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if hasName {
                    establishedName
                } else {
                    initialNameEditor
                }
            }
        }
        .onAppear {
            if draftName.isEmpty { draftName = profile.displayName }
        }
        .onChange(of: profile.displayName) { _, name in
            draftName = name
        }
    }

    private var establishedName: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("YOUR SHEPHERD")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            Text("\(profile.displayName)’s Shepherd")
                .font(AppTypography.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text("Ollie will use this name around the Farm.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if isRenaming {
                nameEditor
            } else {
                Button("Choose a new name") {
                    draftName = profile.displayName
                    feedback = nil
                    isRenaming = true
                    nameFieldIsFocused = true
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                .frame(minHeight: 44)
                .accessibilityHint("You can change your name up to twice in a rolling fourteen days.")
            }
        }
    }

    private var initialNameEditor: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("What should Ollie call you?")
                .font(AppTypography.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text("Choose a name for your Shepherd. You can update it later.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            nameEditor
        }
    }

    private var nameEditor: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            TextField("Name", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.body)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($nameFieldIsFocused)
                .onSubmit(save)
                .frame(minHeight: 44)
                .accessibilityLabel("Name Ollie should use")
                .accessibilityHint("Use 2 to 24 letters, numbers, spaces, apostrophes, or dashes.")

            if let feedback {
                Text(feedback)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
            }

            actionButtons
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: AppSpacing.xs) {
                saveButton
                if hasName { cancelButton }
            }
        } else {
            HStack(spacing: AppSpacing.sm) {
                saveButton
                if hasName { cancelButton }
            }
        }
    }

    private var saveButton: some View {
        Button("Save name") { save() }
            .buttonStyle(PixelPrimaryButtonStyle())
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private var cancelButton: some View {
        Button("Cancel") {
            draftName = profile.displayName
            feedback = nil
            isRenaming = false
            nameFieldIsFocused = false
        }
        .buttonStyle(PixelChipButtonStyle(isSelected: false))
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func save() {
        feedback = onSave(draftName)
        guard feedback == nil else { return }
        draftName = CountingSheepDisplayName.normalize(draftName)
        isRenaming = false
        nameFieldIsFocused = false
    }
}

#Preview("Shepherd name · initial") {
    ShepherdNameCardPreview(
        profile: CountingSheepUserProfile(displayName: ""),
        feedback: nil
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Shepherd name · limit · accessibility") {
    ShepherdNameCardPreview(
        profile: CountingSheepUserProfile(
            displayName: "Clover",
            successfulDisplayNameChangeDates: [Date(), Date()],
            hasEstablishedDisplayName: true
        ),
        feedback: "You can choose a new name again after one of your recent changes has had time to rest."
    )
    .padding()
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
}

private struct ShepherdNameCardPreview: View {
    let profile: CountingSheepUserProfile
    let initialFeedback: String?
    @State private var draftName = "Clover"
    @State private var feedback: String?

    init(profile: CountingSheepUserProfile, feedback: String?) {
        self.profile = profile
        self.initialFeedback = feedback
        _feedback = State(initialValue: feedback)
    }

    var body: some View {
        ShepherdNameCard(
            profile: profile,
            draftName: $draftName,
            feedback: $feedback,
            onSave: { _ in initialFeedback }
        )
    }
}
