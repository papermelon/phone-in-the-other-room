import SwiftUI

struct FocusRunSetupView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var selectedPurpose: FocusRunPurpose = .focus

    private let durationOptions: [DurationOption] = [
        .init(minutes: 15, title: "15 min", subtitle: "Quick reset"),
        .init(minutes: 25, title: "25 min", subtitle: "Focus sprint"),
        .init(minutes: 45, title: "45 min", subtitle: "Deep work"),
        .init(minutes: 60, title: "60 min", subtitle: "Long run")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    CountingSheepTopBar(progress: viewModel.coordinator.progress)
                        .padding(.top, 8)

                    header
                    durationSection
                    purposeSection
                    rewardSection
                    WatchConnectedRow()

                    PrimaryGreenCTA(
                        title: "Send Phone Away",
                        subtitle: "Next: Put your phone in another room",
                        icon: "door.left.hand.open"
                    ) {
                        viewModel.requestStartRun()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }

            SetupBottomBar()
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
        }
        .background(AppColors.paper.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("Start Focus Run")
                .font(.system(size: 34, weight: .black, design: .monospaced))
                .foregroundStyle(AppColors.ink)
            Text("Choose your run and let's get started.")
                .font(pixelFont(.subheadline))
                .foregroundStyle(AppColors.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var durationSection: some View {
        SetupSection(number: 1, title: "Choose Duration", icon: "clock", subtitle: "How long will your phone stay away?") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(durationOptions) { option in
                    DurationChoiceCard(
                        option: option,
                        isSelected: !viewModel.customDurationSelected && viewModel.durationMinutes == option.minutes
                    ) {
                        viewModel.chooseDuration(minutes: option.minutes)
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    updateCustomDuration(by: 0)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "stopwatch")
                            .font(.system(size: 34, weight: .black))
                        Text("Custom")
                            .font(pixelFont(.subheadline))
                        Text("Set your own")
                            .font(pixelFont(.caption2))
                    }
                    .foregroundStyle(AppColors.ink)
                    .frame(width: 118, height: 126)
                    .background(customBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(customStroke)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Set custom duration")
                        .font(pixelFont(.caption))
                    HStack {
                        customStepperButton(systemImage: "minus") {
                            updateCustomDuration(by: -5)
                        }
                        Spacer()
                        Text("\(max(25, viewModel.durationMinutes)) min")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                        Spacer()
                        customStepperButton(systemImage: "plus") {
                            updateCustomDuration(by: 5)
                        }
                    }
                    .padding(10)
                    .background(AppColors.panel.opacity(0.70), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.stroke.opacity(0.12), lineWidth: 1))
                    Text("Min 25 min  -  Max 180 min")
                        .font(pixelFont(.caption2))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 126)
                .background(customBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(customStroke)
            }
        }
    }

    private var purposeSection: some View {
        SetupSection(number: 2, title: "What are you protecting?", icon: "scope", subtitle: "Choose your focus for this run.") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(FocusRunPurpose.allCases) { purpose in
                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            selectedPurpose = purpose
                        }
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: purpose.icon)
                                .font(.system(size: 32, weight: .black))
                                .foregroundStyle(purpose.tint)
                            Text(purpose.title)
                                .font(pixelFont(.subheadline))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .foregroundStyle(AppColors.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 106)
                        .background(selectedPurpose == purpose ? AppColors.grass.opacity(0.12) : AppColors.panel.opacity(0.68), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedPurpose == purpose ? AppColors.grass : AppColors.stroke.opacity(0.14), lineWidth: selectedPurpose == purpose ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var rewardSection: some View {
        SetupSection(number: 3, title: "Possible Reward", icon: "gift", subtitle: "Stay focused and earn rewards!") {
            HStack(spacing: 18) {
                CountingSheepMiniSheep(style: .cream)
                    .frame(width: 78, height: 64)
                VStack(spacing: 3) {
                    Text("+10%")
                        .font(.system(size: 25, weight: .black, design: .monospaced))
                    Text("Sheep Progress")
                        .font(pixelFont(.caption2))
                }
                Rectangle()
                    .fill(AppColors.stroke.opacity(0.15))
                    .frame(width: 1, height: 60)
                Image(systemName: "diamond.fill")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(AppColors.grassLight)
                VStack(spacing: 3) {
                    Text("+1")
                        .font(.system(size: 25, weight: .black, design: .monospaced))
                    Text("Collectible")
                        .font(pixelFont(.caption2))
                }
                Spacer()
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("Rewards are granted when you complete your run.")
                        .font(pixelFont(.caption2))
                        .lineSpacing(4)
                }
                .foregroundStyle(AppColors.muted)
                .padding(12)
                .frame(width: 170)
                .background(AppColors.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.stroke.opacity(0.12), lineWidth: 1))
            }
        }
    }

    private var customBackground: some ShapeStyle {
        AppColors.panel.opacity(viewModel.customDurationSelected ? 0.82 : 0.64)
    }

    private var customStroke: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(viewModel.customDurationSelected ? AppColors.grass : AppColors.stroke.opacity(0.14), lineWidth: viewModel.customDurationSelected ? 2 : 1)
    }

    private func customStepperButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AppColors.ink)
                .frame(width: 44, height: 44)
                .background(AppColors.panel, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppColors.stroke.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func updateCustomDuration(by delta: Int) {
        viewModel.customDurationSelected = true
        let startingMinutes = max(25, viewModel.durationMinutes)
        viewModel.durationMinutes = min(180, max(25, startingMinutes + delta))
        viewModel.durationSeconds = 0
        viewModel.updateSelectedDuration()
    }
}

private struct SetupSection<Content: View>: View {
    var number: Int
    var title: String
    var icon: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(number). \(title)")
                        .font(pixelFont(.title3))
                    Text(subtitle)
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.muted)
                }
            }
            content
        }
        .foregroundStyle(AppColors.ink)
        .padding(18)
        .background(AppColors.panel.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.stroke.opacity(0.16), lineWidth: 1))
    }
}

private struct DurationChoiceCard: View {
    var option: DurationOption
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 11) {
                Image(systemName: "stopwatch")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(isSelected ? AppColors.grass : AppColors.ink)
                Text(option.title)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                Text(option.subtitle)
                    .font(pixelFont(.caption2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
            .foregroundStyle(isSelected ? AppColors.grass : AppColors.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 128)
            .background(isSelected ? AppColors.grass.opacity(0.12) : AppColors.panel.opacity(0.68), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? AppColors.grass : AppColors.stroke.opacity(0.14), lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}

private struct DurationOption: Identifiable {
    var id: Int { minutes }
    var minutes: Int
    var title: String
    var subtitle: String
}

private enum FocusRunPurpose: String, CaseIterable, Identifiable {
    case focus
    case study
    case sleep
    case present

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .study: return "Study"
        case .sleep: return "Sleep"
        case .present: return "Be Present"
        }
    }

    var icon: String {
        switch self {
        case .focus: return "leaf.fill"
        case .study: return "book.fill"
        case .sleep: return "moon.stars.fill"
        case .present: return "heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .focus: return AppColors.grass
        case .study: return AppColors.wood
        case .sleep: return AppColors.lavender
        case .present: return Color(red: 0.88, green: 0.33, blue: 0.36)
        }
    }
}

private struct SetupBottomBar: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainAppTab.visibleTabs) { tab in
                setupTab(tab.title, icon: tab.icon, selected: tab == .home)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppColors.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.stroke.opacity(0.10), lineWidth: 1))
    }

    private func setupTab(_ title: String, icon: String, selected: Bool = false) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .black))
                .frame(height: 28)
            Text(title)
                .font(pixelFont(.caption2))
        }
        .foregroundStyle(selected ? AppColors.grass : AppColors.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.grass.opacity(0.18))
            }
        }
    }
}
