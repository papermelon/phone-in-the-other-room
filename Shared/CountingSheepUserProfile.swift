import Foundation

/// The small, curated identity a member may show inside an invited Slumber Party.
/// It deliberately stores identifiers only; local Farm ownership never crosses this boundary.
struct CountingSheepPublicPresentation: Codable, Equatable, Sendable {
    var skinToneID: String
    var hairStyleID: String
    var shepherdOutfitID: String
    var shepherdAccessoryID: String
    var ollieOrnamentID: String
    var featuredSheepDefinitionID: String
    var pastureThemeID: String

    static let defaultValue = Self(
        skinToneID: ShepherdSkinTone.warm.rawValue,
        hairStyleID: ShepherdHairStyle.waves.rawValue,
        shepherdOutfitID: "none",
        shepherdAccessoryID: "none",
        ollieOrnamentID: "none",
        featuredSheepDefinitionID: "none",
        pastureThemeID: "pasture_meadow"
    )

    func isAllowlisted() -> Bool {
        CountingSheepPublicPresentationAllowlist.skinToneIDs.contains(skinToneID)
            && CountingSheepPublicPresentationAllowlist.hairStyleIDs.contains(hairStyleID)
            && CountingSheepPublicPresentationAllowlist.shepherdOutfitIDs.contains(shepherdOutfitID)
            && CountingSheepPublicPresentationAllowlist.shepherdAccessoryIDs.contains(shepherdAccessoryID)
            && CountingSheepPublicPresentationAllowlist.ollieOrnamentIDs.contains(ollieOrnamentID)
            && CountingSheepPublicPresentationAllowlist.featuredSheepDefinitionIDs.contains(featuredSheepDefinitionID)
            && CountingSheepPublicPresentationAllowlist.pastureThemeIDs.contains(pastureThemeID)
    }
}

enum CountingSheepPublicPresentationAllowlist {
    static let skinToneIDs = Set(ShepherdSkinTone.allCases.map(\.rawValue))
    static let hairStyleIDs = Set(ShepherdHairStyle.allCases.map(\.rawValue))
    static let shepherdOutfitIDs: Set<String> = ["none", "shepherd_moss_coat", "shepherd_moon_coat", "shepherd_field_overalls", "shepherd_star_keeper_cloak"]
    static let shepherdAccessoryIDs: Set<String> = ["none", "shepherd_wool_hat", "shepherd_clover_headscarf", "shepherd_moon_beanie"]
    static let ollieOrnamentIDs: Set<String> = ["none", "ollie_moss_bandana", "ollie_moon_kerchief", "ollie_brass_bell", "ollie_clover_collar", "ollie_sunrise_scarf", "ollie_star_keeper_cape"]
    static let featuredSheepDefinitionIDs = Set(SheepCatalog.all.map(\.id)).union(["none"])
    static let pastureThemeIDs: Set<String> = ["pasture_meadow", "pasture_moonlit", "pasture_sunrise"]
}

struct CountingSheepUserProfile: Codable, Equatable, Sendable {
    var displayName: String
    var presentation: CountingSheepPublicPresentation
    var revision: Int
    var successfulDisplayNameChangeDates: [Date]
    var hasEstablishedDisplayName: Bool

    init(
        displayName: String,
        presentation: CountingSheepPublicPresentation = .defaultValue,
        revision: Int = 0,
        successfulDisplayNameChangeDates: [Date] = [],
        hasEstablishedDisplayName: Bool = false
    ) {
        self.displayName = CountingSheepDisplayName.normalize(displayName)
        self.presentation = presentation
        self.revision = max(0, revision)
        self.successfulDisplayNameChangeDates = successfulDisplayNameChangeDates.sorted()
        self.hasEstablishedDisplayName = hasEstablishedDisplayName
    }

    private enum CodingKeys: String, CodingKey {
        case displayName, presentation, revision, successfulDisplayNameChangeDates, hasEstablishedDisplayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            displayName: try container.decodeIfPresent(String.self, forKey: .displayName) ?? "",
            presentation: try container.decodeIfPresent(CountingSheepPublicPresentation.self, forKey: .presentation) ?? .defaultValue,
            revision: try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0,
            successfulDisplayNameChangeDates: try container.decodeIfPresent([Date].self, forKey: .successfulDisplayNameChangeDates) ?? [],
            hasEstablishedDisplayName: try container.decodeIfPresent(Bool.self, forKey: .hasEstablishedDisplayName) ?? false
        )
    }
}

enum CountingSheepDisplayName {
    static let minimumLength = 2
    static let maximumLength = 24

    enum ValidationError: Error, Equatable, Sendable {
        case tooShort, tooLong, unsupportedCharacter
    }

    static func normalize(_ value: String) -> String {
        value.split(whereSeparator: { $0.unicodeScalars.allSatisfy(CharacterSet.whitespacesAndNewlines.contains) })
            .joined(separator: " ")
            .precomposedStringWithCanonicalMapping
    }

    static func validate(_ value: String) -> Result<String, ValidationError> {
        let normalized = normalize(value)
        guard normalized.count >= minimumLength else { return .failure(.tooShort) }
        guard normalized.count <= maximumLength else { return .failure(.tooLong) }
        guard normalized.unicodeScalars.allSatisfy(isAllowed) else { return .failure(.unsupportedCharacter) }
        return .success(normalized)
    }

    private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        if CharacterSet.letters.contains(scalar) || CharacterSet.nonBaseCharacters.contains(scalar)
            || CharacterSet.decimalDigits.contains(scalar) || scalar == " " {
            return true
        }
        return ["'", "’", "-", "‐", "‑"].contains(scalar)
    }
}

enum CountingSheepDisplayNameChangeRules {
    static let maximumSuccessfulChanges = 2
    static let rollingWindow: TimeInterval = 14 * 24 * 60 * 60

    enum Decision: Equatable, Sendable {
        case accepted(normalizedName: String, recordChangeAt: Date?)
        case noChange(normalizedName: String)
        case invalid(CountingSheepDisplayName.ValidationError)
        case changeLimitReached
    }

    static func decision(
        current: CountingSheepUserProfile,
        proposedName: String,
        now: Date
    ) -> Decision {
        switch CountingSheepDisplayName.validate(proposedName) {
        case let .failure(error): return .invalid(error)
        case let .success(normalized):
            guard normalized != current.displayName else { return .noChange(normalizedName: normalized) }
            guard current.hasEstablishedDisplayName else {
                return .accepted(normalizedName: normalized, recordChangeAt: nil)
            }
            let recent = current.successfulDisplayNameChangeDates.filter { $0 > now.addingTimeInterval(-rollingWindow) }
            guard recent.count < maximumSuccessfulChanges else { return .changeLimitReached }
            return .accepted(normalizedName: normalized, recordChangeAt: now)
        }
    }

    static func applying(_ decision: Decision, to profile: CountingSheepUserProfile) -> CountingSheepUserProfile {
        var updated = profile
        guard case let .accepted(name, recordedAt) = decision else { return updated }
        updated.displayName = name
        updated.hasEstablishedDisplayName = true
        if let recordedAt {
            updated.successfulDisplayNameChangeDates = updated.successfulDisplayNameChangeDates
                .filter { $0 > recordedAt.addingTimeInterval(-rollingWindow) } + [recordedAt]
        }
        return updated
    }
}

enum CountingSheepUserProfileRevisionRules {
    /// Conditional updates prevent two settings screens from both spending the same name-change slot.
    static func canApply(expectedRevision: Int, to profile: CountingSheepUserProfile) -> Bool {
        expectedRevision == profile.revision
    }
}

/// The server is authoritative for revision conflicts and its own rate-limit history.
/// This local rule only keeps the settings UI predictable while offline.
