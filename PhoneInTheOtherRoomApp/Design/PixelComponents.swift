import SwiftUI
import UIKit

// MARK: - Shapes

struct PixelPanelShape: Shape {
    var cut: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

// MARK: - Cards

struct PixelAssetImage: View {
    var name: String
    var contentMode: ContentMode = .fit

    var body: some View {
        Image(name)
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .aspectRatio(contentMode: contentMode)
    }
}

struct PixelCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .foregroundStyle(AppColors.ink)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    PixelPanelShape(cut: 8)
                        .fill(AppColors.panel)
                    PixelPanelShape(cut: 8)
                        .stroke(AppColors.stroke.opacity(0.88), lineWidth: 2)
                }
            )
    }
}

// MARK: - Buttons

struct PixelPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(18)
            .background(AppColors.grass.opacity(configuration.isPressed ? 0.88 : 1))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(AppColors.stroke.opacity(0.9), lineWidth: 2))
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.99 : 1)
            .animation(reduceMotion ? nil : AppMotion.press, value: configuration.isPressed)
    }
}

struct PixelChipButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? .white : AppColors.ink)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(isSelected ? AppColors.grass : AppColors.panel)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(isSelected ? AppColors.stroke.opacity(0.9) : AppColors.stroke.opacity(0.35), lineWidth: isSelected ? 2 : 1.5)
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

// MARK: - Progress

enum PixelRailMarker {
    case star, none
}

struct PixelProgressRail: View {
    var progress: Double
    var marker: PixelRailMarker = .none
    var animated = true

    @State private var displayedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fillWidth = max(0, min(width, width * displayedProgress))
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(AppColors.panel)
                    .overlay(Rectangle().stroke(AppColors.stroke, lineWidth: 3))
                Rectangle()
                    .fill(AppColors.grass)
                    .frame(width: fillWidth)
                if marker == .star {
                    Image(systemName: "star.fill")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(AppColors.coin)
                        .shadow(color: AppColors.stroke, radius: 0, x: 1.5, y: 1.5)
                        .offset(x: max(0, min(width - 34, fillWidth - 17)), y: -9)
                }
            }
        }
        .frame(height: 18)
        .onAppear {
            guard animated, !reduceMotion else {
                displayedProgress = progress
                return
            }
            withAnimation(AppMotion.progress) {
                displayedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(reduceMotion ? nil : AppMotion.progress) {
                displayedProgress = newValue
            }
        }
    }
}

// MARK: - Navigation chrome

enum MainAppTab: String, CaseIterable, Identifiable {
    case home, nights, more

    static var visibleTabs: [MainAppTab] { allCases }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .nights: return "Nights"
        case .more: return "More"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .nights: return "moon.stars.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }
}

struct PixelBottomBar: View {
    @Binding var selectedTab: MainAppTab
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainAppTab.visibleTabs) { tab in
                Button {
                    withAnimation(reduceMotion ? nil : AppMotion.navigation) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3.weight(.black))
                            .symbolEffect(.bounce, value: selectedTab == tab)
                        Text(tab.title)
                            .font(pixelFont(.caption2))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == tab ? AppColors.grass : AppColors.ink)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppColors.grass.opacity(0.18))
                                .matchedGeometryEffect(id: "tabIndicator", in: selection)
                        }
                    }
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: selectedTab)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            AppColors.panel
                .shadow(color: AppColors.stroke.opacity(0.08), radius: 0, x: 0, y: -1)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AppColors.stroke.opacity(0.12))
                        .frame(height: 1)
                }
        )
    }
}

// MARK: - Counting Sheep mockup chrome

struct CountingSheepTopBar: View {
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "moon.stars.fill")
                .foregroundStyle(AppColors.lavender)
            Text("Counting Sheep")
                .font(pixelFont(.headline))
                .foregroundStyle(AppColors.ink)
            Spacer()
        }
        .frame(minHeight: 42)
    }
}

struct PixelIconButton: View {
    var systemImage: String
    var size: CGFloat = 50

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.52, weight: .black))
            .foregroundStyle(AppColors.ink)
            .frame(width: size, height: size * 0.86)
            .background(AppColors.panel.opacity(0.35), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppColors.stroke, lineWidth: 2.5))
    }
}

struct CountingSheepBottomBar: View {
    @Binding var selectedTab: MainAppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainAppTab.visibleTabs) { tab in
                Button {
                    withAnimation(reduceMotion ? nil : AppMotion.selection) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 25, weight: .black))
                            .frame(height: 28)
                        Text(tab.title)
                            .font(pixelFont(.caption2))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .foregroundStyle(selectedTab == tab ? AppColors.grass : AppColors.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppColors.grass.opacity(0.18))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            AppColors.panel.opacity(0.96),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.stroke.opacity(0.10), lineWidth: 1))
        .shadow(color: AppColors.stroke.opacity(0.10), radius: 10, x: 0, y: -2)
    }
}

struct ProgressStarBar: View {
    var progress: Double
    var leftLabel = "0 min"
    var rightLabel = "60 min"

    var body: some View {
        VStack(spacing: 8) {
            PixelProgressRail(progress: progress, marker: .star)
                .frame(height: 20)
            HStack {
                Text(leftLabel)
                Spacer()
                Text(rightLabel)
            }
            .font(pixelFont(.caption))
            .foregroundStyle(AppColors.ink)
        }
    }
}

struct PrimaryGreenCTA: View {
    var title: String
    var subtitle: String
    var icon: String
    var assetName: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if let assetName {
                    PixelAssetImage(name: assetName)
                        .frame(width: 54, height: 54)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(AppColors.wood)
                        .frame(width: 54, height: 54)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(AppTypography.title)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(pixelFont(.caption))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 86)
            .background(
                LinearGradient(colors: [AppColors.grass, Color(red: 0.26, green: 0.48, blue: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.stroke, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

struct PixelMetricCard: View {
    var title: String
    var icon: String
    var assetName: String? = nil
    var value: String
    var detail: String
    var accent: Color = AppColors.grass
    var footer: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(pixelFont(.caption))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            if let assetName {
                PixelAssetImage(name: assetName)
                    .frame(height: 48)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(accent)
                    .frame(height: 42)
            }
            Text(value)
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(detail)
                .font(pixelFont(.caption2))
                .foregroundStyle(accent == AppColors.grass ? AppColors.grass : AppColors.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
            if let footer {
                Text(footer)
                    .font(pixelFont(.caption2))
                    .foregroundStyle(AppColors.muted)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(AppColors.ink)
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 145)
        .background(AppColors.panel.opacity(0.90), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.stroke.opacity(0.18), lineWidth: 1))
    }
}

struct WeeklyComparisonCard: View {
    var focusValues: [Double]
    var screenValues: [Double]
    var focusAverage: String
    var screenAverage: String

    private let days = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(pixelFont(.headline))
            HStack(alignment: .top, spacing: 14) {
                chartBlock(icon: "moon.stars.fill", title: "Quiet Bookends (avg.)", value: focusAverage, tint: AppColors.grass, values: focusValues)
                Rectangle()
                    .fill(AppColors.stroke.opacity(0.12))
                    .frame(width: 1, height: 130)
                chartBlock(icon: "iphone", title: "Screen Time (avg.)", value: screenAverage, tint: AppColors.lavender, values: screenValues)
            }
        }
        .padding(16)
        .background(AppColors.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.stroke.opacity(0.18), lineWidth: 1))
    }

    private func chartBlock(icon: String, title: String, value: String, tint: Color, values: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon)
                    .font(.title3.weight(.black))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(pixelFont(.caption2))
                    Text(value)
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                }
            }
            HStack(alignment: .bottom, spacing: 9) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill((values[safe: index] ?? 0) == 0 ? Color.gray.opacity(0.35) : tint)
                            .frame(width: 14, height: max(12, CGFloat(values[safe: index] ?? 0) * 48))
                        Text(day)
                            .font(pixelFont(.caption2))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AchievementRow: View {
    var title: String
    var detail: String
    var icon: String
    var assetName: String? = nil
    var progress: Double
    var progressLabel: String
    var trailingIcon = true

    var body: some View {
        HStack(spacing: 14) {
            if let assetName {
                PixelAssetImage(name: assetName)
                    .frame(width: 72, height: 72)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(icon == "medal.fill" ? AppColors.coin : AppColors.grass)
                    .frame(width: 72, height: 72)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(pixelFont(.subheadline))
                Text(detail)
                    .font(pixelFont(.caption2))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                HStack(spacing: 10) {
                    ProgressBar(progress: progress, tint: AppColors.grass)
                    Text(progressLabel)
                        .font(pixelFont(.caption2))
                        .frame(width: 48, alignment: .trailing)
                }
            }
            if trailingIcon {
                Image(systemName: "chevron.right")
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppColors.muted)
            }
        }
        .padding(14)
        .background(AppColors.panel.opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.stroke.opacity(0.18), lineWidth: 1))
    }
}

struct WatchConnectedRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "applewatch")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(AppColors.ink)
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Watch Connected")
                    .font(pixelFont(.subheadline))
                Text("We'll check that your phone stays away.")
                    .font(pixelFont(.caption2))
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(AppColors.grass)
        }
        .padding(14)
        .background(AppColors.panel.opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.stroke.opacity(0.16), lineWidth: 1))
    }
}

struct CountingSheepMiniSheep: View {
    enum Style {
        case white, cream, black
    }

    var style: Style = .white

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Ellipse()
                    .fill(AppColors.stroke.opacity(0.12))
                    .frame(width: size * 0.72, height: size * 0.16)
                    .offset(y: size * 0.32)
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(bodyColor)
                        .overlay(Circle().stroke(AppColors.stroke.opacity(0.45), lineWidth: 0.7))
                        .frame(width: size * 0.25, height: size * 0.25)
                        .offset(x: CGFloat(index % 3 - 1) * size * 0.15 - size * 0.08, y: CGFloat(index / 3) * size * 0.14 - size * 0.10)
                }
                RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                    .fill(bodyColor)
                    .overlay(RoundedRectangle(cornerRadius: size * 0.16).stroke(AppColors.stroke.opacity(0.40), lineWidth: 0.8))
                    .frame(width: size * 0.58, height: size * 0.36)
                    .offset(x: -size * 0.08)
                Circle()
                    .fill(headColor)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .offset(x: size * 0.25, y: -size * 0.01)
                HStack(spacing: size * 0.18) {
                    Capsule().fill(legColor).frame(width: size * 0.06, height: size * 0.25)
                    Capsule().fill(legColor).frame(width: size * 0.06, height: size * 0.25)
                }
                .offset(x: -size * 0.08, y: size * 0.25)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var bodyColor: Color {
        switch style {
        case .white: return .white
        case .cream: return Color(red: 0.98, green: 0.78, blue: 0.46)
        case .black: return Color(red: 0.10, green: 0.10, blue: 0.10)
        }
    }

    private var headColor: Color {
        switch style {
        case .white: return AppColors.ink
        case .cream: return Color(red: 0.90, green: 0.63, blue: 0.28)
        case .black: return Color(red: 0.06, green: 0.06, blue: 0.06)
        }
    }

    private var legColor: Color {
        style == .cream ? Color(red: 0.39, green: 0.22, blue: 0.12) : headColor
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Shared UI bits

struct SpeechBubble: View {
    var text: String

    var body: some View {
        Text(text)
            .font(PixelTypography.title(.subheadline))
            .multilineTextAlignment(.center)
            .foregroundStyle(AppColors.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                PixelPanelShape(cut: 10)
                    .fill(AppColors.panel)
                    .overlay(PixelPanelShape(cut: 10).stroke(AppColors.stroke, lineWidth: 3))
            )
    }
}

struct PixelSegmentedPicker<T: Hashable & Identifiable>: View where T: CaseIterable, T.AllCases: RandomAccessCollection {
    let title: String
    @Binding var selection: T
    var items: [T]? = nil
    let label: (T) -> String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items ?? Array(T.allCases)) { item in
                Button {
                    withAnimation(reduceMotion ? nil : AppMotion.selection) {
                        selection = item
                    }
                } label: {
                    Text(label(item))
                        .font(pixelFont(.caption))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: selection.id == item.id))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

struct PixelStatsMetricRow: View {
    var icon: String
    var title: String
    var value: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(AppColors.grass, in: RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(AppColors.stroke, lineWidth: 2))
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(PixelTypography.title(.subheadline))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Text(value)
                        .font(pixelFont(.subheadline))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: 122, alignment: .trailing)
                }
                Text(detail)
                    .font(PixelTypography.title(.caption2))
                    .foregroundStyle(AppColors.muted)
            }
        }
    }
}

struct IntegrationSetupCard: View {
    var title: String
    var detail: String
    var icon: String
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        PixelCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2.weight(.black))
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(pixelFont(.headline))
                    Text(detail)
                        .font(PixelTypography.title(.caption2))
                        .foregroundStyle(AppColors.muted)
                    Button(action: action) {
                        Text(actionTitle)
                            .font(pixelFont(.caption2))
                            .foregroundStyle(AppColors.grass)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(PixelPanelShape(cut: 5).stroke(AppColors.stroke, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct PingPulseOverlay: View {
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title2.weight(.bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Phone heard the whistle")
                        .font(AppTypography.headline)
                    Text("Ping sound and haptic sent.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.ink.opacity(0.64))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(AppColors.ink)
            .padding(16)
            .background(AppColors.amber, in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.stroke, lineWidth: 2)
            )
            .shadow(color: AppColors.stroke.opacity(0.25), radius: 0, x: 0, y: 6)
            .padding(.horizontal, 22)
            .padding(.top, 10)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

struct IdleBobModifier: ViewModifier {
    @State private var bobbing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: reduceMotion ? 0 : (bobbing ? -4 : 2))
            .animation(
                reduceMotion ? nil : AppMotion.ambient,
                value: bobbing
            )
            .onAppear {
                if !reduceMotion { bobbing = true }
            }
            .onChange(of: reduceMotion) { _, shouldReduce in
                bobbing = !shouldReduce
            }
    }
}

extension View {
    func idleBob() -> some View {
        modifier(IdleBobModifier())
    }
}

struct FocusSessionStartBar: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Wind Down")
                        .font(PixelTypography.title(.title3))
                    Text("Tuck your phone in for the night")
                        .font(PixelTypography.title(.caption))
                        .opacity(0.9)
                }
                Spacer()
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 32, weight: .bold))
            }
        }
        .buttonStyle(PixelPrimaryButtonStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColors.paper)
    }
}

struct AssetOrSymbolImage: View {
    var assetName: String
    var systemImage: String
    var size: CGFloat = 120

    var body: some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: size, height: size)
        } else if UIImage(named: "OllieMascot") != nil, assetName.contains("dog") || assetName.contains("Ollie") {
            Image("OllieMascot")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(AppColors.grass)
        }
    }
}
