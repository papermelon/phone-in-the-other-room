import SwiftUI
import WidgetKit

struct LockScreenQuietNoteGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var note = QuietNoteText.defaultText
    @State private var didSave = false
    @FocusState private var noteIsFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                noteEditorBlock
                addWidgetBlock
                privacyBlock
                surfacesBlock
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Quiet Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            note = QuietNoteText.savedText ?? QuietNoteText.defaultText
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("A little note below the clock")
                .font(AppTypography.display(30))
            Text("Keep one gentle line nearby when you reach for your phone.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
        }
    }

    private var noteEditorBlock: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                blockLabel("Write your note", detail: "This is the note your Quiet Note widget will show.")
                TextEditor(text: $note)
                    .focused($noteIsFocused)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.ink)
                    .scrollContentBackground(.hidden)
                    .padding(AppSpacing.xs)
                    .frame(minHeight: 110)
                    .background(AppColors.surfaceMuted.opacity(0.42), in: RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(AppColors.stroke.opacity(0.18), lineWidth: 1)
                    }
                HStack(alignment: .center, spacing: AppSpacing.sm) {
                    Text("\(QuietNoteText.normalized(note).count)/\(QuietNoteText.maximumLength)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Spacer()
                    Button("Save note") {
                        saveNote()
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())
                }
                if didSave {
                    Label("Saved to your Quiet Note widget.", systemImage: "checkmark.circle.fill")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                }
            }
        }
    }

    private var addWidgetBlock: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                blockLabel("Add it once", detail: "Then the note is close by without opening Counting Sheep.")
                guideStep("1", "Touch and hold your Lock Screen, then choose Customize.")
                guideStep("2", "Select the Lock Screen and tap the widget area below the clock.")
                guideStep("3", "Choose Counting Sheep, then add Quiet Note.")
                guideStep("4", "Finish customizing, then tap the installed Quiet Note widget. Counting Sheep opens this editor so you can save your note.")
            }
        }
    }

    private var privacyBlock: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                blockLabel("Keep it short", detail: nil)
                Text("Anything you enter may be visible while your phone is locked, so keep private details inside Counting Sheep.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private var surfacesBlock: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                blockLabel("Two quiet surfaces", detail: nil)
                Text("The Quiet Note stays in place. During Wind Down, the separate Live Activity can show your current phase and timer.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private func blockLabel(_ title: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.headline)
            if let detail {
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func guideStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(number)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.grass)
                .frame(width: 24, alignment: .leading)
            Text(text)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
        }
    }

    private func saveNote() {
        note = QuietNoteText.save(note)
        WidgetCenter.shared.reloadTimelines(ofKind: QuietNoteText.widgetKind)
        noteIsFocused = false
        withAnimation(AppMotion.stateChange) {
            didSave = true
        }
    }
}

#Preview {
    NavigationStack {
        LockScreenQuietNoteGuideView()
    }
}
