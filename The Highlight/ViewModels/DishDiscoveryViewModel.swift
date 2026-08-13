import Combine
import Foundation

enum DietaryFilterOption: String, CaseIterable, Hashable, Identifiable {
    case vegetarian
    case vegan
    case containsMeat
    case containsSeafood
    case varies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vegetarian:
            return "Vegetarian"
        case .vegan:
            return "Vegan"
        case .containsMeat:
            return "Contains meat"
        case .containsSeafood:
            return "Contains seafood"
        case .varies:
            return "Varies"
        }
    }

    func matches(dietaryTags: [String]) -> Bool {
        dietaryTags.contains { matches(tag: $0) }
    }

    private func matches(tag: String) -> Bool {
        let normalizedText = tag.normalizedDietaryFilterText
        let compactText = normalizedText.replacingOccurrences(of: " ", with: "")

        switch self {
        case .vegetarian:
            guard !containsAny(["non vegetarian", "not vegetarian"], in: normalizedText, compactText: compactText) else {
                return false
            }
            return containsAny(["vegetarian"], in: normalizedText, compactText: compactText)
        case .vegan:
            guard !containsAny(["non vegan", "not vegan"], in: normalizedText, compactText: compactText) else {
                return false
            }
            return containsAny(["vegan"], in: normalizedText, compactText: compactText)
        case .containsMeat:
            guard !containsAny(["no meat", "without meat", "meat free", "meatless"], in: normalizedText, compactText: compactText) else {
                return false
            }
            return containsAny([
                "meat", "pork", "beef", "chicken", "lamb", "duck", "goat", "sausage", "bacon", "ham", "gelatin", "animal product"
            ], in: normalizedText, compactText: compactText)
        case .containsSeafood:
            guard !containsAny(["no seafood", "without seafood", "seafood free"], in: normalizedText, compactText: compactText) else {
                return false
            }
            return containsAny([
                "seafood", "fish", "shrimp", "prawn", "shellfish", "crab", "lobster", "clam", "oyster", "mussel", "anchovy", "squid"
            ], in: normalizedText, compactText: compactText)
        case .varies:
            return containsAny([
                "varies", "vary", "variable", "depends", "by preparation", "by recipe", "preparation dependent", "recipe dependent"
            ], in: normalizedText, compactText: compactText)
        }
    }

    private func containsAny(_ phrases: [String], in normalizedText: String, compactText: String) -> Bool {
        phrases.contains { phrase in
            let normalizedPhrase = phrase.normalizedDietaryFilterText
            let compactPhrase = normalizedPhrase.replacingOccurrences(of: " ", with: "")
            return normalizedText.contains(normalizedPhrase) || compactText.contains(compactPhrase)
        }
    }
}

enum TriedFilterOption: String, CaseIterable, Hashable, Identifiable {
    case tried
    case notTried

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tried:
            return "Tried"
        case .notTried:
            return "Not Tried"
        }
    }

    var menuTitle: String {
        switch self {
        case .tried:
            return "Yes"
        case .notTried:
            return "No"
        }
    }

    func matches(isTried: Bool) -> Bool {
        switch self {
        case .tried:
            return isTried
        case .notTried:
            return !isTried
        }
    }
}

private extension String {
    var normalizedDietaryFilterText: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

@MainActor
final class DishDiscoveryViewModel: ObservableObject {
    @Published private(set) var dishes: [DishReference]
    @Published private(set) var orderedDishIDs: [UUID]
    @Published var searchText: String = ""
    @Published var selectedCuisineGroup: CuisineGroup?
    @Published var selectedDescriptionTag: String?
    @Published var selectedDietaryFilter: DietaryFilterOption?
    @Published var selectedTriedFilter: TriedFilterOption?

    private var orderingSalt: Int

    init(previewDishes: [DishReference]? = nil) {
        let initialDishes = previewDishes ?? []
        let initialOrdering = Self.buildDefaultOrdering(initialDishes, salt: 0)

        self.dishes = initialDishes
        self.orderedDishIDs = initialOrdering.map(\.id)
        self.orderingSalt = 0

        #if DEBUG
        if previewDishes != nil {
            Self.logDefaultOrderingDiagnostics(allDishes: initialDishes, orderedDishes: initialOrdering)
        }
        #endif
    }

    func applyCatalog(_ catalogDishes: [DishReference], forceRebuildOrdering: Bool = false) {
        let currentIDs = dishes.map(\.id)
        let catalogIDs = catalogDishes.map(\.id)
        let shouldRebuildOrdering = forceRebuildOrdering || currentIDs != catalogIDs

        dishes = catalogDishes

        guard shouldRebuildOrdering else { return }

        #if DEBUG
        let clock = ContinuousClock()
        let orderingStart = clock.now
        #endif

        let defaultOrdering = Self.buildDefaultOrdering(catalogDishes, salt: orderingSalt)
        orderedDishIDs = defaultOrdering.map(\.id)

        #if DEBUG
        let orderingDuration = orderingStart.duration(to: clock.now)
        print("[DishDiscoveryTiming] default ordering: \(DishDiscoveryPerformanceLogger.milliseconds(for: orderingDuration)) ms")
        Self.logDefaultOrderingDiagnostics(allDishes: catalogDishes, orderedDishes: defaultOrdering)
        #endif
    }

    func applyRefreshedCatalog(_ catalogDishes: [DishReference]) {
        orderingSalt += 1
        applyCatalog(catalogDishes, forceRebuildOrdering: true)
    }

    func filteredDishes(triedDishIDs: Set<UUID>) -> [DishReference] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return filteredDishes(in: orderedDishes, query: query, triedDishIDs: triedDishIDs)
    }

    var availableCuisineGroups: [CuisineGroup] {
        let availableGroups = Set(dishes.map(\.cuisineGroup))
        return CuisineGroup.allCases.filter { availableGroups.contains($0) }
    }

    var availableDescriptionTags: [String] {
        uniqueSortedValues(dishes.flatMap(\.descriptionTags))
    }

    var availableDietaryFilters: [DietaryFilterOption] {
        DietaryFilterOption.allCases
    }

    var hasActiveFilters: Bool {
        selectedCuisineGroup != nil || selectedDescriptionTag != nil || selectedDietaryFilter != nil || selectedTriedFilter != nil
    }

    var isCatalogEmpty: Bool {
        dishes.isEmpty
    }

    func shuffleDishes() {
        shuffleDishes(triedDishIDs: [])
    }

    func shuffleDishes(triedDishIDs: Set<UUID>) {
        var generator = SystemRandomNumberGenerator()
        shuffleDishes(triedDishIDs: triedDishIDs, using: &generator)
    }

    func shuffleDishes<Generator: RandomNumberGenerator>(
        triedDishIDs: Set<UUID> = [],
        using generator: inout Generator
    ) {
        guard dishes.count > 1 else { return }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousVisibleDishes = filteredDishes(in: orderedDishes, query: query, triedDishIDs: triedDishIDs)
        let newOrdering = buildBestShuffledOrdering(
            previousVisibleDishes: previousVisibleDishes,
            query: query,
            triedDishIDs: triedDishIDs,
            generator: &generator
        )
        let newVisibleDishes = filteredDishes(in: newOrdering, query: query, triedDishIDs: triedDishIDs)

        orderedDishIDs = newOrdering.map(\.id)

        #if DEBUG
        Self.logShuffleDiagnostics(previousDishes: previousVisibleDishes, newDishes: newVisibleDishes)
        #endif
    }

    func toggleCuisineGroup(_ cuisineGroup: CuisineGroup) {
        selectedCuisineGroup = selectedCuisineGroup == cuisineGroup ? nil : cuisineGroup
    }

    func toggleDescriptionTag(_ tag: String) {
        selectedDescriptionTag = selectedDescriptionTag == tag ? nil : tag
    }

    func toggleDietaryFilter(_ filter: DietaryFilterOption) {
        selectedDietaryFilter = selectedDietaryFilter == filter ? nil : filter
    }

    func toggleTriedFilter(_ filter: TriedFilterOption) {
        selectedTriedFilter = selectedTriedFilter == filter ? nil : filter
    }

    func clearFilters() {
        selectedCuisineGroup = nil
        selectedDescriptionTag = nil
        selectedDietaryFilter = nil
        selectedTriedFilter = nil
    }

    private func uniqueSortedValues(_ values: [String]) -> [String] {
        Array(
            Set(
                values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var orderedDishes: [DishReference] {
        let dishesByID = Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0) })
        let ordered = orderedDishIDs.compactMap { dishesByID[$0] }

        if ordered.count == dishes.count {
            return ordered
        }

        let orderedIDs = Set(ordered.map(\.id))
        return ordered + dishes.filter { !orderedIDs.contains($0.id) }
    }

    private func filteredDishes(
        in orderedBaseDishes: [DishReference],
        query: String,
        triedDishIDs: Set<UUID>
    ) -> [DishReference] {
        orderedBaseDishes.filter { dish in
            if !query.isEmpty && !dish.searchableText.localizedCaseInsensitiveContains(query) {
                return false
            }

            if let selectedCuisineGroup, dish.cuisineGroup != selectedCuisineGroup {
                return false
            }

            if let selectedDescriptionTag, !dish.descriptionTags.contains(where: { $0.localizedCaseInsensitiveCompare(selectedDescriptionTag) == .orderedSame }) {
                return false
            }

            if let selectedDietaryFilter, !selectedDietaryFilter.matches(dietaryTags: dish.dietaryTags) {
                return false
            }

            if let selectedTriedFilter, !selectedTriedFilter.matches(isTried: triedDishIDs.contains(dish.id)) {
                return false
            }

            return true
        }
    }

    private func buildBestShuffledOrdering<Generator: RandomNumberGenerator>(
        previousVisibleDishes: [DishReference],
        query: String,
        triedDishIDs: Set<UUID>,
        generator: inout Generator
    ) -> [DishReference] {
        var bestOrdering = Self.buildShuffledOrdering(dishes, using: &generator)
        var bestVisibleDishes = filteredDishes(in: bestOrdering, query: query, triedDishIDs: triedDishIDs)
        var bestScore = Self.shuffleChangeScore(previousDishes: previousVisibleDishes, newDishes: bestVisibleDishes)

        guard previousVisibleDishes.count > 1 else {
            return bestOrdering
        }

        for _ in 0..<11 {
            let candidateOrdering = Self.buildShuffledOrdering(dishes, using: &generator)
            let candidateVisibleDishes = filteredDishes(in: candidateOrdering, query: query, triedDishIDs: triedDishIDs)
            let candidateScore = Self.shuffleChangeScore(previousDishes: previousVisibleDishes, newDishes: candidateVisibleDishes)

            if candidateScore > bestScore {
                bestOrdering = candidateOrdering
                bestVisibleDishes = candidateVisibleDishes
                bestScore = candidateScore
            }

            if Self.isSubstantialShuffle(previousDishes: previousVisibleDishes, newDishes: candidateVisibleDishes) {
                return candidateOrdering
            }
        }

        return orderingWithChangedFirstVisibleDishIfPossible(
            bestOrdering,
            previousVisibleDishes: previousVisibleDishes,
            newVisibleDishes: bestVisibleDishes
        )
    }

    private func orderingWithChangedFirstVisibleDishIfPossible(
        _ ordering: [DishReference],
        previousVisibleDishes: [DishReference],
        newVisibleDishes: [DishReference]
    ) -> [DishReference] {
        guard let previousFirstID = previousVisibleDishes.first?.id,
              newVisibleDishes.first?.id == previousFirstID,
              let replacementID = newVisibleDishes.dropFirst().first?.id,
              let replacementIndex = ordering.firstIndex(where: { $0.id == replacementID })
        else {
            return ordering
        }

        var adjustedOrdering = ordering
        let replacementDish = adjustedOrdering.remove(at: replacementIndex)

        guard let previousFirstIndex = adjustedOrdering.firstIndex(where: { $0.id == previousFirstID }) else {
            return ordering
        }

        adjustedOrdering.insert(replacementDish, at: previousFirstIndex)
        return adjustedOrdering
    }

    static func buildDefaultOrdering(_ dishes: [DishReference], salt: Int = 0) -> [DishReference] {
        buildWeightedOrdering(
            dishes,
            familiarityCycle: [.familiar, .familiar, .familiar, .familiar, .familiar, .moderate, .moderate, .moderate, .discovery, .discovery],
            salt: salt
        )
    }

    static func buildShuffledOrdering(_ dishes: [DishReference]) -> [DishReference] {
        var generator = SystemRandomNumberGenerator()
        return buildShuffledOrdering(dishes, using: &generator)
    }

    static func buildShuffledOrdering<Generator: RandomNumberGenerator>(
        _ dishes: [DishReference],
        using generator: inout Generator
    ) -> [DishReference] {
        repairShuffledClusters(dishes.shuffled(using: &generator))
    }

    private static func repairShuffledClusters(_ shuffledDishes: [DishReference]) -> [DishReference] {
        var remainingDishes = shuffledDishes
        var result: [DishReference] = []

        while !remainingDishes.isEmpty {
            if let index = remainingDishes.firstIndex(where: { !wouldCreateCluster(dish: $0, result: result) }) {
                result.append(remainingDishes.remove(at: index))
            } else {
                result.append(remainingDishes.removeFirst())
            }
        }

        return result
    }

    private static func shuffleChangeScore(previousDishes: [DishReference], newDishes: [DishReference]) -> Int {
        let firstChangedScore = previousDishes.first?.id != newDishes.first?.id ? 100 : 0
        return firstChangedScore + changedPositionCount(previousDishes: previousDishes, newDishes: newDishes)
    }

    private static func isSubstantialShuffle(previousDishes: [DishReference], newDishes: [DishReference]) -> Bool {
        guard previousDishes.count > 1, newDishes.count > 1 else { return true }

        let firstChanged = previousDishes.first?.id != newDishes.first?.id
        let leadingCount = min(10, max(previousDishes.count, newDishes.count))
        let minimumChangedPositions = min(6, max(1, leadingCount / 2))

        return firstChanged && changedPositionCount(previousDishes: previousDishes, newDishes: newDishes) >= minimumChangedPositions
    }

    private static func changedPositionCount(previousDishes: [DishReference], newDishes: [DishReference]) -> Int {
        let previousIDs = previousDishes.prefix(10).map(\.id)
        let newIDs = newDishes.prefix(10).map(\.id)
        let leadingCount = max(previousIDs.count, newIDs.count)
        var changedPositions = 0

        for index in 0..<leadingCount {
            let previousID = index < previousIDs.count ? previousIDs[index] : nil
            let newID = index < newIDs.count ? newIDs[index] : nil

            if previousID != newID {
                changedPositions += 1
            }
        }

        return changedPositions
    }

    private static func buildWeightedOrdering(
        _ dishes: [DishReference],
        familiarityCycle: [FamiliarityTier],
        salt: Int
    ) -> [DishReference] {
        guard !dishes.isEmpty else { return [] }

        let candidates = dishes.map { OrderingCandidate(dish: $0, salt: salt) }
        var remaining = Dictionary(grouping: candidates, by: \.familiarityTier)
        for tier in FamiliarityTier.allCases {
            remaining[tier] = sortedCandidates(remaining[tier] ?? [])
        }

        var result: [OrderingCandidate] = []
        var cycleIndex = 0

        while result.count < dishes.count {
            let preferredTier = familiarityCycle[cycleIndex % familiarityCycle.count]
            cycleIndex += 1

            guard let nextCandidate = takeNextDish(preferredTier: preferredTier, remaining: &remaining, result: result) else {
                break
            }

            result.append(nextCandidate)
        }

        return result.map(\.dish)
    }

    private static func takeNextDish(
        preferredTier: FamiliarityTier,
        remaining: inout [FamiliarityTier: [OrderingCandidate]],
        result: [OrderingCandidate]
    ) -> OrderingCandidate? {
        let tierOrder = [preferredTier] + FamiliarityTier.allCases.filter { $0 != preferredTier }

        for tier in tierOrder {
            guard var candidates = remaining[tier], !candidates.isEmpty else { continue }

            if let index = candidates.firstIndex(where: { !wouldCreateCluster(candidate: $0, result: result) }) {
                let candidate = candidates.remove(at: index)
                remaining[tier] = candidates
                return candidate
            }
        }

        for tier in tierOrder {
            guard var candidates = remaining[tier], !candidates.isEmpty else { continue }
            let candidate = candidates.removeFirst()
            remaining[tier] = candidates
            return candidate
        }

        return nil
    }

    private static func sortedCandidates(_ candidates: [OrderingCandidate]) -> [OrderingCandidate] {
        candidates.sorted { first, second in
            if first.accessibilityLevel.sortPriority != second.accessibilityLevel.sortPriority {
                return first.accessibilityLevel.sortPriority < second.accessibilityLevel.sortPriority
            }

            if first.stableOrder != second.stableOrder {
                return first.stableOrder < second.stableOrder
            }

            return first.dish.name.localizedCaseInsensitiveCompare(second.dish.name) == .orderedAscending
        }
    }

    private static func wouldCreateCluster(candidate: OrderingCandidate, result: [OrderingCandidate]) -> Bool {
        guard result.count >= 2 else { return false }

        let recentCandidates = result.suffix(2)

        if recentCandidates.allSatisfy({ $0.cuisineGroup == candidate.cuisineGroup }) {
            return true
        }

        if !candidate.normalizedCuisine.isEmpty && recentCandidates.allSatisfy({ $0.normalizedCuisine == candidate.normalizedCuisine }) {
            return true
        }

        if !candidate.normalizedCategory.isEmpty && recentCandidates.allSatisfy({ $0.normalizedCategory == candidate.normalizedCategory }) {
            return true
        }

        return false
    }

    private static func wouldCreateCluster(dish: DishReference, result: [DishReference]) -> Bool {
        guard result.count >= 2 else { return false }

        let recentDishes = result.suffix(2)
        let normalizedCuisine = normalizedExactValue(dish.cuisine)
        let normalizedCategory = normalizedExactValue(dish.category)

        if recentDishes.allSatisfy({ $0.cuisineGroup == dish.cuisineGroup }) {
            return true
        }

        if !normalizedCuisine.isEmpty && recentDishes.allSatisfy({ normalizedExactValue($0.cuisine) == normalizedCuisine }) {
            return true
        }

        if !normalizedCategory.isEmpty && recentDishes.allSatisfy({ normalizedExactValue($0.category) == normalizedCategory }) {
            return true
        }

        return false
    }

    private static func familiarityTier(for dish: DishReference) -> FamiliarityTier {
        let value = dish.familiarity.normalizedDiscoverySearchText

        if value.contains("familiar") {
            return .familiar
        }

        if value.contains("moderate") || value.contains("medium") {
            return .moderate
        }

        if value.contains("discover") || value.contains("discovery") || value.contains("unfamiliar") || value.contains("adventurous") {
            return .discovery
        }

        return .moderate
    }

    private static func accessibilityLevel(for dish: DishReference) -> AccessibilityLevel {
        guard let value = dish.restaurantAccessibility?.normalizedDiscoverySearchText, !value.isEmpty else {
            return .low
        }

        if value.contains("high") {
            return .high
        }

        if value.contains("medium") || value.contains("moderate") {
            return .medium
        }

        if value.contains("low") {
            return .low
        }

        if value.contains("common")
            || value.contains("widely")
            || value.contains("many")
            || value.contains("easy")
            || value.contains("readily")
            || value.contains("accessible") {
            return .high
        }

        if value.contains("rare")
            || value.contains("hard")
            || value.contains("difficult")
            || value.contains("limited")
            || value.contains("seek")
            || value.contains("home style")
            || value.contains("home cooking") {
            return .low
        }

        return .medium
    }

    private static func normalizedExactValue(_ value: String) -> String {
        value.normalizedDiscoverySearchText
    }

    private static func stableOrderValue(for dish: DishReference, salt: Int) -> UInt64 {
        let key = "\(dish.id.uuidString)|\(dish.name)|\(salt)"
        var hash: UInt64 = 14_695_981_039_346_656_037

        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        return hash
    }

    private enum FamiliarityTier: String, CaseIterable {
        case familiar = "Familiar"
        case moderate = "Moderate"
        case discovery = "Discovery"
    }

    private enum AccessibilityLevel: String, CaseIterable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var sortPriority: Int {
            switch self {
            case .high:
                return 0
            case .medium:
                return 1
            case .low:
                return 2
            }
        }
    }

    private struct OrderingCandidate {
        let dish: DishReference
        let familiarityTier: FamiliarityTier
        let accessibilityLevel: AccessibilityLevel
        let cuisineGroup: CuisineGroup
        let normalizedCuisine: String
        let normalizedCategory: String
        let stableOrder: UInt64

        init(dish: DishReference, salt: Int) {
            self.dish = dish
            self.familiarityTier = DishDiscoveryViewModel.familiarityTier(for: dish)
            self.accessibilityLevel = DishDiscoveryViewModel.accessibilityLevel(for: dish)
            self.cuisineGroup = dish.cuisineGroup
            self.normalizedCuisine = DishDiscoveryViewModel.normalizedExactValue(dish.cuisine)
            self.normalizedCategory = DishDiscoveryViewModel.normalizedExactValue(dish.category)
            self.stableOrder = DishDiscoveryViewModel.stableOrderValue(for: dish, salt: salt)
        }
    }

    #if DEBUG
    private static func logDefaultOrderingDiagnostics(allDishes: [DishReference], orderedDishes: [DishReference]) {
        print("[DishDiscovery] total catalog count: \(allDishes.count)")
        print("[DishDiscovery] familiarity counts: \(countsDescription(FamiliarityTier.allCases, values: allDishes.map(familiarityTier(for:))))")
        print("[DishDiscovery] restaurant accessibility counts: \(countsDescription(AccessibilityLevel.allCases, values: allDishes.map(accessibilityLevel(for:))))")
        print("[DishDiscovery] cuisine group counts: \(countsDescription(CuisineGroup.allCases, values: allDishes.map(\.cuisineGroup)))")

        let firstTwenty = orderedDishes.prefix(20).enumerated().map { index, dish in
            "\(index + 1). \(dish.name) — \(dish.discoveryCardCuisineLabel) · \(dish.cuisineGroup.title) · \(dish.familiarity) · \(dish.restaurantAccessibility ?? "No accessibility value")"
        }
        print("[DishDiscovery] first 20 default order:\n\(firstTwenty.joined(separator: "\n"))")

        let otherDishes = allDishes
            .filter { $0.cuisineGroup == .other }
            .map(\.name)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        if !otherDishes.isEmpty {
            print("[DishDiscovery] Other cuisine group dishes: \(otherDishes.joined(separator: ", "))")
        }
    }

    private static func logShuffleDiagnostics(previousDishes: [DishReference], newDishes: [DishReference]) {
        let previousFirstTen = previousDishes.prefix(10).map(shuffleLogLine(for:))
        let newFirstTen = newDishes.prefix(10).map(shuffleLogLine(for:))
        let changedPositions = changedPositionCount(previousDishes: previousDishes, newDishes: newDishes)
        let firstChanged = previousDishes.first?.id != newDishes.first?.id

        print("[DishDiscoveryShuffle] previous first 10:\n\(previousFirstTen.joined(separator: "\n"))")
        print("[DishDiscoveryShuffle] new first 10:\n\(newFirstTen.joined(separator: "\n"))")
        print("[DishDiscoveryShuffle] first 10 positions changed: \(changedPositions)")
        print("[DishDiscoveryShuffle] first dish changed: \(firstChanged)")
    }

    private static func shuffleLogLine(for dish: DishReference) -> String {
        "\(dish.id.uuidString) — \(dish.name)"
    }

    private static func countsDescription<Value: CaseIterable & Hashable & RawRepresentable>(
        _ allValues: Value.AllCases,
        values: [Value]
    ) -> String where Value.RawValue == String {
        let counts = Dictionary(grouping: values, by: { $0 }).mapValues(\.count)
        return allValues
            .map { "\($0.rawValue): \(counts[$0, default: 0])" }
            .joined(separator: ", ")
    }
    #endif
}

private extension String {
    var normalizedDiscoverySearchText: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
