import SwiftUI

//DishLocationSection is the location portion of AddDishView.
//
//It is responsible for:
//
//showing the current selected location
//showing “Search for a restaurant”
//showing “Choose on map”
//showing “Change,” “Map,” and “Remove location”
//deciding whether the inline search UI is visible
//
//It receives bindings from AddDishView, so it does not own the final location. It reads and changes the location state owned by AddDishView
struct DishLocationSection: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedLocation: DishLocation?
    @Binding var isSearchVisible: Bool //controls whether SwiftUI includes that view inside DishLocationSection.

    let onChooseMap: () -> Void //it takes no arguments, it returns nothing, it performs some action supplied by the parent.
    //DishLocationSection does not know that the action changes isShowingMapPicker.
    //It only knows when the user requests the map, call onChooseMap()

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .appBodyFont(size: 14)
                .foregroundColor(theme.primaryText)

            if let location = selectedLocation {
                selectedLocationCard(location)
            } else {
                unselectedLocationCard
            }

            if isSearchVisible {
                LocationSearchView { location in
                    selectedLocation = location
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchVisible = false
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearchVisible)
    }

    private var unselectedLocationCard: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearchVisible.toggle() // flips a Bool value between true and false
                }
            } label: {
                Label("Search for a restaurant", systemImage: "magnifyingglass")
                    .font(AppTypography.font(.bodyBold, size: 14))
                    .foregroundColor(theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button { //When no location is selected
                onChooseMap()
            } label: {
                Label("Choose on map", systemImage: "map")
                    .font(AppTypography.font(.bodyBold, size: 14))
                    .foregroundColor(theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(theme.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func selectedLocationCard(_ location: DishLocation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentPrimary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(location.displayName)
                        .font(AppTypography.font(.bodyBold, size: 16))
                        .foregroundColor(theme.primaryText)
                        .lineLimit(2)

                    Text(location.displayAddress)
                        .font(AppTypography.font(.body, size: 13))
                        .foregroundColor(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchVisible.toggle()
                    }
                } label: {
                    Text("Change")
                        .font(AppTypography.font(.bodyBold, size: 14))
                        .foregroundColor(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.controlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)

                Button { //When a location already exists
                    onChooseMap() //DishLocationSection calls onChooseMap(), which executes the closure originally supplied by AddDishView to set isShowingMapPicker to TRUE
                } label: {
                    Text("Map")
                        .font(AppTypography.font(.bodyBold, size: 14))
                        .foregroundColor(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.controlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    selectedLocation = nil
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchVisible = false
                    }
                } label: {
                    Text("Remove location")
                        .font(AppTypography.font(.bodyBold, size: 14))
                        .foregroundColor(.red.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.controlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

        var cardBackground: Color {
            isDark ? .textPrimary : Color.containerPrimary.opacity(0.45)
        }

        var controlBackground: Color {
            isDark ? Color.backgroundDarkPrimary.opacity(0.72) : .containerPrimary
        }
    }
}

private struct DishLocationSectionPreviewHost: View {
    @State var location: DishLocation?
    @State private var isSearchVisible = false

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            DishLocationSection(
                selectedLocation: $location,
                isSearchVisible: $isSearchVisible,
                onChooseMap: {}
            )
            .padding()
        }
    }
}

#Preview("Location Section - Empty") {
    DishLocationSectionPreviewHost(location: nil)
}

#Preview("Location Section - Populated") {
    DishLocationSectionPreviewHost(
        location: DishLocation(
            restaurantName: "Honeybird",
            formattedAddress: "714 Foothill Blvd\nLa Canada Flintridge, CA 91011\nUnited States",
            latitude: 34.2012,
            longitude: -118.1907
        )
    )
}
