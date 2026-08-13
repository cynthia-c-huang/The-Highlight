import SwiftUI

struct DiscoverDishesView: View {
    @Binding private var highlights: [Highlight]
    @EnvironmentObject private var catalogStore: DishCatalogStore
    @StateObject private var viewModel: DishDiscoveryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showsScrollToTopButton = false

    private let occasions: [Occasion]
    private let previewImageAssets: [UUID: String]
    private let previewOccasions: [Occasion]?
    private let usesPreviewData: Bool
    private let scrollTopAnchorID = "discoverDishesTop"
    private let scrollToTopOffsetThreshold: CGFloat = 1_500
    var onSaveComplete: (() -> Void)? = nil

    init(
        highlights: Binding<[Highlight]>,
        occasions: [Occasion] = [],
        previewImageAssets: [UUID: String] = [:],
        previewDishes: [DishReference]? = nil,
        previewOccasions: [Occasion]? = nil,
        usesPreviewData: Bool = false,
        onSaveComplete: (() -> Void)? = nil
    ) {
        _highlights = highlights
        _viewModel = StateObject(wrappedValue: DishDiscoveryViewModel(previewDishes: previewDishes))
        self.occasions = occasions
        self.previewImageAssets = previewImageAssets
        self.previewOccasions = previewOccasions
        self.usesPreviewData = usesPreviewData || previewDishes != nil
        self.onSaveComplete = onSaveComplete
    }

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }

    private var triedDishIDs: Set<UUID> {
        Set(highlights.compactMap(\.dishReferenceID))
    }

    private var displayedDishes: [DishReference] {
        viewModel.filteredDishes(triedDishIDs: triedDishIDs)
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Color.clear
                            .frame(height: 0)
                            .id(scrollTopAnchorID)

                        AppTopNavigationRow(
                            title: "DISCOVER",
                            leadingAction: { dismiss() },
                            trailingSystemName: "shuffle",
                            trailingBackground: Color.accentSecondary,
                            trailingForeground: .textPrimary,
                            trailingAction: { viewModel.shuffleDishes(triedDishIDs: triedDishIDs) }
                        )

                        header
                        searchBar
                        filterSection
                        content
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
                .refreshable {
                    await catalogStore.refresh()
                    viewModel.applyRefreshedCatalog(catalogStore.dishes)
                }
                .overlay(alignment: .bottomTrailing) {
                    if showsScrollToTopButton {
                        scrollToTopButton(proxy: proxy)
                            .padding(.trailing, 24)
                            .padding(.bottom, 26)
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y > scrollToTopOffsetThreshold
                } action: { _, shouldShowButton in
                    updateScrollToTopButtonVisibility(shouldShowButton)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            viewModel.applyCatalog(catalogStore.dishes)
            await catalogStore.loadIfNeeded()
            viewModel.applyCatalog(catalogStore.dishes)
        }
        .onChange(of: catalogStore.dishes) { _, newDishes in
            viewModel.applyCatalog(newDishes)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find a dish to try")
                .appHeaderFont(size: 34)
                .foregroundColor(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Browse the shared catalog, then attach your own Highlights when you save or link a dish.")
                .appBodyFont(size: 15)
                .foregroundColor(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.accentPrimary)

            TextField("", text: $viewModel.searchText, prompt: Text("Search dishes, cuisines, tags...").foregroundColor(theme.secondaryText.opacity(0.78)))
                .appBodyFont(size: 15)
                .foregroundColor(theme.primaryText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.secondaryText.opacity(0.72))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(theme.controlBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            filterControls
            selectedFiltersRow
        }
    }

    private var filterControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                cuisineGroupFilterMenu

                filterMenu(
                    title: "Flavor",
                    selection: viewModel.selectedDescriptionTag,
                    options: viewModel.availableDescriptionTags,
                    clearAction: { viewModel.selectedDescriptionTag = nil },
                    selectAction: viewModel.toggleDescriptionTag
                )

                dietaryFilterMenu

                triedFilterMenu

            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var selectedFiltersRow: some View {
        if viewModel.hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let selectedCuisineGroup = viewModel.selectedCuisineGroup {
                        selectedFilterPill(title: selectedCuisineGroup.title) {
                            viewModel.selectedCuisineGroup = nil
                        }
                    }

                    if let selectedDescriptionTag = viewModel.selectedDescriptionTag {
                        selectedFilterPill(title: selectedDescriptionTag) {
                            viewModel.selectedDescriptionTag = nil
                        }
                    }

                    if let selectedDietaryFilter = viewModel.selectedDietaryFilter {
                        selectedFilterPill(title: selectedDietaryFilter.title) {
                            viewModel.selectedDietaryFilter = nil
                        }
                    }

                    if let selectedTriedFilter = viewModel.selectedTriedFilter {
                        selectedFilterPill(title: selectedTriedFilter.title) {
                            viewModel.selectedTriedFilter = nil
                        }
                    }

                    Button {
                        viewModel.clearFilters()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                            Text("Clear")
                                .appBodyBoldFont(size: 13)
                        }
                        .foregroundColor(theme.primaryText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(theme.controlBackground)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear all filters")
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func selectedFilterPill(title: String, clearAction: @escaping () -> Void) -> some View {
        Button(action: clearAction) {
            HStack(spacing: 6) {
                Text(title)
                    .appBodyBoldFont(size: 12)
                    .lineLimit(1)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.accentPrimary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(theme.controlBackground)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.accentPrimary, lineWidth: 1.2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(title) filter")
    }

    private var cuisineGroupFilterMenu: some View {
        Menu {
            Button("All cuisines") {
                viewModel.selectedCuisineGroup = nil
            }

            ForEach(viewModel.availableCuisineGroups) { option in
                Button {
                    viewModel.toggleCuisineGroup(option)
                } label: {
                    if viewModel.selectedCuisineGroup == option {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("Cuisine")
                    .appBodyBoldFont(size: 13)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(viewModel.selectedCuisineGroup == nil ? theme.primaryText : .accentPrimary)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(theme.controlBackground)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(viewModel.selectedCuisineGroup == nil ? Color.clear : Color.accentPrimary, lineWidth: 1.5)
            }
        }
        .disabled(viewModel.availableCuisineGroups.isEmpty)
        .accessibilityLabel(
            viewModel.selectedCuisineGroup.map { "Cuisine filter, \($0.title)" } ?? "Cuisine filter"
        )
    }

    private var dietaryFilterMenu: some View {
        Menu {
            Button("All diet") {
                viewModel.selectedDietaryFilter = nil
            }

            ForEach(viewModel.availableDietaryFilters) { option in
                Button {
                    viewModel.toggleDietaryFilter(option)
                } label: {
                    if viewModel.selectedDietaryFilter == option {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("Diet")
                    .appBodyBoldFont(size: 13)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(viewModel.selectedDietaryFilter == nil ? theme.primaryText : .accentPrimary)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(theme.controlBackground)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(viewModel.selectedDietaryFilter == nil ? Color.clear : Color.accentPrimary, lineWidth: 1.5)
            }
        }
    }

    private var triedFilterMenu: some View {
        Menu {
            ForEach(TriedFilterOption.allCases) { option in
                Button {
                    viewModel.toggleTriedFilter(option)
                } label: {
                    if viewModel.selectedTriedFilter == option {
                        Label(option.menuTitle, systemImage: "checkmark")
                    } else {
                        Text(option.menuTitle)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("Tried")
                    .appBodyBoldFont(size: 13)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(viewModel.selectedTriedFilter == nil ? theme.primaryText : .accentPrimary)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(theme.controlBackground)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(viewModel.selectedTriedFilter == nil ? Color.clear : Color.accentPrimary, lineWidth: 1.5)
            }
        }
    }

    private func filterMenu(
        title: String,
        selection: String?,
        options: [String],
        clearAction: @escaping () -> Void,
        selectAction: @escaping (String) -> Void
    ) -> some View {
        Menu {
            Button("All \(title.lowercased())") {
                clearAction()
            }

            ForEach(options, id: \.self) { option in
                Button {
                    selectAction(option)
                } label: {
                    if selection == option {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .appBodyBoldFont(size: 13)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(selection == nil ? theme.primaryText : .accentPrimary)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(theme.controlBackground)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(selection == nil ? Color.clear : Color.accentPrimary, lineWidth: 1.5)
            }
        }
        .disabled(options.isEmpty)
    }

    @ViewBuilder
    private var content: some View {
        if catalogStore.isLoading && viewModel.isCatalogEmpty {
            loadingState
                .frame(maxWidth: .infinity, minHeight: 280)
        } else if let errorMessage = catalogStore.errorMessage, viewModel.isCatalogEmpty {
            errorState(errorMessage)
                .frame(maxWidth: .infinity, minHeight: 280)
        } else if viewModel.isCatalogEmpty {
            emptyState(
                title: "No published dishes yet",
                message: "Published catalog dishes will appear here."
            )
            .frame(maxWidth: .infinity, minHeight: 280)
        } else if displayedDishes.isEmpty {
            emptyState(
                title: "No catalog dishes found",
                message: "Try a different search or clear a filter."
            )
            .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            LazyVStack(spacing: 14) {
                ForEach(displayedDishes) { dish in
                    NavigationLink {
                        DiscoveredDishDetailView(
                            dish: dish,
                            allDishes: viewModel.dishes,
                            highlights: $highlights,
                            occasions: occasions,
                            previewImageAssets: previewImageAssets,
                            previewOccasions: previewOccasions,
                            usesPreviewData: usesPreviewData,
                            onSaveComplete: onSaveComplete
                        )
                    } label: {
                        DishDiscoveryCard(
                            dish: dish,
                            isTried: triedDishIDs.contains(dish.id),
                            theme: theme
                        )
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            #if DEBUG
                            DishDiscoveryPerformanceLogger.recordDishCardTap(dish)
                            #endif
                        }
                    )
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func scrollToTopButton(proxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.24)) {
                proxy.scrollTo(scrollTopAnchorID, anchor: .top)
                showsScrollToTopButton = false
            }
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.backgroundPrimary)
                .frame(width: 52, height: 52)
                .background(Color.accentSecondary)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scroll to top")
    }

    private func updateScrollToTopButtonVisibility(_ shouldShowButton: Bool) {
        guard showsScrollToTopButton != shouldShowButton else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            showsScrollToTopButton = shouldShowButton
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentPrimary))
            Text("Loading dish catalog...")
                .appBodyFont(size: 14)
                .foregroundColor(theme.secondaryText)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.accentPrimary)

            Text("Discovery could not load")
                .appHeaderFont(size: 24)
                .foregroundColor(theme.primaryText)

            Text(message)
                .appBodyFont(size: 14)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    await catalogStore.refresh()
                    viewModel.applyRefreshedCatalog(catalogStore.dishes)
                }
            } label: {
                Text("Try Again")
                    .appBodyBoldFont(size: 14)
                    .foregroundColor(.textPrimary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(Color.surfacePrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.accentPrimary)

            Text(title)
                .appHeaderFont(size: 24)
                .foregroundColor(theme.primaryText)

            Text(message)
                .appBodyFont(size: 14)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private struct DishDiscoveryCard: View {
        let dish: DishReference
        let isTried: Bool
        let theme: Theme

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(dish.discoveryCardCuisineLabel)
                        .appBodyBoldFont(size: 12)
                        .foregroundColor(.accentPrimary)
                        .textCase(.uppercase)

                    Spacer()

                    if isTried {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.accentSecondary)
                            .accessibilityLabel("Already tried")
                    }
                }

                Text(dish.name)
                    .appHeaderFont(size: 28)
                    .foregroundColor(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(dish.shortDescription)
                    .appBodyFont(size: 15)
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(Array(dish.descriptionTags.prefix(3)), id: \.self) { tag in
                        Text(tag)
                            .appBodyBoldFont(size: 12)
                            .foregroundColor(.textPrimary)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 10)
                            .background(Color.descriptionTagBackground(for: tag))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
        }

        private var accessibilityLabel: String {
            let triedText = isTried ? ", already tried" : ""
            return "\(dish.name), \(dish.discoveryCardCuisineLabel), \(dish.formattedGeography)\(triedText). \(dish.shortDescription)"
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

        var controlBackground: Color {
            isDark ? .textPrimary : .containerPrimary
        }

        var cardBackground: Color {
            isDark ? .textPrimary : .containerPrimary
        }
    }
}

#Preview("Discover Dishes") {
    let previewHighlights = HomeView.previewHighlights.map { highlight in
        highlight.id == HomeView.chickenCroffleID
            ? highlight.withDishReferenceID(DishReference.previewKimchiJjigaeID)
            : highlight
    }

    NavigationStack {
        DiscoverDishesView(
            highlights: .constant(previewHighlights),
            occasions: HomeView.previewOccasions,
            previewImageAssets: HomeView.previewImageAssets,
            previewDishes: DishReference.previewCatalog,
            previewOccasions: HomeView.previewOccasions,
            usesPreviewData: true
        )
    }
    .environmentObject(DishCatalogStore(previewDishes: DishReference.previewCatalog))
}

#Preview("Discover Dishes Empty") {
    NavigationStack {
        DiscoverDishesView(
            highlights: .constant([]),
            previewDishes: [],
            usesPreviewData: true
        )
    }
    .environmentObject(DishCatalogStore(previewDishes: []))
}
