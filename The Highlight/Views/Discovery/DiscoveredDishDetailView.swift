import SwiftUI

struct DiscoveredDishDetailView: View {
    let dish: DishReference
    let allDishes: [DishReference]

    @Binding private var highlights: [Highlight]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let occasions: [Occasion]
    private let previewImageAssets: [UUID: String]
    private let previewOccasions: [Occasion]?
    private let usesPreviewData: Bool
    var onSaveComplete: (() -> Void)? = nil

    @State private var isShowingLinkPicker = false
    @State private var highlightPendingUnlink: Highlight?
    @State private var isUpdatingLink = false
    @State private var linkErrorMessage: String?

    init(
        dish: DishReference,
        allDishes: [DishReference],
        highlights: Binding<[Highlight]> = .constant([]),
        occasions: [Occasion] = [],
        previewImageAssets: [UUID: String] = [:],
        previewOccasions: [Occasion]? = nil,
        usesPreviewData: Bool = false,
        onSaveComplete: (() -> Void)? = nil
    ) {
        self.dish = dish
        self.allDishes = allDishes
        _highlights = highlights
        self.occasions = occasions
        self.previewImageAssets = previewImageAssets
        self.previewOccasions = previewOccasions
        self.usesPreviewData = usesPreviewData
        self.onSaveComplete = onSaveComplete
    }

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AppTopNavigationRow(
                        title: "DISH",
                        leadingAction: { dismiss() }
                    )

                    dishHeader
                    descriptionSection
                    detailTagsSection
                    dietaryTagsSection
                    originNoteSection
                    relatedDishesSection
                    actionsSection
                    attachedHighlightsSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            #if DEBUG
            DishDiscoveryPerformanceLogger.logDetailAppeared(for: dish)
            #endif
        }
        .sheet(isPresented: $isShowingLinkPicker) {
            HighlightLinkPickerView(
                dish: dish,
                highlights: $highlights,
                previewImageAssets: previewImageAssets,
                usesPreviewData: usesPreviewData,
                onLinkComplete: handleHighlightChange
            )
        }
        .alert("Unlink this Highlight?", isPresented: isShowingUnlinkConfirmation) {
            Button("Cancel", role: .cancel) {
                highlightPendingUnlink = nil
            }
            Button("Unlink", role: .destructive) {
                if let highlightPendingUnlink {
                    Task {
                        await updateDishReference(for: highlightPendingUnlink, dishReferenceID: nil)
                    }
                }
            }
        } message: {
            Text("This keeps the Highlight saved, but removes it from this catalog dish.")
        }
    }

    private var dishHeader: some View {
        DishDetailHeroCard(
            dish: dish,
            cardBackground: theme.cardBackground,
            primaryText: theme.primaryText
        )
    }

    private var descriptionSection: some View {
        Text(dish.longDescription)
            .appBodyFont(size: 16)
            .foregroundColor(theme.primaryText)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var detailTagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What to expect")
                .appBodyBoldFont(size: 15)
                .foregroundColor(theme.primaryText)

            HStack(spacing: 8) {
                ForEach(Array(dish.descriptionTags.prefix(3)), id: \.self) { tag in
                    Text(tag)
                        .appBodyBoldFont(size: 12)
                        .foregroundColor(.textPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.descriptionTagBackground(for: tag))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var dietaryTagsSection: some View {
        if !dish.dietaryTags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Dietary notes")
                    .appBodyBoldFont(size: 15)
                    .foregroundColor(theme.primaryText)

                FlowPills(values: dish.dietaryTags, theme: theme)
            }
        }
    }

    @ViewBuilder
    private var originNoteSection: some View {
        if let originNote = dish.originNote?.trimmingCharacters(in: .whitespacesAndNewlines), !originNote.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Origin")
                    .appBodyBoldFont(size: 15)
                    .foregroundColor(theme.primaryText)

                Text(originNote)
                    .appBodyFont(size: 15)
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var relatedDishesSection: some View {
        if !resolvedRelatedDishes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Related dishes")
                    .appBodyBoldFont(size: 15)
                    .foregroundColor(theme.primaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(resolvedRelatedDishes) { relatedDish in
                            NavigationLink {
                                DiscoveredDishDetailView(
                                    dish: relatedDish,
                                    allDishes: allDishes,
                                    highlights: $highlights,
                                    occasions: occasions,
                                    previewImageAssets: previewImageAssets,
                                    previewOccasions: previewOccasions,
                                    usesPreviewData: usesPreviewData,
                                    onSaveComplete: onSaveComplete
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(relatedDish.discoveryCardCuisineLabel)
                                        .appBodyBoldFont(size: 11)
                                        .foregroundColor(.accentPrimary)
                                        .textCase(.uppercase)
                                    Text(relatedDish.name)
                                        .appBodyBoldFont(size: 15)
                                        .foregroundColor(theme.primaryText)
                                        .lineLimit(2)
                                    Text(relatedDish.shortDescription)
                                        .appBodyFont(size: 12)
                                        .foregroundColor(theme.secondaryText)
                                        .lineLimit(3)
                                }
                                .padding(14)
                                .frame(width: 180, alignment: .leading)
                                .background(theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    #if DEBUG
                                    DishDiscoveryPerformanceLogger.recordDishCardTap(relatedDish)
                                    #endif
                                }
                            )
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            NavigationLink {
                AddDishView(
                    initialDishReference: dish,
                    previewOccasions: childPreviewOccasions,
                    onSaveComplete: handleHighlightChange
                )
            } label: {
                actionButtonContent(
                    title: "Add a new Highlight",
                    systemName: "plus",
                    background: .accentPrimary,
                    foreground: theme.primaryActionText
                )
            }
            .buttonStyle(.plain)

            Button {
                isShowingLinkPicker = true
            } label: {
                actionButtonContent(
                    title: "Link an existing Highlight",
                    systemName: "link",
                    background: .surfacePrimary,
                    foreground: .textPrimary
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var attachedHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Your Highlights")
                    .appHeaderFont(size: 28)
                    .foregroundColor(theme.primaryText)

                Text("\(attachedHighlights.count)")
                    .appBodyBoldFont(size: 12)
                    .foregroundColor(.white)
                    .frame(minWidth: 24, minHeight: 24)
                    .padding(.horizontal, 4)
                    .background(Color.accentPrimary)
                    .clipShape(Capsule())
            }

            if let linkErrorMessage {
                Text(linkErrorMessage)
                    .appBodyFont(size: 13)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if attachedHighlights.isEmpty {
                Text("You haven't saved a Highlight for this dish yet.")
                    .appBodyFont(size: 15)
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                LazyVGrid(columns: cardColumns, spacing: 28) {
                    ForEach(Array(attachedHighlights.enumerated()), id: \.element.id) { index, highlight in
                        VStack(spacing: 10) {
                            NavigationLink {
                                DishDescriptionView(
                                    highlight: highlight,
                                    highlights: $highlights,
                                    occasions: occasions,
                                    previewImageAssets: previewImageAssets,
                                    onSaveComplete: handleHighlightChange
                                )
                            } label: {
                                HomeView.HighlightCard(
                                    highlight: highlight,
                                    rotationDegrees: index.isMultiple(of: 2) ? -2 : 2,
                                    imageSource: imageSource(for: highlight),
                                    theme: HomeView.HighlightCard.Theme(
                                        background: theme.highlightCardBackground,
                                        text: theme.highlightCardText,
                                        fallbackBackground: theme.photoFallbackBackground
                                    )
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                highlightPendingUnlink = highlight
                            } label: {
                                HStack(spacing: 6) {
                                    if isUpdatingLink && highlightPendingUnlink?.id == highlight.id {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "link.badge.minus")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    Text("Unlink")
                                        .appBodyBoldFont(size: 12)
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(theme.cardBackground)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(isUpdatingLink)
                        }
                    }
                }
            }
        }
    }

    private var cardColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
    }

    private var attachedHighlights: [Highlight] {
        highlights
            .filter { $0.dishReferenceID == dish.id }
            .sorted { first, second in
                (first.date_eaten ?? first.created_at) > (second.date_eaten ?? second.created_at)
            }
    }

    private var childPreviewOccasions: [Occasion]? {
        usesPreviewData ? (previewOccasions ?? occasions) : nil
    }

    private var isShowingUnlinkConfirmation: Binding<Bool> {
        Binding(
            get: { highlightPendingUnlink != nil },
            set: { isPresented in
                if !isPresented {
                    highlightPendingUnlink = nil
                }
            }
        )
    }

    private var resolvedRelatedDishes: [DishReference] {
        var seenIDs = Set<UUID>()
        return dish.relatedDishes.compactMap { relatedName in
            guard let relatedDish = allDishes.first(where: { candidate in
                candidate.id != dish.id && candidate.name.localizedCaseInsensitiveCompare(relatedName) == .orderedSame
            }) else {
                return nil
            }

            guard !seenIDs.contains(relatedDish.id) else { return nil }
            seenIDs.insert(relatedDish.id)
            return relatedDish
        }
    }

    private func actionButtonContent(title: String, systemName: String, background: Color, foreground: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
            Text(title)
                .appBodyBoldFont(size: 15)
        }
        .foregroundColor(foreground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(background)
        .clipShape(Capsule())
    }

    private func imageSource(for highlight: Highlight) -> HomeView.HighlightImageSource {
        if let assetName = previewImageAssets[highlight.id] {
            return .asset(name: assetName)
        }

        if let photoPath = highlight.photo_path {
            return .remote(path: photoPath)
        }

        return .placeholder
    }

    private func handleHighlightChange() {
        onSaveComplete?()

        Task {
            await refreshHighlightsIfNeeded()
        }
    }

    @MainActor
    private func updateDishReference(for highlight: Highlight, dishReferenceID: UUID?) async {
        guard !isUpdatingLink else { return }

        isUpdatingLink = true
        linkErrorMessage = nil

        #if DEBUG
        let clock = ContinuousClock()
        let updateStart = clock.now
        #endif

        do {
            if usesPreviewData {
                highlights = highlights.map { currentHighlight in
                    currentHighlight.id == highlight.id
                        ? currentHighlight.withDishReferenceID(dishReferenceID)
                        : currentHighlight
                }
            } else {
                try await HighlightService.shared.updateDishReference(
                    highlightID: highlight.id,
                    dishReferenceID: dishReferenceID
                )
                highlights = try await HighlightService.shared.fetchHighlights()
            }

            onSaveComplete?()
            highlightPendingUnlink = nil

            #if DEBUG
            let updateDuration = updateStart.duration(to: clock.now)
            print("[DishDiscoveryTiming] detail highlight link update and refresh: \(DishDiscoveryPerformanceLogger.milliseconds(for: updateDuration)) ms")
            #endif
        } catch {
            linkErrorMessage = "Unable to update this Highlight link. Please try again."
            #if DEBUG
            print("[DishDiscovery] Highlight link update failed: \(error.localizedDescription)")
            #endif
        }

        isUpdatingLink = false
    }

    @MainActor
    private func refreshHighlightsIfNeeded() async {
        guard !usesPreviewData else { return }

        #if DEBUG
        let clock = ContinuousClock()
        let refreshStart = clock.now
        #endif

        do {
            highlights = try await HighlightService.shared.fetchHighlights()

            #if DEBUG
            let refreshDuration = refreshStart.duration(to: clock.now)
            print("[DishDiscoveryTiming] detail highlight refresh: \(DishDiscoveryPerformanceLogger.milliseconds(for: refreshDuration)) ms")
            #endif
        } catch {
            linkErrorMessage = "Highlights could not refresh. Pull back to Home and try again."
            #if DEBUG
            print("[DishDiscovery] Highlight refresh failed: \(error.localizedDescription)")
            #endif
        }
    }

    private struct FlowPills: View {
        let values: [String]
        let theme: Theme

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .appBodyBoldFont(size: 12)
                        .foregroundColor(theme.primaryText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(theme.cardBackground)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct Theme {
        let colorScheme: ColorScheme

        private var isDark: Bool {
            colorScheme == .dark
        }

        var background: Color {
            isDark ? .backgroundDarkPrimary : .backgroundPrimary
        }

        var primaryText: Color {
            isDark ? .backgroundPrimary : .textPrimary
        }

        var secondaryText: Color {
            primaryText.opacity(0.72)
        }

        var cardBackground: Color {
            isDark ? .textPrimary : .containerPrimary
        }

        var primaryActionText: Color {
            isDark ? .backgroundDarkPrimary : .white
        }

        var highlightCardBackground: Color {
            isDark ? .textPrimary : .surfacePrimary
        }

        var highlightCardText: Color {
            isDark ? .backgroundPrimary : .textPrimary
        }

        var photoFallbackBackground: Color {
            (isDark ? Color.backgroundDarkPrimary : Color.backgroundPrimary).opacity(0.3)
        }
    }
}

private struct DishDetailHeroCard: View {
    let dish: DishReference
    let cardBackground: Color
    let primaryText: Color

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                Text(dish.name)
                    .appHeaderFont(size: titleFontSize)
                    .foregroundColor(primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, titleTrailingPadding)

                countryRow
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(2)

            if shouldShowContinent, let continentAssetName {
                continentImage(assetName: continentAssetName)
                    .frame(width: continentSize, height: continentSize)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    private var titleFontSize: CGFloat {
        switch dish.name.count {
        case 0...12:
            return 48
        case 13...22:
            return 42
        default:
            return 36
        }
    }

    private var continentSize: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return 92
        }

        return horizontalSizeClass == .compact ? 104 : 112
    }

    private var continentColumnWidth: CGFloat {
        continentSize
    }

    private var titleTrailingPadding: CGFloat {
        shouldShowContinent && continentAssetName != nil ? continentColumnWidth + 14 : 0
    }

    private var shouldShowContinent: Bool {
        switch dynamicTypeSize {
        case .accessibility3, .accessibility4, .accessibility5:
            return false
        default:
            return true
        }
    }

    private var countryText: String {
        let countries = dish.countries
        return DishCountryDisplay.text(countries: countries, region: dish.region)
    }

    private var countryRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 19, weight: .semibold))
                .padding(.top, 1)

            countryTextView
        }
        .foregroundColor(primaryText)
        .layoutPriority(2)
    }

    @ViewBuilder
    private var countryTextView: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text(countryText)
                .appBodyBoldFont(size: 19)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(countryText)
                .appBodyBoldFont(size: 19)
                .lineLimit(3)
                .minimumScaleFactor(0.97)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(2)
        }
    }

    private var continentAssetName: String? {
        DishContinentArtwork.assetName(for: dish)
    }

    private func continentImage(assetName: String) -> some View {
        Image(assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundColor(.accentPrimary)
            .accessibilityHidden(true)
    }
}

enum DishCountryDisplay {
    static func text(countries: [String], region: String) -> String {
        let cleanCountries = countries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanCountries.isEmpty else {
            return region.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard cleanCountries.count > 6 else {
            return cleanCountries.joined(separator: ", ")
        }

        let visibleCountries = cleanCountries.prefix(4).joined(separator: ", ")
        return "\(visibleCountries) +\(cleanCountries.count - 4) more"
    }
}

enum DishContinentArtwork {
    static func assetName(for dish: DishReference) -> String? {
        if let assetName = exactAssetName(for: dish.continent) {
            return assetName
        }

        #if DEBUG
        print("[DishDiscovery] Legacy continent fallback for \(dish.name): continent=\(dish.continent ?? "nil"), region=\(dish.region), countries=\(dish.countries.joined(separator: ", "))")
        #endif

        return legacyRegionAssetName(for: dish)
    }

    private static func exactAssetName(for continent: String?) -> String? {
        switch continent?.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "Africa":
            return "Africa"
        case "Asia":
            return "Asia"
        case "Europe":
            return "Europe"
        case "North America":
            return "North America"
        case "South America":
            return "South America"
        case "Oceania":
            return "Oceania"
        default:
            return nil
        }
    }

    // Temporary fallback for legacy rows whose continent field is nil or unrecognized.
    private static func legacyRegionAssetName(for dish: DishReference) -> String? {
        let normalizedRegion = dish.region
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        if normalizedRegion.contains("africa") {
            return "Africa"
        }

        if normalizedRegion.contains("asia") || normalizedRegion.contains("middle east") {
            return "Asia"
        }

        if normalizedRegion.contains("europe") {
            return "Europe"
        }

        if normalizedRegion.contains("north america") || normalizedRegion.contains("central america") || normalizedRegion.contains("caribbean") {
            return "North America"
        }

        if normalizedRegion.contains("south america") {
            return "South America"
        }

        if normalizedRegion.contains("oceania") || normalizedRegion.contains("australia") || normalizedRegion.contains("pacific") {
            return "Oceania"
        }

        return nil
    }
}

#Preview("Discovered Dish Detail") {
    let linkedHighlights = HomeView.previewHighlights.map { highlight in
        highlight.id == HomeView.chickenCroffleID
            ? highlight.withDishReferenceID(DishReference.previewKimchiJjigaeID)
            : highlight
    }

    NavigationStack {
        DiscoveredDishDetailView(
            dish: DishReference.previewCatalog[0],
            allDishes: DishReference.previewCatalog,
            highlights: .constant(linkedHighlights),
            occasions: HomeView.previewOccasions,
            previewImageAssets: HomeView.previewImageAssets,
            previewOccasions: HomeView.previewOccasions,
            usesPreviewData: true
        )
    }
}

#Preview("Dish Detail Hero Variants") {
    let heroDishes = [
        heroPreviewDish(
            name: "Biryani",
            countries: ["India"],
            region: "South Asia",
            continent: "Asia",
            cuisine: "Indian"
        ),
        heroPreviewDish(
            name: "Chana masala",
            countries: ["India", "Pakistan"],
            region: "South Asia",
            continent: "Asia",
            cuisine: "Punjabi"
        ),
        heroPreviewDish(
            name: "Vietnamese shaking beef",
            countries: ["Vietnam", "United States", "France"],
            region: "Southeast Asia",
            continent: "Asia",
            cuisine: "Vietnamese"
        ),
        heroPreviewDish(
            name: "Arroz con pollo",
            countries: ["Spain", "Cuba", "Puerto Rico", "Peru", "Colombia"],
            region: "Latin America & Caribbean",
            continent: "South America",
            cuisine: "Latin American"
        ),
        heroPreviewDish(
            name: "Khao soi",
            countries: ["Thailand"],
            region: "Southeast Asia",
            continent: "Asia",
            cuisine: "Northern Thai"
        ),
        heroPreviewDish(
            name: "Jollof rice",
            countries: ["Nigeria", "Ghana", "Senegal"],
            region: "West Africa",
            continent: "Africa",
            cuisine: "West African"
        ),
        heroPreviewDish(
            name: "Cacio e pepe",
            countries: ["Italy"],
            region: "Europe",
            continent: "Europe",
            cuisine: "Roman"
        ),
        heroPreviewDish(
            name: "Aguachile",
            countries: ["Mexico"],
            region: "Latin America & Caribbean",
            continent: "North America",
            cuisine: "Mexican"
        ),
        heroPreviewDish(
            name: "Jerk chicken",
            countries: ["Jamaica"],
            region: "Latin America & Caribbean",
            continent: "North America",
            cuisine: "Jamaican"
        ),
        heroPreviewDish(
            name: "Doubles",
            countries: ["Jamaica", "Trinidad and Tobago"],
            region: "Latin America & Caribbean",
            continent: "North America",
            cuisine: "Caribbean"
        ),
        heroPreviewDish(
            name: "Pepperpot",
            countries: ["Jamaica", "Trinidad and Tobago", "Guyana"],
            region: "Latin America & Caribbean",
            continent: "South America",
            cuisine: "Caribbean"
        ),
        heroPreviewDish(
            name: "Kibbeh",
            countries: ["Lebanon", "Syria", "Iraq", "Jordan", "Palestine", "Turkey"],
            region: "Middle East & North Africa",
            continent: "Asia",
            cuisine: "Levantine"
        ),
        heroPreviewDish(
            name: "Hangi",
            countries: ["New Zealand"],
            region: "Oceania",
            continent: "Oceania",
            cuisine: "Māori"
        ),
        heroPreviewDish(
            name: "Legacy fallback",
            countries: ["Kazakhstan"],
            region: "Central Asia & Caucasus",
            continent: nil,
            cuisine: "Kazakh"
        )
    ]

    ScrollView {
        VStack(spacing: 16) {
            ForEach(heroDishes) { dish in
                DishDetailHeroCard(
                    dish: dish,
                    cardBackground: .containerPrimary,
                    primaryText: .textPrimary
                )
            }
        }
        .padding(24)
    }
    .background(Color.backgroundPrimary)
}

private func heroPreviewDish(
    name: String,
    countries: [String],
    region: String,
    continent: String?,
    cuisine: String
) -> DishReference {
    DishReference(
        id: UUID(),
        name: name,
        alternateNames: [],
        countries: countries,
        region: region,
        continent: continent,
        cuisine: cuisine,
        category: "Preview",
        familiarity: "Preview",
        restaurantAccessibility: nil,
        shortDescription: "Preview dish.",
        longDescription: "Preview dish.",
        descriptionTags: ["Aromatic", "Comforting", "Classic"],
        dietaryTags: [],
        searchKeywords: [],
        originNote: nil,
        relatedDishes: [],
        contentStatus: "published",
        createdAt: Date(timeIntervalSince1970: 1_780_000_000)
    )
}

#Preview("Discovered Dish Detail Empty") {
    NavigationStack {
        DiscoveredDishDetailView(
            dish: DishReference.previewCatalog[1],
            allDishes: DishReference.previewCatalog,
            highlights: .constant([]),
            usesPreviewData: true
        )
    }
}
