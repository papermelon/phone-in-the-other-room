import SwiftUI

struct PhoneBedTagEditorRequest: Identifiable {
    enum Mode { case add(PhoneBedTagRole), rename(NamedPhoneBedTagRegistration), uses(NamedPhoneBedTagRegistration), replace(NamedPhoneBedTagRegistration) }
    let id = UUID()
    let mode: Mode
    static func add(role: PhoneBedTagRole) -> Self { Self(mode: .add(role)) }
    static func rename(_ tag: NamedPhoneBedTagRegistration) -> Self { Self(mode: .rename(tag)) }
    static func uses(_ tag: NamedPhoneBedTagRegistration) -> Self { Self(mode: .uses(tag)) }
    static func replace(_ tag: NamedPhoneBedTagRegistration) -> Self { Self(mode: .replace(tag)) }
    var tag: NamedPhoneBedTagRegistration? {
        switch mode { case .add: return nil; case .rename(let tag), .uses(let tag), .replace(let tag): return tag }
    }
    var role: PhoneBedTagRole {
        switch mode { case .add(let role): return role; case .rename(let tag), .uses(let tag), .replace(let tag): return tag.role }
    }
}

struct PhoneBedTagEditorSheet: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    let request: PhoneBedTagEditorRequest
    @State private var name: String
    @State private var purposes: Set<PhoneBedTagPurpose>

    init(request: PhoneBedTagEditorRequest) {
        self.request = request
        _name = State(initialValue: request.tag?.name ?? NamedPhoneBedTagRegistration.defaultName)
        _purposes = State(initialValue: request.tag?.purposes ?? NamedPhoneBedTagRegistration.allPurposes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text(title).font(AppTypography.display(28))
                        TextField("Tag name", text: $name).textFieldStyle(.roundedBorder)
                        Text("Names are local-only and limited to \(NamedPhoneBedTagRegistration.maximumNameLength) characters.").font(AppTypography.caption).foregroundStyle(AppColors.muted)
                        purposeChoices
                        Text("Suggested label: Counting Sheep — \(NamedPhoneBedTagRegistration.normalizedName(name))").font(AppTypography.caption).foregroundStyle(AppColors.muted)
                        Text("Place the tag where your phone should rest. The place name is never written to NFC or transmitted.").font(AppTypography.caption).foregroundStyle(AppColors.muted)
                        Button(actionTitle, action: commit).buttonStyle(PixelPrimaryButtonStyle()).disabled(viewModel.isProvisioningNFCTag || purposes.isEmpty)
                        if !viewModel.nfcStatus.isEmpty { Text(viewModel.nfcStatus).font(AppTypography.caption).foregroundStyle(AppColors.muted) }
                    }
                }.padding(AppSpacing.md)
            }
            .background(AppColors.paper.ignoresSafeArea()).navigationTitle(request.role.displayName).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var title: String {
        switch request.mode { case .add: return "Pair a tag"; case .rename: return "Rename tag"; case .uses: return "Change tag uses"; case .replace: return "Replace tag" }
    }
    private var actionTitle: String {
        switch request.mode { case .add: return "Pair tag"; case .rename: return "Save name"; case .uses: return "Save uses"; case .replace: return "Pair replacement" }
    }
    private var purposeChoices: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("USES").font(pixelFont(.caption)).foregroundStyle(AppColors.grass)
            ForEach(PhoneBedTagPurpose.allCases, id: \.self) { purpose in
                Toggle(purpose.displayName, isOn: Binding(get: { purposes.contains(purpose) }, set: { enabled in if enabled { purposes.insert(purpose) } else { purposes.remove(purpose) } }))
                    .font(AppTypography.body).frame(minHeight: 44)
            }
        }
    }
    private func commit() {
        switch request.mode {
        case .add: viewModel.provisionNFCTag(role: request.role, name: name, purposes: purposes)
        case .rename(let tag): viewModel.renameNFCTag(id: tag.id, name: name)
        case .uses(let tag): viewModel.changeNFCTagPurposes(id: tag.id, purposes: purposes)
        case .replace: viewModel.provisionNFCTag(forActiveRun: viewModel.activeRun?.guardKind == .nfcTag, role: request.role, name: name, purposes: purposes)
        }
    }
}

struct LostPhoneBedTagWizard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    let initialRole: PhoneBedTagRole?
    @State private var selectedRole: PhoneBedTagRole?
    @State private var name = NamedPhoneBedTagRegistration.defaultName
    @State private var purposes = NamedPhoneBedTagRegistration.allPurposes
    @State private var showsDetails = false

    init(initialRole: PhoneBedTagRole?) { self.initialRole = initialRole; _selectedRole = State(initialValue: initialRole) }
    var body: some View {
        NavigationStack {
            ScrollView {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Lost tag replacement").font(AppTypography.display(28))
                        Text("Your old tag is not required. It stays paired until the replacement is written successfully.").font(AppTypography.body)
                        if showsDetails { replacementDetails } else { roleSelection }
                        if !viewModel.nfcStatus.isEmpty { Text(viewModel.nfcStatus).font(AppTypography.caption).foregroundStyle(AppColors.muted) }
                        if viewModel.activeRun?.guardKind == .nfcTag { Text("Your run and app limits stay active. Close this wizard to reach the separate emergency exit.").font(AppTypography.caption).foregroundStyle(AppColors.muted) }
                    }
                }.padding(AppSpacing.md)
            }
            .background(AppColors.paper.ignoresSafeArea()).navigationTitle("Replace lost tag").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }.onAppear(perform: loadSelection)
    }
    private var roleSelection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Which tag are you replacing?").font(AppTypography.headline)
            ForEach(viewModel.phoneBedTagLibrary.tags) { tag in
                Button { selectedRole = tag.role; name = tag.name; purposes = tag.purposes } label: {
                    HStack { VStack(alignment: .leading) { Text(tag.name).font(AppTypography.body.weight(.semibold)); Text(tag.role.displayName).font(AppTypography.caption) }; Spacer(); if selectedRole == tag.role { Image(systemName: "checkmark.circle.fill") } }.frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                }.buttonStyle(.plain).foregroundStyle(AppColors.ink).padding(.horizontal, AppSpacing.sm).background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
            }
            Button("Continue") { showsDetails = true }.buttonStyle(PixelPrimaryButtonStyle()).disabled(selectedRole == nil)
        }
    }
    private var replacementDetails: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            TextField("Replacement name", text: $name).textFieldStyle(.roundedBorder)
            ForEach(PhoneBedTagPurpose.allCases, id: \.self) { purpose in
                Toggle(purpose.displayName, isOn: Binding(get: { purposes.contains(purpose) }, set: { enabled in if enabled { purposes.insert(purpose) } else { purposes.remove(purpose) } })).frame(minHeight: 44)
            }
            Text("Suggested label: Counting Sheep — \(NamedPhoneBedTagRegistration.normalizedName(name))").font(AppTypography.caption).foregroundStyle(AppColors.muted)
            Text("Place it where your phone should rest. This name stays on your iPhone.").font(AppTypography.caption).foregroundStyle(AppColors.muted)
            Button("Pair replacement") { guard let selectedRole else { return }; viewModel.provisionNFCTag(forActiveRun: viewModel.activeRun?.guardKind == .nfcTag, role: selectedRole, name: name, purposes: purposes) }.buttonStyle(PixelPrimaryButtonStyle()).disabled(viewModel.isProvisioningNFCTag || purposes.isEmpty)
            Button("Back") { showsDetails = false }.frame(minHeight: 44)
        }
    }
    private func loadSelection() {
        guard let selectedRole, let tag = viewModel.phoneBedTagLibrary.tag(for: selectedRole) else { return }
        name = tag.name; purposes = tag.purposes
    }
}

#Preview("Phone-bed tag editor · replace primary") {
    let viewModel = FocusRunViewModel(startsExternalServices: false)
    let primary = NamedPhoneBedTagRegistration(
        name: "Bedroom shelf", tokenDigest: "primary-preview", registeredAt: .now,
        role: .primary, purposes: NamedPhoneBedTagRegistration.allPurposes
    )
    viewModel.phoneBedTagLibrary = PhoneBedTagLibrary(tags: [
        primary,
        NamedPhoneBedTagRegistration(
            name: "Travel pouch", tokenDigest: "backup-preview", registeredAt: .now,
            role: .backup, purposes: [.windDown]
        )
    ])
    return PhoneBedTagEditorSheet(request: .replace(primary))
        .environmentObject(viewModel)
}

#Preview("Phone-bed tag editor · lost backup") {
    let viewModel = FocusRunViewModel(startsExternalServices: false)
    viewModel.phoneBedTagLibrary = PhoneBedTagLibrary(tags: [
        NamedPhoneBedTagRegistration(
            name: "Bedroom shelf", tokenDigest: "primary-preview", registeredAt: .now,
            role: .primary, purposes: NamedPhoneBedTagRegistration.allPurposes
        ),
        NamedPhoneBedTagRegistration(
            name: "Travel pouch", tokenDigest: "backup-preview", registeredAt: .now,
            role: .backup, purposes: NamedPhoneBedTagRegistration.allPurposes
        )
    ], previouslyPairedTokenDigests: ["retired-backup-preview"])
    return LostPhoneBedTagWizard(initialRole: .backup)
        .environmentObject(viewModel)
}
