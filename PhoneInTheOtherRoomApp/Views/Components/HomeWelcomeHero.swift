import SwiftUI

/// The Home welcome is intentionally a small personal scene, not a second
/// dashboard card. Ollie remains the emotional lead before the practical
/// Wind Down controls begin.
struct HomeWelcomeHero: View {
    var title: String = "Welcome home."
    var subtitle: String = "Ollie saved you a quiet spot."
    /// The equipped Farm cosmetic follows Ollie into the shared Home renderer.
    var accessoryItemID: String? = nil
    var scrollViewportSize = CGSize.zero

    // Art keeps a fixed canvas so larger text does not turn transparent pixels
    // into extra vertical whitespace. The greeting itself remains Dynamic Type.
    private let sceneHeight: CGFloat = 190
    @State private var isInViewport = false
    @State private var artFrame = CGRect.null

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack(alignment: .bottom) {
                HomeWindowImage(isInViewport: isInViewport)
                    .frame(width: 56, height: 52)
                    .offset(x: 94, y: -122)
                    .accessibilityHidden(true)

                PixelAssetImage(name: AssetSlot.Home.plant)
                    .frame(width: 42, height: 60)
                    .offset(x: -88, y: -28)
                    .accessibilityHidden(true)

                HomeOllieIdleView(
                    presentation: .onboardingHero,
                    accessoryItemID: accessoryItemID,
                    isMotionEnabled: isInViewport
                )
                    .frame(width: 190, height: 190)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: sceneHeight)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            updateViewportVisibility(
                                with: proxy.frame(in: .named(HomeScrollViewportCoordinateSpace.name))
                            )
                        }
                        .onChange(of: proxy.frame(in: .named(HomeScrollViewportCoordinateSpace.name))) { _, frame in
                            updateViewportVisibility(with: frame)
                        }
                }
            }

            Text(title)
                .font(AppTypography.display(26))
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .onChange(of: scrollViewportSize) { _, _ in
            updateViewportVisibility()
        }
        .onAppear { updateViewportVisibility() }
        .onDisappear { isInViewport = false }
    }

    private func updateViewportVisibility(with measuredArtFrame: CGRect? = nil) {
        if let measuredArtFrame {
            artFrame = measuredArtFrame
        }
        let viewport = CGRect(origin: .zero, size: scrollViewportSize)
        let updatedVisibility = !scrollViewportSize.equalTo(.zero) && artFrame.intersects(viewport)
        isInViewport = updatedVisibility
    }
}

private struct HomeWindowImage: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var displayedDate = Date()
    var isInViewport: Bool

    var body: some View {
        HomeClockWindow(phase: HomeWindowPhase.phase(at: displayedDate))
            .onAppear { displayedDate = Date() }
            .task(id: scenePhase == .active && isInViewport) {
                guard scenePhase == .active, isInViewport else { return }
                while !Task.isCancelled {
                    let now = Date()
                    displayedDate = now
                    let next = Calendar.autoupdatingCurrent
                        .dateInterval(of: .minute, for: now)?.end
                        ?? now.addingTimeInterval(60)
                    let delay = max(0.02, next.timeIntervalSince(now))
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        return
                    }
                }
            }
    }

}

/// A small clock-aware ornament. It stays code-native so the Home scene can
/// change with local time without depending on duplicate day/night sprite art.
private struct HomeClockWindow: View {
    var phase: HomeWindowPhase

    private var skyStyle: AnyShapeStyle {
        switch phase {
        case .day:
            AnyShapeStyle(AppColors.sky)
        case .night:
            AnyShapeStyle(LinearGradient(
                colors: [AppColors.homeWindowNightSkyTop, AppColors.homeWindowNightSkyBottom],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(AppColors.bark)

            Rectangle()
                .fill(AppColors.wood)
                .padding(2)

            Rectangle()
                .fill(skyStyle)
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .padding(.bottom, 10)
                .overlay(alignment: phase == .day ? .topTrailing : .topLeading) {
                    celestialBody
                        .padding(.horizontal, 10)
                        .padding(.top, 9)
                }
                .overlay {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle().fill(AppColors.wood.opacity(0.9)).frame(height: 2)
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle().fill(AppColors.wood.opacity(0.9)).frame(width: 2)
                        Spacer(minLength: 0)
                    }
                }
                .clipped()

            Rectangle()
                .fill(AppColors.floor)
                .frame(height: 7)
                .padding(.horizontal, 2)
                .offset(y: 26)
        }
        .aspectRatio(66 / 60, contentMode: .fit)
    }

    @ViewBuilder
    private var celestialBody: some View {
        switch phase {
        case .day:
            Circle()
                .fill(AppColors.amber)
                .frame(width: 10, height: 10)
        case .night:
            Image(systemName: "moon.fill")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppColors.wool)
                .frame(width: 12, height: 12)
        }
    }
}

private struct HomeClockWindowPreview: View {
    @State private var date: Date
    private let calendar: Calendar
    private let timeZone: TimeZone

    init(hour: Int) {
        var previewCalendar = Calendar(identifier: .gregorian)
        let previewTimeZone = TimeZone(secondsFromGMT: 0)!
        previewCalendar.timeZone = previewTimeZone
        calendar = previewCalendar
        timeZone = previewTimeZone
        _date = State(initialValue: previewCalendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 28,
            hour: hour
        ))!)
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HomeClockWindow(phase: HomeWindowPhase.phase(
                at: date,
                calendar: calendar,
                timeZone: timeZone
            ))
            .frame(width: 66, height: 60)

            DatePicker("Preview time", selection: $date, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
        .padding()
        .background(AppColors.paper)
    }
}

#Preview("Personal welcome") {
    HomeWelcomeHero(scrollViewportSize: CGSize(width: 390, height: 700))
        .padding()
        .background(AppColors.paper)
}

#Preview("Day window") {
    HomeClockWindowPreview(hour: 9)
}

#Preview("Night window") {
    HomeClockWindowPreview(hour: 21)
}
