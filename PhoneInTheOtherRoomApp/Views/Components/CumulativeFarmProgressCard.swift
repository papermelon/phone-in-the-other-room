import SwiftUI

struct CumulativeFarmProgressCard: View {
    let credit: CumulativeFarmCredit
    var accessoryItemID: String? = nil
    @State private var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(credit: CumulativeFarmCredit, accessoryItemID: String? = nil, initiallyExpanded: Bool = false) {
        self.credit = credit
        self.accessoryItemID = accessoryItemID
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    private var presentation: SearchTrailPresentation { SearchTrailPresentation(credit: credit) }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Button(action: toggleExpansion) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                            Text("Ollie's next search")
                                .font(pixelFont(.headline))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(pixelFont(.caption))
                        }
                        Label(isExpanded ? "Your Wind Downs add up across nights." : "Continue the trail tonight.",
                              systemImage: "moon.stars.fill")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        SearchTrailDrawing(fraction: presentation.fraction, expanded: isExpanded,
                                           accessoryItemID: accessoryItemID)
                            .dynamicTypeSize(.medium)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: SearchTrailLayout.headerHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search-trail-disclosure")
                .accessibilityLabel("Ollie's next search, Wind Down")
                .accessibilityValue("\(isExpanded ? "Expanded" : "Collapsed"). \(presentation.summary)")
                .accessibilityHint(isExpanded ? "Hide search details" : "Show progress and search rules")

                if isExpanded {
                    details.accessibilityElement(children: .contain)
                    Button(action: toggleExpansion) {
                        Label("Show less", systemImage: "chevron.up")
                            .font(pixelFont(.caption))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.grass)
                    .accessibilityLabel("Collapse Ollie's next search")
                    .accessibilityIdentifier("search-trail-collapse")
                }
            }
        }
    }

    private func toggleExpansion() {
        withAnimation(reduceMotion ? nil : AppMotion.stateChange) { isExpanded.toggle() }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(presentation.summary).font(pixelFont(.body))
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                detailRow("Wind Down time · \(presentation.time)", value: presentation.timeShare)
                if let bonus = presentation.bonusShare {
                    detailRow("Bedtime bonus", value: bonus)
                }
            }
            Text("These are the contributions still on this trail.")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.secondaryText)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("7 hours of Wind Down time fills a trail.")
                Text("Start within 15 minutes of your planned Wind Down and continue to bedtime for a 20% trail bonus, once a night.")
                Text("Time and bonuses carry into the next trail. Brief Access time is excluded.")
                Text("A full trail opens a search. Ollie may find a sheep or a clue.")
            }
            .font(pixelFont(.caption))
            .foregroundStyle(AppColors.secondaryText)
            Divider()
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                detailRow("Phone Away", value: presentation.phoneAway)
                ProgressView(value: presentation.phoneAwayFraction)
                    .tint(AppColors.grass)
                    .accessibilityHidden(true)
                Text("Its own trail. Every 100 credited minutes opens a search.")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func detailRow(_ title: String, value: String) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: AppSpacing.xs))
        return layout {
            Text(title).frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
        }
        .font(pixelFont(.caption))
        .accessibilityElement(children: .combine)
    }
}

private struct SearchTrailDrawing: View {
    let fraction: Double
    let expanded: Bool
    let accessoryItemID: String?

    var body: some View {
        GeometryReader { geometry in
            let inset = SearchTrailLayout.ollieSize / 2
            let width = max(0, geometry.size.width - inset * 2)
            let baseline = expanded ? geometry.size.height * 0.8 : geometry.size.height - AppSpacing.xs
            ZStack(alignment: .topLeading) {
                if expanded {
                    PixelAssetImage(name: AssetSlot.Farm.sharedMeadowDusk, contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(0.7)
                }
                // Use the same path for the filled trail and Ollie's position.
                let points = (0...100).map { index in
                    let progress = Double(index) / 100
                    return CGPoint(x: inset + width * progress,
                        y: baseline + sin(progress * .pi * 4) * AppSpacing.xxs)
                }
                Path { path in path.addLines(points) }
                    .stroke(AppColors.secondaryText, style: StrokeStyle(
                        lineWidth: SearchTrailLayout.lineWidth, lineCap: .round,
                        dash: [AppSpacing.xxs, AppSpacing.xs]))
                Path { path in
                    path.addLines(Array(points.prefix(Int(fraction * 100) + 1)))
                }
                .stroke(AppColors.grass, style: StrokeStyle(
                    lineWidth: SearchTrailLayout.lineWidth, lineCap: .round))
                OllieDressedSprite(assetName: AssetSlot.Dog.idle, accessoryItemID: accessoryItemID)
                    .frame(width: SearchTrailLayout.ollieSize, height: SearchTrailLayout.ollieSize)
                    .position(x: inset + width * fraction,
                              y: max(inset, baseline + sin(fraction * .pi * 4) * AppSpacing.xxs - inset))
                Image(systemName: "magnifyingglass")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.ink)
                    .padding(AppSpacing.xxs)
                    .background(AppColors.panel, in: Circle())
                    .position(x: inset + width, y: min(baseline, geometry.size.height - AppSpacing.md))
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
        .frame(height: expanded ? SearchTrailLayout.expandedHeight : SearchTrailLayout.foldedHeight)
    }
}

#Preview("Folded") {
    CumulativeFarmProgressCard(credit: CumulativeFarmCredit(windDownSeconds: 256 * 60, phoneAwaySeconds: 5 * 60))
        .padding().background(AppColors.background)
}

#Preview("Expanded with bedtime bonus") {
    ScrollView {
        CumulativeFarmProgressCard(credit: CumulativeFarmCredit(windDownSeconds: 256 * 60,
            phoneAwaySeconds: 5 * 60, bedtimeBonus: BedtimeSearchBonus(remainingSearchSeconds: 5040)),
            initiallyExpanded: true).padding()
    }.background(AppColors.background)
}

#Preview("Empty trail, large text") {
    ScrollView {
        CumulativeFarmProgressCard(credit: CumulativeFarmCredit(), initiallyExpanded: true).padding()
    }.dynamicTypeSize(.accessibility3).background(AppColors.background)
}
