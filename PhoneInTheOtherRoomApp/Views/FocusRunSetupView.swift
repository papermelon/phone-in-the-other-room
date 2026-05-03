import SwiftUI

struct FocusRunSetupView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        VStack(spacing: 16) {
            GamePanelView(title: "Run length") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose how long Ollie guards your focus.")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        PresetDurationButton(title: "Quick", detail: "3 min", isSelected: !viewModel.customDurationSelected && viewModel.durationMinutes == 3 && viewModel.durationSeconds == 0) {
                            viewModel.chooseDuration(minutes: 3)
                        }
                        PresetDurationButton(title: "Short", detail: "10 min", isSelected: !viewModel.customDurationSelected && viewModel.durationMinutes == 10 && viewModel.durationSeconds == 0) {
                            viewModel.chooseDuration(minutes: 10)
                        }
                        PresetDurationButton(title: "Focus", detail: "25 min", isSelected: !viewModel.customDurationSelected && viewModel.durationMinutes == 25 && viewModel.durationSeconds == 0) {
                            viewModel.chooseDuration(minutes: 25)
                        }
                        PresetDurationButton(title: "Long", detail: "60 min", isSelected: !viewModel.customDurationSelected && viewModel.durationMinutes == 60 && viewModel.durationSeconds == 0) {
                            viewModel.chooseDuration(minutes: 60)
                        }
                    }

                    Button {
                        viewModel.chooseCustomDuration()
                    } label: {
                        HStack {
                            Image(systemName: "timer")
                            Text("Custom duration")
                            Spacer()
                            Text(viewModel.selectedDurationLabel)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(viewModel.customDurationSelected ? OlliePalette.success.opacity(0.42) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(viewModel.customDurationSelected ? OlliePalette.success.opacity(0.85) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }

            GamePanelView(title: "Watch companion") {
                Label {
                    Text("Open Phone in the Other Room on your Apple Watch before starting. The iPhone will also send a reminder when the run begins.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                } icon: {
                    Image(systemName: "applewatch")
                        .foregroundStyle(OlliePalette.amber)
                }
            }

            GamePanelView(title: "Shortcut") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create a Shortcut with Apple’s Focus action, then add Phone in the Other Room’s Start Focus Run action.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                    Text("Example: Start Focus Run -> Set Do Not Disturb -> Open App.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                    if !viewModel.focusGuidance.isEmpty {
                        Text(viewModel.focusGuidance)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(OlliePalette.amber)
                    }
                }
            }

            Button {
                viewModel.requestStartRun()
            } label: {
                Label("Send Ollie Out", systemImage: "figure.run")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PixelButtonStyle(tint: OlliePalette.brown))
        }
        .sheet(isPresented: $viewModel.showCustomDurationPicker) {
            CustomDurationPickerView()
                .environmentObject(viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct PresetDurationButton: View {
    var title: String
    var detail: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.64))
                Text(detail)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? OlliePalette.success.opacity(0.42) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? OlliePalette.success.opacity(0.85) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CustomDurationPickerView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                HStack(spacing: 0) {
                    Picker("Minutes", selection: $viewModel.durationMinutes) {
                        ForEach(0...180, id: \.self) { minute in
                            Text("\(minute) min").tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Picker("Seconds", selection: $viewModel.durationSeconds) {
                        ForEach(0...59, id: \.self) { second in
                            Text("\(second) sec").tag(second)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .frame(height: 180)
                .onChange(of: viewModel.durationMinutes) { _, _ in viewModel.updateSelectedDuration() }
                .onChange(of: viewModel.durationSeconds) { _, _ in viewModel.updateSelectedDuration() }

                Text("Selected: \(viewModel.selectedDurationLabel)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Custom Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.updateSelectedDuration()
                        dismiss()
                    }
                }
            }
        }
    }
}
