import SwiftUI

struct DishesView: View {
    @Binding private var highlights: [Highlight]

    let occasions: [Occasion]
    let previewImageAssets: [UUID: String]
    var onSaveComplete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText: String = ""
    @State private var locationFilter: LocationFilter? = nil
    @State private var minimumRating: Int? = nil
    @State private var dateFilter: DateFilter? = nil
    @State private var sortMode: SortMode = .alphabetical
    @State private var isMealSearchEnabled: Bool = false //toggles whether the search bar searches by meal or dish name
    @State private var isShowingRatingWheel: Bool = false
    @State private var selectedRatingWheelValue: Int = 7
    @State private var isShowingDateSheet: Bool = false
    @State private var dateFilterGranularity: DateFilterGranularity = .year

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    private static let ungroupedMealSectionID = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()

    init(
        highlights: Binding<[Highlight]>,
        occasions: [Occasion] = [],
        previewImageAssets: [UUID: String] = [:],
        onSaveComplete: (() -> Void)? = nil
    ) {
        _highlights = highlights
        self.occasions = occasions
        self.previewImageAssets = previewImageAssets
        self.onSaveComplete = onSaveComplete
    }

    private var theme: DishesTheme {
        DishesTheme(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topNavigationRow
                    searchBar
                    quickFilters
                    if isShowingRatingWheel {
                        ratingWheelFilter
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if filteredHighlights.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, minHeight: 240)
                    } else if isMealSearchEnabled {
                        mealGroupedGrid
                    } else {
                        LazyVGrid(columns: columns, spacing: 32) {
                            ForEach(Array(filteredHighlights.enumerated()), id: \.element.id) { index, highlight in
                                NavigationLink {
                                    DishDescriptionView(
                                        highlight: highlight,
                                        highlights: $highlights,
                                        occasions: occasions,
                                        previewImageAssets: previewImageAssets,
                                        onSaveComplete: onSaveComplete, //Dishes passes both an edit/save callback and a delete callback.
                                        onDeleteComplete: handleDeleteComplete
                                    )
                                } label: {
                                    HomeView.HighlightCard(
                                        highlight: highlight,
                                        rotationDegrees: index.isMultiple(of: 2) ? -2 : 2,
                                        imageSource: imageSource(for: highlight),
                                        theme: theme.highlightCard
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 100)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingDateSheet) {
            dateSheet
        }
    }

    private func handleDeleteComplete(_ updatedHighlights: [Highlight]) {
        guard updatedHighlights.isEmpty else { return }
        dismiss()
    }

    private var topNavigationRow: some View {
        AppTopNavigationRow(
            title: "DISHES",
            leadingAction: { dismiss() }
        )
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentSecondary)
            //Because it uses $searchText, every character the user types updates the state.
            TextField("", text: $searchText, prompt: Text(searchPrompt).foregroundColor(theme.secondaryText.opacity(0.78)))
                .appBodyFont(size: 15)
                .foregroundColor(theme.primaryText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            //canceling a search
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.secondaryText.opacity(0.72))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(theme.controlBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    private var quickFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterPill(title: "Most recent", isSelected: sortMode == .mostRecent) {
                    sortMode = sortMode == .mostRecent ? .alphabetical : .mostRecent
                }

                filterPill(title: "Home", isSelected: locationFilter == .home) {
                    locationFilter = locationFilter == .home ? nil : .home
                }

                filterPill(title: "Restaurant", isSelected: locationFilter == .restaurant) {
                    locationFilter = locationFilter == .restaurant ? nil : .restaurant
                }

                filterPill(title: ratingFilterTitle, isSelected: minimumRating != nil || isShowingRatingWheel) {
                    selectedRatingWheelValue = minimumRating ?? selectedRatingWheelValue
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingRatingWheel.toggle()
                    }
                }

                filterPill(title: dateFilterTitle, isSelected: dateFilter != nil) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingRatingWheel = false
                    }
                    isShowingDateSheet = true
                }
                //The code does not clear searchText when meal mode is toggled or untoggled, so searching for "pasta" (dishname) then toggling will search for meal metadata containing pasta, which will likely contain nil because meal metadata does not search by dish name.
                //When searching for "birthday" and untoggling, it will search for dish names with "birthday", which will also likely contain nil
                filterPill(title: "Meal", isSelected: isMealSearchEnabled) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isMealSearchEnabled.toggle()
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .appBodyFont(size: 13)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .accentPrimary : theme.primaryText)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(theme.controlBackground)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? Color.accentPrimary : Color.clear, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
    }

    private var ratingWheelFilter: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Rating above")
                    .appBodyFont(size: 15)
                    .fontWeight(.bold)
                    .foregroundColor(theme.primaryText)

                Spacer()

                Button {
                    minimumRating = nil
                    selectedRatingWheelValue = 7
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingRatingWheel = false
                    }
                } label: {
                    Text("Clear")
                        .appBodyFont(size: 13)
                        .fontWeight(.bold)
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.plain)
            }

            Picker("Minimum rating", selection: $selectedRatingWheelValue) {
                ForEach(1...10, id: \.self) { rating in
                    Text("\(rating)")
                        .appHeaderFont(size: 24)
                        .tag(rating)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 142)
            .clipped()

            Button {
                minimumRating = selectedRatingWheelValue
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingRatingWheel = false
                }
            } label: {
                Text("Apply Above \(selectedRatingWheelValue)")
                    .appBodyFont(size: 14)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.accentPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.accentPrimary)

            Text("No dishes found")
                .appHeaderFont(size: 24)
                .foregroundColor(theme.primaryText)

            Text(isMealSearchEnabled ? "Try a different meal or filter." : "Try a different name or filter.")
                .appBodyFont(size: 14)
                .foregroundColor(theme.secondaryText)
        }
        .multilineTextAlignment(.center)
    }

    private var mealGroupedGrid: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(mealSections) { section in
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(section.title)
                            .appHeaderFont(size: 24)
                            .foregroundColor(theme.primaryText)
                    }

                    LazyVGrid(columns: columns, spacing: 32) {
                        ForEach(Array(section.highlights.enumerated()), id: \.element.id) { index, highlight in
                            NavigationLink {
                                DishDescriptionView(
                                    highlight: highlight,
                                    highlights: $highlights,
                                    occasions: occasions,
                                    previewImageAssets: previewImageAssets,
                                    onSaveComplete: onSaveComplete,
                                    onDeleteComplete: handleDeleteComplete
                                )
                            } label: {
                                HomeView.HighlightCard(
                                    highlight: highlight,
                                    rotationDegrees: index.isMultiple(of: 2) ? -2 : 2,
                                    imageSource: imageSource(for: highlight),
                                    theme: theme.highlightCard
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var dateSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Range", selection: $dateFilterGranularity) {
                    ForEach(DateFilterGranularity.allCases) { granularity in
                        Text(granularity.rawValue).tag(granularity)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)

                ScrollView {
                    VStack(spacing: 10) {
                        Button {
                            dateFilter = nil
                            isShowingDateSheet = false
                        } label: {
                            dateOptionLabel("All dates")
                        }
                        .buttonStyle(.plain)

                        switch dateFilterGranularity {
                        case .year:
                            ForEach(availableYears, id: \.self) { year in
                                Button {
                                    dateFilter = .year(year)
                                    isShowingDateSheet = false
                                } label: {
                                    dateOptionLabel("\(year)")
                                }
                                .buttonStyle(.plain)
                            }
                        case .month:
                            ForEach(availableMonths, id: \.self) { month in
                                Button {
                                    dateFilter = .month(month)
                                    isShowingDateSheet = false
                                } label: {
                                    dateOptionLabel(month.formatted(.dateTime.month(.wide).year()))
                                }
                                .buttonStyle(.plain)
                            }
                        case .week:
                            ForEach(availableWeeks, id: \.start) { week in
                                Button {
                                    dateFilter = .week(week)
                                    isShowingDateSheet = false
                                } label: {
                                    dateOptionLabel(weekTitle(for: week))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, 18)
            .background(theme.background)
            .navigationTitle("During")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func dateOptionLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .appBodyFont(size: 16)
                .foregroundColor(theme.primaryText)
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    //the program always filters Highlights. Even when searching by meal, it asks whether each individual Highlight belongs to a meal matching the search.
    private var filteredHighlights: [Highlight] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines) //When searchText changes, SwiftUI recomputes the view, including filteredHighlights

        return highlights
            .filter { highlight in
                //ex. "Spicy Miso Pasta".localizedCaseInsensitiveContains("pasta") returns TRUE
                if !query.isEmpty && !searchText(for: highlight).localizedCaseInsensitiveContains(query) {
                    return false //Searching a particular ungrouped dish’s name will not find it in meal mode because the returned search text is "Ungrouped dishes", not its dish name.
                }
                //After the search test, the same Highlight must pass the location, rating, and date tests.
                if let locationFilter /*Run this check only when a location filter has been selected.*/, highlight.location_type.lowercased() != locationFilter.databaseValue {
                    return false
                }

                if let minimumRating, highlight.rating < Double(minimumRating) {
                    return false
                }

                if let dateFilter, !dateFilter.contains(recencyDate(for: highlight), calendar: calendar) {
                    return false
                }

                return true
            }
            .sorted(by: sortedHighlights)
    }
    //if meal search is enabled, the prompt is "Search meals..."
    private var searchPrompt: String {
        isMealSearchEnabled ? "Search meals..." : "I'm looking for..."
    }

    private var mealSections: [MealSection] {
        //Filtering happens before meal grouping
        let groupedHighlights = Dictionary(grouping: filteredHighlights, by: \.occasion_id) //This creates a dictionary whose key is UUID?. The key is optional because ungrouped dishes also form a group.
        //each dictionary entry becomes a MealSection
        return groupedHighlights.map { occasionID, highlights in
            //if occasionID is nil → occasion is nil
            //if occasionID has a UUID → look up that UUID in occasionLookup
            let occasion = occasionID.flatMap { occasionLookup[$0] } //flatMap handles both the possibility that occasion = nil and occasionLookup may not contain that ID and returns nil, so it returns an Occasion?. Since dictionary lookup already returns an optional Occasion?, using map here could return Occasion??. flatMap combines, or “flattens,” those two optional layers into one
            return MealSection(
                id: occasionID ?? Self.ungroupedMealSectionID /*MealSection requires a non-optional UUID, so all ungrouped dishes use a reserved all-zero UUID. That gives SwiftUI a stable identity for the “Ungrouped dishes” section.*/,
                title: occasion?.displayTitle ?? "Ungrouped dishes",
                isGroupedMeal: occasionID != nil,
                sortDate: occasion?.date ?? highlights.map { recencyDate(for: $0) }.max() ?? Date.distantPast,
                highlights: highlights.sorted(by: sortedHighlights)
            )
        }
        .sorted { first, second in
            //this block only runs when one of them is grouped and one is ungrouped
            if first.isGroupedMeal != second.isGroupedMeal { //grouped meals before ungrouped
                return first.isGroupedMeal //if first is ungrouped, this returns false, so second comes first. If first is grouped, this returns true, so first comes first.
            }
            //if both of them are grouped or ungrouped, this block then runs
            if first.sortDate != second.sortDate { //newer meals before older
                return first.sortDate > second.sortDate
            }
            //alphabetical title when dates tie
            return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
        }
    }

    private var occasionLookup: [UUID: Occasion] { //converts [Occasion] into [UUID: Occasion] so lookup becomes occasionLookup[id] rather than occasions.first { $0.id == id }
        Dictionary(uniqueKeysWithValues: occasions.map { ($0.id, $0) })
    }

    private func searchText(for highlight: Highlight) -> String {
        guard isMealSearchEnabled else { //Unless meal search is enabled, immediately return the dish name
            return highlight.dish_name
        }
        //meal search enabled
        guard let occasionID = highlight.occasion_id,
              let occasion = occasionLookup[occasionID] else { //Attempts to get the Highlight’s occasion ID and find the corresponding full Occasion object.
            return "Ungrouped dishes"
        }
        //when the Occasion is found, it builds the meal string.
        let parts = [
            occasion.displayTitle,
            occasion.detailText,
            occasion.date?.formatted(.dateTime.month(.wide).day().year()),
            occasion.restaurantName,
            occasion.formattedAddress
        ]
        return parts.compactMap { $0 }.joined(separator: " ") //That combined string is never shown directly. It exists only to provide several searchable fields. Therefore, while meal search is active, these could all match that meal: Cynthia, birthday, Bestia, Los Angeles, July, 2026, 2121
    }

    private var ratingFilterTitle: String {
        if let minimumRating {
            return "Above \(minimumRating)"
        }

        return "Above"
    }

    private var dateFilterTitle: String {
        dateFilter?.title ?? "During"
    }

    private var availableYears: [Int] {
        uniqueSortedValues { highlight in
            calendar.component(.year, from: recencyDate(for: highlight))
        }
    }

    private var availableMonths: [Date] {
        uniqueSortedDates { highlight in
            intervalStart(.month, for: recencyDate(for: highlight))
        }
    }

    private var availableWeeks: [DateInterval] {
        let intervals = highlights.compactMap { highlight in
            calendar.dateInterval(of: .weekOfYear, for: recencyDate(for: highlight))
        }
        let uniqueIntervals = Dictionary(grouping: intervals, by: \.start).compactMap { $0.value.first }
        return uniqueIntervals.sorted { $0.start > $1.start }
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private func uniqueSortedValues(_ transform: (Highlight) -> Int) -> [Int] {
        Array(Set(highlights.map(transform))).sorted(by: >)
    }

    private func uniqueSortedDates(_ transform: (Highlight) -> Date?) -> [Date] {
        Array(Set(highlights.compactMap(transform))).sorted(by: >)
    }

    private func intervalStart(_ component: Calendar.Component, for date: Date) -> Date? {
        calendar.dateInterval(of: component, for: date)?.start
    }

    private func sortedHighlights(_ first: Highlight, _ second: Highlight) -> Bool {
        switch sortMode {
        case .alphabetical:
            let nameComparison = first.dish_name.localizedCaseInsensitiveCompare(second.dish_name)

            if nameComparison == .orderedSame {
                return recencyDate(for: first) > recencyDate(for: second)
            }

            return nameComparison == .orderedAscending
        case .mostRecent:
            return recencyDate(for: first) > recencyDate(for: second)
        }
    }

    private func recencyDate(for highlight: Highlight) -> Date {
        highlight.date_eaten ?? highlight.created_at
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

    private func weekTitle(for interval: DateInterval) -> String {
        let start = interval.start.formatted(.dateTime.month(.abbreviated).day())
        let end = interval.end.addingTimeInterval(-1).formatted(.dateTime.month(.abbreviated).day().year())
        return "\(start) - \(end)"
    }

    enum LocationFilter: String {
        case home = "Home"
        case restaurant = "Restaurant"

        var databaseValue: String {
            rawValue.lowercased()
        }
    }

    enum SortMode {
        case alphabetical
        case mostRecent
    }

    struct MealSection: Identifiable {
        let id: UUID
        let title: String
        let isGroupedMeal: Bool
        let sortDate: Date
        let highlights: [Highlight]
    }

    enum DateFilterGranularity: String, CaseIterable, Identifiable {
        case year = "Year"
        case month = "Month"
        case week = "Week"

        var id: String { rawValue }
    }

    enum DateFilter {
        case year(Int)
        case month(Date)
        case week(DateInterval)

        var title: String {
            switch self {
            case .year(let year):
                return "During \(year)"
            case .month(let date):
                return date.formatted(.dateTime.month(.abbreviated).year())
            case .week(let interval):
                return "Week of \(interval.start.formatted(.dateTime.month(.abbreviated).day()))"
            }
        }

        func contains(_ date: Date, calendar: Calendar) -> Bool {
            switch self {
            case .year(let year):
                return calendar.component(.year, from: date) == year
            case .month(let month):
                guard let interval = calendar.dateInterval(of: .month, for: month) else {
                    return false
                }
                return interval.contains(date)
            case .week(let interval):
                return interval.contains(date)
            }
        }
    }

    private struct DishesTheme {
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
            primaryText.opacity(0.7)
        }

        var controlBackground: Color {
            isDark ? .textPrimary : .containerPrimary
        }

        var cardBackground: Color {
            isDark ? .textPrimary : .containerPrimary
        }

        var highlightCard: HomeView.HighlightCard.Theme {
            HomeView.HighlightCard.Theme(
                background: isDark ? .textPrimary : .surfacePrimary,
                text: isDark ? .backgroundPrimary : .textPrimary,
                fallbackBackground: (isDark ? Color.backgroundDarkPrimary : Color.backgroundPrimary).opacity(0.3)
            )
        }
    }
}

#Preview("Dishes With Local Food Photos") {
    NavigationStack {
        DishesView(
            highlights: .constant(HomeView.previewHighlights),
            occasions: HomeView.previewOccasions,
            previewImageAssets: HomeView.previewImageAssets
        )
    }
}

#Preview("Dishes Dark With Local Food Photos") {
    NavigationStack {
        DishesView(
            highlights: .constant(HomeView.previewHighlights),
            occasions: HomeView.previewOccasions,
            previewImageAssets: HomeView.previewImageAssets
        )
    }
    .preferredColorScheme(.dark)
}
