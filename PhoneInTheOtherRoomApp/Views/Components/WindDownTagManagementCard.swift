import SwiftUI
import UIKit

struct WindDownTagManagementCard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var editorRequest: PhoneBedTagEditorRequest?
    @State private var tagToForget: NamedPhoneBedTagRegistration?
    @State private var showLostTagWizard = false
    @State private var lostTagRole: PhoneBedTagRole?
    @State private var resyncRole: PhoneBedTagRole?
    @State private var expandedTagActions = Set<UUID>()

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Wind Down tags").font(AppTypography.headline)
                    Text("Keep one primary tag and an optional backup. Names stay on this iPhone.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.muted).fixedSize(horizontal: false, vertical: true)
                }
                if viewModel.phoneBedTagLibrary.tags.isEmpty {
                    Text("No tags paired yet.").font(AppTypography.body).foregroundStyle(AppColors.muted)
                    managementButton("Pair primary tag", icon: "plus.circle.fill") { editorRequest = .add(role: .primary) }
                } else {
                    if let primary = viewModel.primaryPhoneBedTag { tagRow(primary) }
                    if let backup = viewModel.backupPhoneBedTag {
                        Divider(); tagRow(backup)
                    } else {
                        managementButton("Add backup tag", icon: "plus.circle") { editorRequest = .add(role: .backup) }
                    }
                }
                if !viewModel.phoneBedTagLibrary.tags.isEmpty {
                    managementButton("Lost a tag? Pair a replacement", icon: "arrow.triangle.2.circlepath") {
                        lostTagRole = nil; showLostTagWizard = true
                    }
                    if !viewModel.phoneBedTagLibrary.previouslyPairedTokenDigests.isEmpty {
                        Text("Resync writes a fresh credential to a retired tag. Its old credential stays retired, and no slot changes until the write succeeds.")
                            .font(AppTypography.caption).foregroundStyle(AppColors.muted)
                    }
                }
                if !viewModel.nfcStatus.isEmpty {
                    Text(viewModel.nfcStatus).font(AppTypography.caption).foregroundStyle(AppColors.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .sheet(item: $editorRequest) { PhoneBedTagEditorSheet(request: $0).environmentObject(viewModel) }
        .sheet(isPresented: $showLostTagWizard) { LostPhoneBedTagWizard(initialRole: lostTagRole).environmentObject(viewModel) }
        .confirmationDialog("Forget this tag?", isPresented: Binding(get: { tagToForget != nil }, set: { if !$0 { tagToForget = nil } }), presenting: tagToForget) { tag in
            Button("Forget \(tag.name)", role: .destructive) { viewModel.forgetNFCTag(id: tag.id); tagToForget = nil }
            Button("Keep tag", role: .cancel) { tagToForget = nil }
        } message: { tag in
            Text("\(tag.name) will no longer start or end its assigned runs. Nothing is erased from the physical tag.")
        }
        .confirmationDialog("Resync a retired tag?", isPresented: Binding(get: { resyncRole != nil }, set: { if !$0 { resyncRole = nil } }), presenting: resyncRole) { role in
            Button("Write fresh credential") { viewModel.resyncRetiredNFCTag(role: role); resyncRole = nil }
            Button("Not now", role: .cancel) { resyncRole = nil }
        } message: { role in
            Text("Hold the retired tag near your iPhone. Counting Sheep will write a fresh credential for the \(role.displayName.lowercased()) slot only after it confirms the physical write.")
        }
    }

    private func tagRow(_ tag: NamedPhoneBedTagRegistration) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(tag.name).font(AppTypography.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    Text("\(tag.role.displayName) · Paired").font(AppTypography.caption).foregroundStyle(AppColors.muted)
                }
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.grass).accessibilityLabel("Paired")
            }
            purposeBadges(tag)
            Text("Suggested label: \(tag.suggestedLabel)").font(AppTypography.caption).foregroundStyle(AppColors.muted).fixedSize(horizontal: false, vertical: true)
            Button("Copy label") { UIPasteboard.general.string = tag.suggestedLabel; viewModel.nfcStatus = "Label copied. Place the tag where your phone should rest." }
                .font(AppTypography.caption.weight(.semibold)).foregroundStyle(AppColors.grass).frame(minHeight: 44)
            DisclosureGroup("Manage tag", isExpanded: Binding(get: { expandedTagActions.contains(tag.id) }, set: { expanded in
                if expanded { expandedTagActions.insert(tag.id) } else { expandedTagActions.remove(tag.id) }
            })) {
                VStack(spacing: AppSpacing.xs) { actionButtons(tag) }.padding(.top, AppSpacing.xs)
            }
            .font(AppTypography.caption.weight(.semibold))
            .accessibilityHint("Shows tag test, rename, uses, replacement, and forget actions")
        }
    }

    @ViewBuilder private func actionButtons(_ tag: NamedPhoneBedTagRegistration) -> some View {
        managementButton("Test", icon: "dot.radiowaves.left.and.right") { viewModel.testNFCTag() }
        managementButton("Rename", icon: "pencil") { editorRequest = .rename(tag) }
        managementButton("Change uses", icon: "checklist") { editorRequest = .uses(tag) }
        managementButton("Replace", icon: "arrow.triangle.2.circlepath") { editorRequest = .replace(tag) }
        if !viewModel.phoneBedTagLibrary.previouslyPairedTokenDigests.isEmpty {
            managementButton("Resync retired tag for this slot", icon: "arrow.triangle.2.circlepath") { resyncRole = tag.role }
        }
        managementButton("Forget", icon: "trash") { tagToForget = tag }
    }

    private func purposeBadges(_ tag: NamedPhoneBedTagRegistration) -> some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(PhoneBedTagPurpose.allCases, id: \.self) { purpose in
                if tag.purposes.contains(purpose) {
                    Text(purpose.displayName).font(AppTypography.caption.weight(.semibold)).padding(.horizontal, AppSpacing.xs).padding(.vertical, AppSpacing.xxs).foregroundStyle(AppColors.grass).background(AppColors.grass.opacity(0.12), in: Capsule())
                }
            }
        }
        .accessibilityElement(children: .combine).accessibilityLabel("Uses: \(tag.purposesDescription)")
    }

    private func managementButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(AppTypography.caption.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(AppColors.ink).padding(.horizontal, AppSpacing.xs).background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }
}

#Preview("Wind Down tags · retired tag resync") {
    let model = FocusRunViewModel(startsExternalServices: false)
    let slotID = UUID()
    var library = PhoneBedTagLibrary(tags: [
        NamedPhoneBedTagRegistration(id: slotID, name: "Kitchen shelf", tokenDigest: "active", registeredAt: .now, role: .primary, purposes: [.windDown, .phoneAway]),
        NamedPhoneBedTagRegistration(name: "Hall table", tokenDigest: "backup", registeredAt: .now, role: .backup, purposes: [.windDown])
    ])
    library.replace(role: .primary, with: NamedPhoneBedTagRegistration(id: slotID, name: "Kitchen shelf", tokenDigest: "fresh", registeredAt: .now, role: .primary, purposes: [.windDown, .phoneAway]))
    model.phoneBedTagLibrary = library
    return ScrollView { WindDownTagManagementCard().padding() }
        .background(AppColors.paper)
        .environmentObject(model)
}
