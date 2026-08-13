import Combine
import Foundation
import MapKit
//It generates autocomplete suggestions while the user types.
//It resolves one selected suggestion into a full DishLocation.

//@MainActor means the view model’s normal properties and methods run on the main actor. That matters because it updates UI-observed state
@MainActor

//The class inherits from NSObject because it acts as the delegate of MKLocalSearchCompleter, an Objective-C-based MapKit API.
//It conforms to ObservableObject so SwiftUI can observe its @Published properties.
final class LocationSearchViewModel: NSObject, ObservableObject {
    //whenever one of these changes, LocationSearchView may redraw.
    @Published private(set) var query: String = "" //stores the text currently displayed in the search field. private(set) means other code may read query, but only LocationSearchViewModel may directly assign to it
    @Published private(set) var suggestions: [MKLocalSearchCompletion] = [] //holds the autocomplete results returned by MapKit. Each MKLocalSearchCompletion is a suggestion, usually containing a title and subtitle. It is not yet a complete location with coordinates.
    @Published private(set) var isSearching: Bool = false //controls UI during autocomplete suggestion loading and final suggestion resolution
    @Published var errorMessage: String? //shown by LocationSearchView when suggestion lookup or resolution fails.

    private let completer = MKLocalSearchCompleter() //Apple MapKit’s autocomplete engine.
    private var queryTask: Task<Void, Never>? //stores the pending debounce task. The view model keeps a reference so it can cancel the previous task whenever the user types another character.

    override init() {
        super.init()
        completer.delegate = self /*view model becomes the completer’s delegate. completer performs the autocomplete search, but it needs somewhere to report that it found new suggestions or that the suggestion search failed. This line tells it where to report those events. self is the current LocationSearchViewModel instance.*/
        completer.resultTypes = [.address, .pointOfInterest] //asks the autocomplete engine for two broad result types, an address or a point of interest (i.e. Blue Bottle Coffee) like a restaurant name
        //restricts the point-of-interest side of autocomplete to food-related categories.
        completer.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .bakery,
            .brewery,
            .cafe,
            .foodMarket,
            .restaurant,
            .winery
        ])
    }

    func updateQuery(_ newValue: String) {
        query = newValue //because query is published, the text field and any dependent UI stay synchronized.
        errorMessage = nil //A previous failure should not remain visible after the user starts a new search.
        queryTask?.cancel() //Cancel the pending debounce. Only the most recent query should eventually be submitted.

        let trimmedQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines) //This prevents spaces from counting as a meaningful query.
        //If the user clears the field or enters only whitespace, then it will stop the loading indicator,
        //remove existing suggestions, clear the completer’s active query, and leave the function
        guard !trimmedQuery.isEmpty else {
            isSearching = false
            suggestions = []
            completer.queryFragment = ""
            return
        }
        //if the query is not empty
        queryTask = Task { [weak self] in //because the task could outlive the viewmodel, [weak self] ensures the task does not strongly keep the view model alive.
            try? await Task.sleep(nanoseconds: 300_000_000)
            //Without debounce, every keystroke could immediately trigger a new search fragment. Typing a word could cause
            //repeated requests, resulting in unnecessary work, rapidly changing suggestions, more MapKit requests, potential race conditions, and flickering UI.
            //A 300 ms debounce waits until the user pauses typing for about 0.3 seconds before sending the latest query to the completer.

            guard !Task.isCancelled else { return } //If another keystroke arrived during those 300 ms, updateQuery canceled this task. The canceled task exits without submitting an old query.
            self?.performCompletionSearch(for: trimmedQuery) //If the user paused and the view model still exists, the latest trimmed query is passed to the completer.
        }
    }

    func clearSearch() { //returns the whole autocomplete system to its initial state. This is called when the user taps the clear icon and after successfully choosing a suggestion.
        query = ""
        suggestions = []
        isSearching = false
        errorMessage = nil
        queryTask?.cancel()
        completer.queryFragment = ""
    }
    //when the user taps the suggested place
    //This is the suggestion the user tapped. V
    func resolve(_ completion: MKLocalSearchCompletion) async -> DishLocation? {
        errorMessage = nil //clear previous errors
        isSearching = true //start loading
        defer { isSearching = false } //Guarantee loading stops: defer means run this statement when the current function exits, regardless of how it exits. So the code does not need to repeat isSearching = false in every branch.

        do {
            let request = MKLocalSearch.Request(completion: completion) //turns the chosen autocomplete completion into a search request. MKLocalSearch is a class provided by Apple’s MapKit framework, it is declared in startSearch.
            request.resultTypes = [.address, .pointOfInterest] //final lookup is also allowed to return either an address or point of interest.
            //Note completer’s food-category filter is not explicitly reapplied here. The selected completion was already generated under that filter, so the resolution request starts from a filtered suggestion.
            let response = try await startSearch(with: request) //helper converts MapKit’s callback API into an async function.

            guard let mapItem = response.mapItems.first, //The response needs a map item, A response can hold multiple places. The code chooses the first, which MapKit considers the best match.
                  let location = LocationFormatting.dishLocation(from: mapItem) else { //The map item must convert to DishLocation
                errorMessage = "No matching location found." //If either step fails
                return nil
            }

            return location //returns the normalized DishLocation to LocationSearchView
        } catch {
            errorMessage = "Location search failed. Please try again." //This catches errors thrown by startSearch
            return nil
        }
    }

    private func performCompletionSearch(for query: String) { //Starting autocomplete
        isSearching = true //Show loading state
        completer.queryFragment = query //Give the text to MapKit, which starts the asynchronous autocomplete process.
    }
    //MKLocalSearch.Response contains response.mapItems, where each item is a MKMapItem. An MKMapItem is a resolved place.
    private func startSearch(with request: MKLocalSearch.Request) async throws -> MKLocalSearch.Response {
        //MKLocalSearch.start is callback-based, but resolve is written using modern async/await. withCheckedThrowingContinuation bridges those two styles.
        try await withCheckedThrowingContinuation { continuation in
            //MKLocalSearch performs a full place search and returns resolved map results.
            MKLocalSearch(request: request).start { response, error in
                if let error {
                    continuation.resume(throwing: error) //async call throws.
                } else if let response {
                    continuation.resume(returning: response) //async call returns the response.
                } else {
                    continuation.resume(throwing: LocationSearchError.emptyResponse) //This protects against the unusual case where MapKit gives neither a response nor an error. This custom error is defined
                    //private enum LocationSearchError: Error
                }
            }
        }
    }
}
//The extension exists mainly to separate the delegate-conformance code from the rest of LocationSearchViewModel.
//LocationSearchViewModel: MKLocalSearchCompleterDelegate tells Swift that LocationSearchViewModel can serve as a completer delegate because it implements the required callback methods.
extension LocationSearchViewModel: MKLocalSearchCompleterDelegate {
    //The class is marked @MainActor, but MapKit’s delegate protocol does not guarantee that its callbacks satisfy main-actor isolation.
    //nonisolated allows this method to be called from outside the main actor.
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) { //the MKLocalSearchCompleter instance calls its assigned delegate after it has updated its autocomplete results.
        Task { @MainActor in //returns execution to the main actor before changing UI state.
            self.isSearching = false
            self.suggestions = completer.results //storing the results. Now SwiftUI sees the published array change and rerenders the suggestion list.
        }
    }
    //autocomplete fails
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false //stop loading
            self.suggestions = [] //clear suggestions
            self.errorMessage = "Location suggestions failed. Please try again." //display error: The actual MapKit error is not exposed to the user. The app displays a friendlier generic message.
        }
    }
}

private enum LocationSearchError: Error {
    case emptyResponse
}
