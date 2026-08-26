import SwiftUI

private struct WatchCompactLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var watchCompactLayout: Bool {
        get { self[WatchCompactLayoutKey.self] }
        set { self[WatchCompactLayoutKey.self] = newValue }
    }
}

enum WatchTheme {
    static let nightTop = Color(red: 0.035, green: 0.075, blue: 0.075)
    static let nightBottom = Color(red: 0.02, green: 0.035, blue: 0.04)
    static let cream = Color(red: 0.96, green: 0.91, blue: 0.78)
    static let mist = Color(red: 0.72, green: 0.78, blue: 0.72)
    static let moss = Color(red: 0.31, green: 0.55, blue: 0.40)
    static let mossPressed = Color(red: 0.24, green: 0.45, blue: 0.32)
    static let amber = Color(red: 0.84, green: 0.65, blue: 0.34)
    static let panel = Color.white.opacity(0.075)
    static let panelBorder = Color.white.opacity(0.11)
}

struct WatchScreen<Content: View>: View {
    private let content: (Bool) -> Content

    init(@ViewBuilder content: @escaping (Bool) -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WatchTheme.nightTop, WatchTheme.nightBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    content(geometry.size.width < 185)
                        .environment(\.watchCompactLayout, geometry.size.width < 185)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(WatchTheme.cream)
    }
}

struct WatchStatusPill: View {
    @Environment(\.watchCompactLayout) private var usesCompactLayout

    let title: String
    let systemImage: String
    var tint = WatchTheme.moss

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .multilineTextAlignment(.center)
            .padding(.horizontal, usesCompactLayout ? 6 : 10)
            .padding(.vertical, usesCompactLayout ? 5 : 6)
            .background(WatchTheme.panel, in: Capsule())
            .overlay(Capsule().stroke(WatchTheme.panelBorder, lineWidth: 1))
    }
}

struct WatchDetailCard: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(WatchTheme.cream)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(WatchTheme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(WatchTheme.panelBorder, lineWidth: 1)
            )
    }
}

struct WatchPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                configuration.isPressed ? WatchTheme.mossPressed : WatchTheme.moss,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .contentShape(Rectangle())
    }
}

struct WatchQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(WatchTheme.mist)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(WatchTheme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(WatchTheme.panelBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.65 : 1)
            .contentShape(Rectangle())
    }
}
