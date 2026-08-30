import SwiftUI

struct WindDownGuidanceSourcesView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    var onboardingDraft: Binding<OnboardingDraft>? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("SOURCES")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("The library behind these ideas")
                        .font(AppTypography.display(30))
                    Text("These bundled notes are here to show context. A source may be background reading rather than support for a particular idea.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                }

                ForEach([WindDownGuidanceSourceKind.external, .internalReference], id: \.rawValue) { kind in
                    sourceSection(kind)
                }
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("All sources")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sourceSection(_ kind: WindDownGuidanceSourceKind) -> some View {
        let sources = WindDownGuidanceSourceRegistry.sources(of: kind)
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(kind.title)
                .font(AppTypography.headline)
            ForEach(sources) { source in
                NavigationLink {
                    WindDownGuidanceSourceDetailView(
                        source: source,
                        onboardingDraft: onboardingDraft
                    )
                    .environmentObject(viewModel)
                } label: {
                    sourceRow(source)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sourceRow(_ source: WindDownGuidanceSource) -> some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(source.title)
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(AppColors.ink)
                    Text(source.organization)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    if source.isBackgroundContext {
                        Text("Background context")
                            .font(AppTypography.caption.weight(.semibold))
                            .foregroundStyle(AppColors.grass)
                    }
                }
                Spacer(minLength: AppSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.grass)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows source notes")
    }
}

struct WindDownGuidanceSourceDetailView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let source: WindDownGuidanceSource
    var onboardingDraft: Binding<OnboardingDraft>? = nil

    private var relatedIdeas: [WindDownGuidanceItem] {
        WindDownGuidanceLibrary.items(referencingSourceID: source.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(source.kind == .external ? "EXTERNAL REFERENCE" : "COUNTING SHEEP DESIGN NOTE")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(source.title)
                        .font(AppTypography.display(30))
                    Text(source.organization)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("WHY IT IS HERE")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text(source.editorialNote)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondaryText)
                        if source.isBackgroundContext {
                            Text("This is background context for the library. It does not support a specific idea in Counting Sheep.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                        }
                    }
                }

                if let url = source.url {
                    Link(destination: url) {
                        Label("Open external source", systemImage: "arrow.up.right.square")
                            .font(AppTypography.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else {
                    Text("This is an internal Counting Sheep design note, not an external source or scientific evidence.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }

                relatedIdeasSection
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Source details")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var relatedIdeasSection: some View {
        if relatedIdeas.isEmpty {
            Text(source.isBackgroundContext
                ? "This background record is available for context only."
                : "No individual idea cites this source right now.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("IDEAS THAT CITE THIS SOURCE")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                ForEach(relatedIdeas) { item in
                    NavigationLink {
                        WindDownGuidanceDetailView(item: item, onboardingDraft: onboardingDraft)
                            .environmentObject(viewModel)
                    } label: {
                        Text(item.title)
                    }
                    .font(AppTypography.body.weight(.semibold))
                    .foregroundStyle(AppColors.grass)
                    .frame(minHeight: 44, alignment: .leading)
                }
            }
        }
    }
}

#Preview("All sources") {
    NavigationStack {
        WindDownGuidanceSourcesView()
            .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
}

#Preview("Background source") {
    NavigationStack {
        WindDownGuidanceSourceDetailView(source: WindDownGuidanceSourceRegistry.sources[3])
            .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
}
