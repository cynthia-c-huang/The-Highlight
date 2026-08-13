import Foundation
import Testing
@testable import The_Highlight

struct DishDiscoveryPresentationTests {
    @Test func cuisineGroupUsesStoredCuisineBeforeCountries() {
        let dolma = DishReference.previewCatalog.first { $0.name == "Dolma" }

        #expect(dolma?.cuisine == "Turkish")
        #expect(dolma?.cuisineGroup == .turkish)
        #expect(dolma?.discoveryCardCuisineLabel == "Turkish")
    }

    @Test func geographyFormattingIncludesCountriesAndRegionWithoutChangingCuisine() {
        let mandi = DishReference.previewCatalog.first { $0.name == "Mandi" }

        #expect(mandi?.cuisine == "Yemeni")
        #expect(mandi?.cuisineGroup == .middleEastern)
        #expect(mandi?.formattedGeography == "Yemen · Arabian Peninsula")
    }

    @Test @MainActor func cuisineGroupFilterSearchesFullCatalog() {
        let viewModel = DishDiscoveryViewModel(previewDishes: DishReference.previewCatalog)
        viewModel.selectedCuisineGroup = .middleEastern

        let matches = viewModel.filteredDishes(triedDishIDs: [])

        #expect(matches.map(\.name) == ["Mandi"])
        #expect(matches.first?.discoveryCardCuisineLabel == "Yemeni")
    }

    @Test @MainActor func explicitSearchPrioritizesNameMatches() {
        let viewModel = DishDiscoveryViewModel(previewDishes: DishReference.previewCatalog)
        viewModel.searchText = "khao"

        let matches = viewModel.filteredDishes(triedDishIDs: [])

        #expect(matches.first?.name == "Khao Soi")
    }

    @Test @MainActor func defaultAndShuffleOrderingKeepTheWholeCatalog() {
        let dishes = DishReference.previewCatalog
        let defaultOrder = DishDiscoveryViewModel.buildDefaultOrdering(dishes, salt: 0)
        var generator = SeededRandomNumberGenerator(seed: 1)
        let shuffledOrder = DishDiscoveryViewModel.buildShuffledOrdering(dishes, using: &generator)

        #expect(defaultOrder.count == dishes.count)
        #expect(shuffledOrder.count == dishes.count)
        #expect(Set(defaultOrder.map(\.id)) == Set(dishes.map(\.id)))
        #expect(Set(shuffledOrder.map(\.id)) == Set(dishes.map(\.id)))
    }

    @Test @MainActor func shuffleChangesFirstVisibleDishWithoutFilters() {
        expectShuffleChangesFirstVisibleDish()
    }

    @Test @MainActor func shuffleChangesFirstVisibleDishWithCuisineFilter() {
        expectShuffleChangesFirstVisibleDish { viewModel in
            viewModel.selectedCuisineGroup = .korean
        }
    }

    @Test @MainActor func shuffleChangesFirstVisibleDishWithFlavorFilter() {
        expectShuffleChangesFirstVisibleDish { viewModel in
            viewModel.selectedDescriptionTag = "Savory"
        }
    }

    @Test @MainActor func shuffleChangesFirstVisibleDishWithDietaryFilter() {
        expectShuffleChangesFirstVisibleDish { viewModel in
            viewModel.selectedDietaryFilter = .vegetarian
        }
    }

    @Test @MainActor func shuffleChangesFirstVisibleDishWithTextSearch() {
        expectShuffleChangesFirstVisibleDish { viewModel in
            viewModel.searchText = "noodle"
        }
    }

    @Test @MainActor func shuffleChangesFirstVisibleDishWithMultipleFilters() {
        expectShuffleChangesFirstVisibleDish { viewModel in
            viewModel.searchText = "noodle"
            viewModel.selectedCuisineGroup = .korean
            viewModel.selectedDescriptionTag = "Savory"
            viewModel.selectedDietaryFilter = .vegetarian
        }
    }

    @Test @MainActor func filtersPreserveCurrentShuffledOrdering() {
        let viewModel = DishDiscoveryViewModel(previewDishes: shuffleTestCatalog)
        var generator = SeededRandomNumberGenerator(seed: 7)

        viewModel.shuffleDishes(triedDishIDs: [], using: &generator)
        let shuffledFullOrder = viewModel.filteredDishes(triedDishIDs: [])

        viewModel.selectedCuisineGroup = .korean
        let filteredOrder = viewModel.filteredDishes(triedDishIDs: [])

        #expect(filteredOrder.map(\.id) == shuffledFullOrder.filter { $0.cuisineGroup == .korean }.map(\.id))
    }

    @Test @MainActor func defaultOrderingAvoidsThreeItemCuisineGroupClustersWhenPossible() {
        let orderedDishes = DishDiscoveryViewModel.buildDefaultOrdering(DishReference.previewCatalog, salt: 0)

        for index in orderedDishes.indices.dropFirst(2) {
            let recentGroups = [
                orderedDishes[index - 2].cuisineGroup,
                orderedDishes[index - 1].cuisineGroup,
                orderedDishes[index].cuisineGroup
            ]

            #expect(Set(recentGroups).count > 1)
        }
    }

    @Test func continentArtworkUsesStoredContinentValues() {
        let expectations: [(String, String)] = [
            ("Africa", "Africa"),
            ("Asia", "Asia"),
            ("Europe", "Europe"),
            ("North America", "North America"),
            ("South America", "South America"),
            ("Oceania", "Oceania")
        ]

        for (continent, assetName) in expectations {
            let dish = makeDishReference(
                name: "\(continent) dish",
                countries: [continent],
                region: "Intentionally ambiguous region",
                continent: continent
            )

            #expect(DishContinentArtwork.assetName(for: dish) == assetName)
        }
    }

    @Test func storedContinentOverridesAmbiguousRegionNames() {
        let menaDish = makeDishReference(
            name: "MENA dish",
            countries: ["Yemen"],
            region: "Middle East & North Africa",
            continent: "Asia"
        )

        let latinCaribbeanDish = makeDishReference(
            name: "Latin Caribbean dish",
            countries: ["Peru", "Puerto Rico"],
            region: "Latin America & Caribbean",
            continent: "South America"
        )

        let multiCountryDish = makeDishReference(
            name: "Multi-country dish",
            countries: ["Vietnam", "United States", "France"],
            region: "Southeast Asia",
            continent: "Asia"
        )

        #expect(DishContinentArtwork.assetName(for: menaDish) == "Asia")
        #expect(DishContinentArtwork.assetName(for: latinCaribbeanDish) == "South America")
        #expect(DishContinentArtwork.assetName(for: multiCountryDish) == "Asia")
    }

    @Test func legacyContinentFallbackIsOnlyForMissingContinent() {
        let fallbackDish = makeDishReference(
            name: "Fallback dish",
            countries: ["Kazakhstan"],
            region: "Central Asia & Caucasus",
            continent: nil
        )

        #expect(DishContinentArtwork.assetName(for: fallbackDish) == "Asia")
    }

    @Test func countryDisplayPreservesMultiWordCountryNames() {
        #expect(DishCountryDisplay.text(countries: ["Jamaica"], region: "Latin America & Caribbean") == "Jamaica")
        #expect(DishCountryDisplay.text(countries: ["Jamaica", "Trinidad and Tobago"], region: "Latin America & Caribbean") == "Jamaica, Trinidad and Tobago")
        #expect(DishCountryDisplay.text(countries: ["Jamaica", "Trinidad and Tobago", "Guyana"], region: "Latin America & Caribbean") == "Jamaica, Trinidad and Tobago, Guyana")
    }

    @Test func countryDisplayShowsSixCountriesBeforeSummarizing() {
        let countries = ["Lebanon", "Syria", "Iraq", "Jordan", "Palestine", "Turkey"]

        #expect(DishCountryDisplay.text(countries: countries, region: "Middle East & North Africa") == "Lebanon, Syria, Iraq, Jordan, Palestine, Turkey")
    }

    @Test func countryDisplaySummarizesExceptionallyLongCountryLists() {
        let countries = ["Lebanon", "Syria", "Iraq", "Jordan", "Palestine", "Turkey", "Armenia", "Azerbaijan"]

        #expect(DishCountryDisplay.text(countries: countries, region: "Middle East & North Africa") == "Lebanon, Syria, Iraq, Jordan +4 more")
    }

    private func makeDishReference(
        name: String,
        countries: [String],
        region: String,
        continent: String?,
        cuisine: String = "Preview",
        category: String = "Preview",
        familiarity: String = "Preview",
        restaurantAccessibility: String? = nil,
        descriptionTags: [String] = ["Preview", "Test", "Catalog"],
        dietaryTags: [String] = [],
        searchKeywords: [String] = []
    ) -> DishReference {
        DishReference(
            id: UUID(),
            name: name,
            alternateNames: [],
            countries: countries,
            region: region,
            continent: continent,
            cuisine: cuisine,
            category: category,
            familiarity: familiarity,
            restaurantAccessibility: restaurantAccessibility,
            shortDescription: "Preview dish.",
            longDescription: "Preview dish.",
            descriptionTags: descriptionTags,
            dietaryTags: dietaryTags,
            searchKeywords: searchKeywords,
            originNote: nil,
            relatedDishes: [],
            contentStatus: "published",
            createdAt: Date(timeIntervalSince1970: 1_780_000_000)
        )
    }

    @MainActor
    private func expectShuffleChangesFirstVisibleDish(
        configure: (DishDiscoveryViewModel) -> Void = { _ in }
    ) {
        let viewModel = DishDiscoveryViewModel(previewDishes: shuffleTestCatalog)
        configure(viewModel)

        let previousDishes = viewModel.filteredDishes(triedDishIDs: [])
        var generator = SeededRandomNumberGenerator(seed: 7)

        viewModel.shuffleDishes(triedDishIDs: [], using: &generator)

        let newDishes = viewModel.filteredDishes(triedDishIDs: [])

        #expect(previousDishes.count > 1)
        #expect(Set(previousDishes.map(\.id)) == Set(newDishes.map(\.id)))
        #expect(previousDishes.first?.id != newDishes.first?.id)
        #expect(changedPositionCount(previousDishes, newDishes) >= min(4, previousDishes.count))
    }

    private func changedPositionCount(_ previousDishes: [DishReference], _ newDishes: [DishReference]) -> Int {
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

    private var shuffleTestCatalog: [DishReference] {
        [
            makeDishReference(
                name: "Noodle Alpha",
                countries: ["Korea"],
                region: "East Asia",
                continent: "Asia",
                cuisine: "Korean",
                category: "Noodles",
                familiarity: "Familiar",
                restaurantAccessibility: "High",
                descriptionTags: ["Savory", "Spicy", "Comforting"],
                dietaryTags: ["Vegetarian"],
                searchKeywords: ["noodle"]
            ),
            makeDishReference(
                name: "Noodle Beta",
                countries: ["Korea"],
                region: "East Asia",
                continent: "Asia",
                cuisine: "Korean",
                category: "Soup",
                familiarity: "Moderate",
                restaurantAccessibility: "Medium",
                descriptionTags: ["Savory", "Brothy", "Comforting"],
                dietaryTags: ["Commonly vegetarian"],
                searchKeywords: ["noodle"]
            ),
            makeDishReference(
                name: "Noodle Gamma",
                countries: ["Korea"],
                region: "East Asia",
                continent: "Asia",
                cuisine: "Korean",
                category: "Stir fry",
                familiarity: "Discover",
                restaurantAccessibility: "Low",
                descriptionTags: ["Savory", "Chewy", "Spicy"],
                dietaryTags: ["Vegetarian"],
                searchKeywords: ["noodle"]
            ),
            makeDishReference(
                name: "Noodle Delta",
                countries: ["Korea"],
                region: "East Asia",
                continent: "Asia",
                cuisine: "Korean",
                category: "Salad",
                familiarity: "Familiar",
                restaurantAccessibility: "High",
                descriptionTags: ["Savory", "Fresh", "Tangy"],
                dietaryTags: ["Commonly vegetarian"],
                searchKeywords: ["noodle"]
            ),
            makeDishReference(
                name: "Pasta Verde",
                countries: ["Italy"],
                region: "Europe",
                continent: "Europe",
                cuisine: "Italian",
                category: "Pasta",
                familiarity: "Familiar",
                restaurantAccessibility: "High",
                descriptionTags: ["Herby", "Savory", "Silky"],
                dietaryTags: ["Vegetarian"],
                searchKeywords: ["pasta"]
            ),
            makeDishReference(
                name: "Taco Claro",
                countries: ["Mexico"],
                region: "North America",
                continent: "North America",
                cuisine: "Mexican",
                category: "Taco",
                familiarity: "Familiar",
                restaurantAccessibility: "High",
                descriptionTags: ["Bright", "Savory", "Fresh"],
                dietaryTags: ["Contains meat"],
                searchKeywords: ["taco"]
            )
        ]
    }

    private struct SeededRandomNumberGenerator: RandomNumberGenerator {
        var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func next() -> UInt64 {
            state = state &* 2_862_933_555_777_941_757 &+ 3_037_000_493
            return state
        }
    }
}
