import MapKit
import SwiftUI
//Overall flow:
//User types
//→ LocationSearchView forwards text to LocationSearchViewModel
//→ view model waits briefly
//→ MKLocalSearchCompleter generates suggestions
//→ user taps one
//→ MKLocalSearch resolves it into a real place
//→ LocationFormatting converts that place into DishLocation
//→ DishLocation is returned to AddDishView

//LocationSearchView appears
//→ create LocationSearchViewModel once
//→ user types and suggestions change
//→ body rerenders
//→ keep the same view model
struct LocationSearchView: View {
    @Environment(\.colorScheme) private var colorScheme

    //@StateObject says create this view model once for this instance of LocationSearchView, and preserve it while the view remains in the hierarchy.
    //because LocationSearchView.body may be reevaluated many times as the query and suggestions change, we do not want a fresh search model to be created on every reevaluation.
    //When isSearchVisible becomes false and LocationSearchView is removed entirely, that state object can be destroyed. Reopening the search usually creates a fresh view model.
    @StateObject private var viewModel = LocationSearchViewModel() //owns a search view model that handles the current search query, search suggestions, loading state, errors, and resolving a selected suggestion into a DishLocation

    let onSelect: (DishLocation) -> Void //LocationSearchView does not own the final selected location. Instead, when the user picks a result, it sends the resolved DishLocation back to its parent.

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.secondaryText)

                TextField( //The text field does not bind directly to a local @State string. It uses a custom binding
                    "Search for a restaurant",
                    text: Binding(
                        get: { viewModel.query }, //What text should the field currently display
                        set: { viewModel.updateQuery($0) } //What should happen whenever the text changes, where $0 is the new text
                        //The view model updates its query property and begins the process of obtaining suggestions.
                    )
                )
                .font(AppTypography.font(.body, size: 15))
                .foregroundColor(theme.primaryText)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(theme.secondaryText.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if viewModel.isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Finding places...")
                        .font(AppTypography.font(.body, size: 13))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.horizontal, 4)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AppTypography.font(.body, size: 13))
                    .foregroundColor(.red.opacity(0.85))
                    .padding(.horizontal, 4)
            }

            if !viewModel.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.suggestions.enumerated()), id: \.offset) { index, suggestion in
                        Button {
                            Task {
                                if let location = await viewModel.resolve(suggestion) { //The selected MKLocalSearchCompletion is passed into resolve
                                    onSelect(location) //sends the selected location back to DishLocationSection, which writes it into the binding selectedLocation = location
                                    viewModel.clearSearch()
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.title)
                                    .font(AppTypography.font(.bodyBold, size: 14))
                                    .foregroundColor(theme.primaryText)
                                    .lineLimit(1)

                                if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(AppTypography.font(.body, size: 12))
                                            .foregroundColor(theme.secondaryText)
                                            .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)

                        if index < viewModel.suggestions.count - 1 {
                            Divider()
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(theme.resultsBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSearching && viewModel.errorMessage == nil {
                Text("No matching places yet.")
                    .font(AppTypography.font(.body, size: 13))
                    .foregroundColor(theme.secondaryText)
                    .padding(.horizontal, 4)
            }
        }
    }

    private struct Theme {
        let colorScheme: ColorScheme

        private var isDark: Bool {
            colorScheme == .dark
        }

        var primaryText: Color {
            isDark ? .backgroundPrimary : .textPrimary
        }

        var secondaryText: Color {
            primaryText.opacity(0.7)
        }

        var controlBackground: Color {
            isDark ? Color.backgroundDarkPrimary.opacity(0.72) : .containerPrimary
        }

        var resultsBackground: Color {
            isDark ? .textPrimary : Color.containerPrimary.opacity(0.85)
        }
    }
}

#Preview("Location Search") {
    ZStack {
        Color.highlightCream.ignoresSafeArea()
        LocationSearchView { _ in }
            .padding()
    }
}
