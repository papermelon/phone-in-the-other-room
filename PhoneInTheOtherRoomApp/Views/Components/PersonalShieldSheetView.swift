import SwiftUI

struct PersonalShieldPresentation: ViewModifier {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.scenePhase) private var scenePhase
    let routeHome: () -> Void

    func body(content: Content) -> some View {
        content
            .task {
                await Task.yield()
                viewModel.consumePersonalShieldRoute()
            }
            .onChange(of: viewModel.homeReceiptRoute) { _, _ in viewModel.consumePersonalShieldRoute() }
            .onChange(of: viewModel.personalShieldSheet) { _, sheet in
                if sheet != nil { routeHome() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { viewModel.dismissPersonalShield() }
                if phase == .active {
                    Task { @MainActor in
                        await Task.yield()
                        viewModel.consumePersonalShieldRoute()
                    }
                }
            }
            .sheet(item: $viewModel.personalShieldSheet, onDismiss: {
                if viewModel.personalShieldSheet == nil { viewModel.coordinator.cancelEmergencyExitChallenge() }
            }) { request in
                PersonalShieldSheetView(request: request)
                    .environmentObject(viewModel)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
    }
}

struct PersonalShieldSheetView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let request: PersonalShieldSheet
    @State private var entry = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if request.action == .checklist, let session = viewModel.personalShieldSession {
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            PersonalShieldChecklist(session: session, date: context.date,
                                toggle: viewModel.togglePersonalShieldStep)
                        }
                        Button("5-min access") { viewModel.openPersonalShield(.briefAccess) }
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        Button("End \(request.mode.timerName)") { viewModel.openPersonalShield(.endSession) }
                            .font(AppTypography.body).foregroundStyle(AppColors.muted).frame(minHeight: 44)
                    } else {
                        PersonalShieldPhraseForm(request: request, entry: $entry) {
                            _ = viewModel.confirmPersonalShield(request, entry: entry)
                        }
                        Button("Keep \(request.mode.timerName) running") { viewModel.dismissPersonalShield() }
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    }
                    if let error = viewModel.personalShieldError {
                        Text(error).font(AppTypography.body).foregroundStyle(AppColors.warning)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.activeWindDownBackground.ignoresSafeArea())
            .navigationTitle(request.action == .checklist
                ? (viewModel.personalShieldSession?.listTitle(at: Date()) ?? "My routine")
                : (request.morningIntent == nil ? request.confirmationTitle : "Early wake"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(request.action == .checklist ? "Done" : "Cancel") { viewModel.dismissPersonalShield() }
                }
            }
        }
        .id(request.id)
        .onChange(of: request.id) { _, _ in entry = "" }
    }
}

struct PersonalShieldChecklist: View {
    let session: PersonalShieldSession
    let date: Date
    let toggle: (UUID) -> Void

    var body: some View {
        let steps = session.visibleSteps(at: date)
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if session.isSleepTime(at: date) || (!steps.isEmpty && steps.allSatisfy(\.checked)) {
                Text(session.title(at: date)).font(AppTypography.title).foregroundStyle(AppColors.ink)
            }
            if session.isSleepTime(at: date) {
                Text("Put your phone away for the night.").font(AppTypography.body).foregroundStyle(AppColors.muted)
            } else if session.mode(at: date) == .additionalQuiet, !steps.isEmpty, steps.allSatisfy(\.checked) {
                Text("Keep this time phone-free, or end when you’re ready.").font(AppTypography.body).foregroundStyle(AppColors.muted)
            }
            if steps.isEmpty {
                Text(session.mode(at: date) == .additionalQuiet ? "No tasks added for this session." : "No activities added for this session.")
                    .font(AppTypography.body).foregroundStyle(AppColors.muted)
            } else {
                Text("\(steps.filter(\.checked).count) of \(steps.count) checked · optional")
                    .font(AppTypography.caption).foregroundStyle(AppColors.muted)
                ForEach(steps) { step in
                    Button { toggle(step.id) } label: {
                        HStack(alignment: .center, spacing: AppSpacing.md) {
                            Image(systemName: step.checked ? "checkmark.square.fill" : "square")
                                .foregroundStyle(AppColors.grass).font(AppTypography.title).accessibilityHidden(true)
                            Text(step.title).font(AppTypography.body).foregroundStyle(AppColors.ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, AppSpacing.sm)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(step.title)
                    .accessibilityValue(step.checked ? "Checked" : "Unchecked")
                    .accessibilityHint(step.checked ? "Double-tap to uncheck" : "Double-tap to check")
                }
            }
        }
    }
}

struct PersonalShieldPhraseForm: View {
    let request: PersonalShieldSheet
    @Binding var entry: String
    let confirm: () -> Void

    private var prompt: String {
        if !request.requiresTypedPhrase { return "Ready to start your morning?" }
        return request.action == .endSession ? "Type this phrase to confirm your choice" : "Type this phrase to continue"
    }

    private var canConfirm: Bool { !request.requiresTypedPhrase || PersonalShieldPhrase.matches(entry, phrase: request.phrase) }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(prompt).font(AppTypography.title).foregroundStyle(AppColors.ink)
            if request.requiresTypedPhrase {
                PixelCard {
                    Text(request.phrase).font(AppTypography.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                TextField("Type the phrase", text: $entry, axis: .vertical)
                    .font(AppTypography.body).textFieldStyle(PixelTextFieldStyle())
                    .textInputAutocapitalization(.sentences).autocorrectionDisabled()
                    .accessibilityLabel(prompt)
                    .onChange(of: entry) { _, value in entry = String(value.prefix(500)) }
            }
            Text(request.action == .endSession ? (request.endDetail ?? "Ends the session and unblocks selected apps.") : "Selected apps unlock for up to 5 minutes.")
                .font(AppTypography.body).foregroundStyle(AppColors.muted)
            Button(request.action == .endSession ? request.confirmationTitle : "Allow 5 minutes", action: confirm)
                .buttonStyle(PixelPrimaryButtonStyle())
                .disabled(!canConfirm)
                .opacity(canConfirm ? 1 : 0.5)
        }
    }
}

struct PersonalShieldActions: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Button(viewModel.personalShieldSession?.listButton(at: Date()) ?? (viewModel.activeScreenFreeMorning != nil ? "My morning" : viewModel.activeRunIsAdditionalQuiet ? "My tasks" : "My routine")) { viewModel.openPersonalShield(.checklist) }
                .buttonStyle(PixelPrimaryButtonStyle())
            Button("5-min access") { viewModel.openPersonalShield(.briefAccess) }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
            if let error = viewModel.personalShieldError, viewModel.personalShieldSheet == nil {
                Text(error).font(AppTypography.caption).foregroundStyle(AppColors.warning)
            }
        }
    }
}

#Preview("Routine · large text") {
    PersonalShieldChecklist(session: PersonalShieldSession(id: UUID(), owner: "preview",
        interval: DateInterval(start: .now, duration: 3600), role: .primaryWindDown,
        bedtime: nil, morningStart: nil, steps: [PersonalShieldStep(id: UUID(), title: "Brush my teeth", checked: true),
            PersonalShieldStep(id: UUID(), title: "Read 10 pages")], morningSteps: [], goal: nil, morningGoal: nil),
        date: .now, toggle: { _ in })
        .padding().background(AppColors.activeWindDownBackground).environment(\.dynamicTypeSize, .accessibility1)
}

#Preview("Phone Away · empty") {
    PersonalShieldChecklist(session: PersonalShieldSession(id: UUID(), owner: "preview",
        interval: DateInterval(start: .now, duration: 3600), role: .additionalQuiet,
        bedtime: nil, morningStart: nil, steps: [], morningSteps: [], goal: nil, morningGoal: nil), date: .now, toggle: { _ in })
        .padding().background(AppColors.activeWindDownBackground)
}

#Preview("Phrase · mismatch") {
    PersonalShieldPhraseForm(request: PersonalShieldSheet(sessionID: UUID(), owner: "preview", action: .briefAccess,
        phrase: "Read 10 pages", mode: .primaryWindDown), entry: .constant("Read"), confirm: {})
        .padding().background(AppColors.activeWindDownBackground)
}
