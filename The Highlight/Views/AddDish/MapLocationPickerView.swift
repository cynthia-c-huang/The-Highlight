import CoreLocation
import MapKit
import SwiftUI

struct MapLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedLocation: DishLocation?
    @State private var lastReverseGeocodedKey: String?
    @State private var isResolvingAddress = false
    @State private var isSearchingNearbyRestaurants = false
    @State private var nearbyRestaurantChoices: [DishLocation] = []
    @State private var nearbyRestaurantSearchMessage: String?
    @State private var nearbyRestaurantSearchRequest: NearbyRestaurantSearchRequest?
    @State private var errorMessage: String?
    @State private var zoomCommand: MapZoomCommand?

    private let initialMapCenterCoordinate: CLLocationCoordinate2D?
    let onConfirm: (DishLocation) -> Void

    init(
        initialLocation: DishLocation?,
        defaultMapCenterCoordinate: CLLocationCoordinate2D? = nil,
        onConfirm: @escaping (DishLocation) -> Void
    ) {
        _selectedLocation = State(initialValue: initialLocation) //the value is copied into the picker’s own temporary @State
        //The picker can now change its pin without immediately changing the form’s location.
        let savedDefaultCoordinate = MapPreferenceStore.shared.defaultMapStartingPoint()?.coordinate
        initialMapCenterCoordinate = initialLocation?.coordinate ?? defaultMapCenterCoordinate ?? savedDefaultCoordinate
        self.onConfirm = onConfirm
    }

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack { //MapLocationPickerView has its own NavigationStack because the map picker is presented as a separate sheet, outside HomeView’s main navigation stack.
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    //the visible map is ultimately an MKMapView, but SwiftUI treats SelectableMapView like another child view.
                    SelectableMapView(
                        selectedLocation: $selectedLocation, //these bindings correspond to state owned by MapLocationPickerView. The wrapper and the parent are connected to the same state.
                        //When the UIKit map wrapper changes parent.selectedLocation = DishLocation(...), it is changing the parent picker’s @State. That change causes SwiftUI to reevaluate MapLocationPickerView.body
                        zoomCommand: $zoomCommand,
                        nearbyRestaurantSearchRequest: $nearbyRestaurantSearchRequest,
                        initialCenterCoordinate: initialMapCenterCoordinate,
                        colorScheme: colorScheme
                    )
                    .ignoresSafeArea(edges: .top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    zoomControls
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 12) {
                    if let location = selectedLocation {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 23, weight: .semibold))
                                .foregroundColor(.accentPrimary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(location.displayName)
                                    .font(AppTypography.font(.bodyBold, size: 18))
                                    .foregroundColor(theme.primaryText)
                                    .lineLimit(2)

                                Text(location.displayAddress)
                                    .font(AppTypography.font(.body, size: 13))
                                    .foregroundColor(theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()
                        }

                        if isResolvingAddress {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Resolving address...")
                                    .font(AppTypography.font(.body, size: 13))
                                    .foregroundColor(theme.secondaryText)
                            }
                        }

                        nearbyRestaurantsSection
                    } else {
                        Text("Tap or long-press the map to pin a restaurant or place.")
                            .font(AppTypography.font(.body, size: 14))
                            .foregroundColor(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTypography.font(.body, size: 13))
                            .foregroundColor(.red.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 12) {
                        Button {
                            dismiss() //because the Cancel button does not call onConfirm, the picker’s temporary selection is discarded and AddDishView.selectedLocation stays unchanged.
                        } label: {
                            Text("Cancel")
                                .font(AppTypography.font(.bodyBold, size: 16))
                                .foregroundColor(theme.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(theme.controlBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        //Use Location Button
                        Button {
                            if let selectedLocation {
                                onConfirm(selectedLocation) //onConfirm is another callback supplied by AddDishView
                                //location in selectedLocation = location (the confirmed picker value travels back
                                //upward) and isShowingLocationSearch = false
                                dismiss()
                            }
                        } label: {
                            Text("Use location")
                                .font(AppTypography.font(.bodyBold, size: 16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(selectedLocation == nil ? theme.disabledButtonBackground : Color.accentPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedLocation == nil)
                    }
                }
                .padding(18)
                .background(theme.panelBackground)
            }
            .navigationTitle("Choose Location") //The stack provides the bar; the two modifiers configure its contents and presentation. This provides the text used in the nav bar
            .navigationBarTitleDisplayMode(.inline) //this specifies how the text should be positioned and styled
            .onChange(of: selectedLocation) { _, location in //when the coordinator assigns the temporary location, SwiftUI notices the state change and invokes this closure.
                reverseGeocodeIfNeeded(location)
            }
            .onChange(of: nearbyRestaurantSearchRequest) { _, request in
                searchNearbyRestaurants(for: request)
            }
        }
    }

    @ViewBuilder
    private var nearbyRestaurantsSection: some View {
        if isSearchingNearbyRestaurants || !nearbyRestaurantChoices.isEmpty || nearbyRestaurantSearchMessage != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.accentPrimary)

                    Text("Nearby restaurants")
                        .font(AppTypography.font(.bodyBold, size: 15))
                        .foregroundColor(theme.primaryText)

                    if isSearchingNearbyRestaurants {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let nearbyRestaurantSearchMessage {
                    Text(nearbyRestaurantSearchMessage)
                        .font(AppTypography.font(.body, size: 13))
                        .foregroundColor(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(nearbyRestaurantChoices, id: \.self) { restaurant in
                    Button {
                        selectNearbyRestaurant(restaurant)
                    } label: {
                        nearbyRestaurantRow(restaurant)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func nearbyRestaurantRow(_ restaurant: DishLocation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.accentPrimary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(restaurant.displayName)
                    .font(AppTypography.font(.bodyBold, size: 14))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(1)

                Text(restaurant.displayAddress)
                    .font(AppTypography.font(.body, size: 12))
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentPrimary)
                .padding(.top, 2)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(theme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var zoomControls: some View {
        VStack(spacing: 0) {
            Button {
                zoomCommand = MapZoomCommand(direction: .zoomIn)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.primaryText)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom in")

            Divider()
                .frame(width: 28)

            Button {
                zoomCommand = MapZoomCommand(direction: .zoomOut)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.primaryText)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom out")
        }
        .background(theme.controlBackground.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }

    private func selectNearbyRestaurant(_ restaurant: DishLocation) {
        lastReverseGeocodedKey = restaurant.coordinateKey
        selectedLocation = restaurant
        nearbyRestaurantChoices = []
        nearbyRestaurantSearchMessage = nil
        errorMessage = nil
        isResolvingAddress = false
    }

    private func searchNearbyRestaurants(for request: NearbyRestaurantSearchRequest?) {
        guard let request else { return }

        nearbyRestaurantChoices = []
        nearbyRestaurantSearchMessage = nil
        isSearchingNearbyRestaurants = true

        Task {
            do {
                let restaurants = try await nearbyRestaurants(near: request.coordinate)

                await MainActor.run {
                    guard nearbyRestaurantSearchRequest?.id == request.id else { return }
                    nearbyRestaurantChoices = restaurants
                    nearbyRestaurantSearchMessage = restaurants.isEmpty ? "No nearby restaurants found." : nil
                    isSearchingNearbyRestaurants = false
                }
            } catch {
                await MainActor.run {
                    guard nearbyRestaurantSearchRequest?.id == request.id else { return }
                    nearbyRestaurantChoices = []
                    nearbyRestaurantSearchMessage = "Nearby restaurant search failed. You can still use the pinned spot."
                    isSearchingNearbyRestaurants = false
                }
            }
        }
    }

    private func nearbyRestaurants(near coordinate: CLLocationCoordinate2D) async throws -> [DishLocation] {
        let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: 120)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .bakery,
            .brewery,
            .cafe,
            .foodMarket,
            .restaurant,
            .winery
        ])

        let response = try await MKLocalSearch(request: request).start()
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return response.mapItems
            .compactMap { mapItem -> (location: DishLocation, distance: CLLocationDistance)? in
                guard let location = LocationFormatting.dishLocation(from: mapItem) else { return nil }
                let itemLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                return (location, origin.distance(from: itemLocation))
            }
            .sorted { $0.distance < $1.distance }
            .prefix(4)
            .map(\.location)
    }

    private func reverseGeocodeIfNeeded(_ location: DishLocation?) {
        guard let location else { //If there is no location, there is nothing to resolve.
            lastReverseGeocodedKey = nil //It also resets the stored key so a future location can be geocoded.
            return
        }
        //prevents repeatedly geocoding the same point
        guard location.coordinateKey != lastReverseGeocodedKey else { return }
        lastReverseGeocodedKey = location.coordinateKey //The code prevents repeatedly geocoding the same point by storing the coordinate key
        isResolvingAddress = true //causes the UI to show ProgressView() Text("Resolving address...")
        errorMessage = nil //removes any error from a previous pin
        //The reverse-geocoding API is asynchronous. The task allows the code to await MapKit’s result without blocking the UI.
        //During that time, the user can still see the map, the temporary pin remains selected, the loading message appears
        //and the app remains responsive
        Task {
            do {
                //Creating the reverse-geocoding request
                guard let request = MKReverseGeocodingRequest(
                    //latitude and longitude are stored separately in DishLocation. MapKit expects a CLLocation, so the code converts accordingly here
                    location: CLLocation(latitude: location.latitude, longitude: location.longitude)
                ) else { //The initializer is optional, so the code handles the possibility that it cannot create a valid request.
                    throw MapLocationPickerError.invalidReverseGeocodingRequest //The private custom error allows this failure to enter the same catch block as other reverse-geocoding errors.
                }

                let mapItems = try await request.mapItems //performs the actual reverse geocoding, coordinates -> place
                //The result is an array because MapKit may find multiple possible items near a coordinate, so
                //we use .first as the best possible match
                let resolvedLocation = LocationFormatting.pinnedLocation(
                    latitude: location.latitude, //Even if the returned MKMapItem has its own coordinate, the original latitude/longitude are explicitly preserved, so the final location remains where the user tapped
                    longitude: location.longitude,
                    mapItem: mapItems.first
                )

                await MainActor.run { //MainActor.run ensures the UI-related state is changed safely on the main actor.
                    guard selectedLocation?.coordinateKey == location.coordinateKey else { return }
                    selectedLocation = resolvedLocation //successful result is applied here, this replaces the temporary fallback with the improved value.
                    isResolvingAddress = false //hides the loading indicator.
                }
            } catch {
                await MainActor.run {
                    guard selectedLocation?.coordinateKey == location.coordinateKey else { return }
                    selectedLocation = DishLocation( //The app deliberately keeps a valid location
                        restaurantName: "Pinned location",
                        formattedAddress: nil,
                        latitude: location.latitude,
                        longitude: location.longitude
                    )
                    isResolvingAddress = false
                    //Then it displays an error, but it does not disable the Use Location button, which is only disabled when selectedLocation == nil
                    errorMessage = "Could not find an address for this spot. You can still use the pinned coordinates."
                }
            }
        }
    }

    private struct Theme {
        let colorScheme: ColorScheme

        private var isDark: Bool {
            colorScheme == .dark
        }

        var panelBackground: Color {
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
            isDark ? .textPrimary : Color.containerPrimary.opacity(0.72)
        }

        var rowBackground: Color {
            isDark ? Color.backgroundDarkPrimary.opacity(0.82) : Color.backgroundPrimary.opacity(0.82)
        }

        var disabledButtonBackground: Color {
            isDark ? Color.backgroundPrimary.opacity(0.22) : Color.textPrimary.opacity(0.35)
        }
    }
}

private enum MapLocationPickerError: Error {
    case invalidReverseGeocodingRequest
}

private struct MapZoomCommand: Equatable {
    enum Direction {
        case zoomIn
        case zoomOut
    }

    let id = UUID() //fresh UUID is important because the user may press the same button multiple times.
    //two consecutive zoomCommands may have zoomIn as their direction, but because SwiftUI sees two different IDs,
    //it runs updateUIView again
    let direction: Direction
}

private struct NearbyRestaurantSearchRequest: Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: NearbyRestaurantSearchRequest, rhs: NearbyRestaurantSearchRequest) -> Bool {
        lhs.id == rhs.id
    }
}
//To place an MKMapView (a UIKit view) inside MapLocationPickerView (a SwiftUI view), the code wraps it in SelectableMapView
//UIViewRepresentable is a bridge that means this SwiftUI-compatible type knows how to create and update a UIKit view.
private struct SelectableMapView: UIViewRepresentable {
    @Binding var selectedLocation: DishLocation?
    @Binding var zoomCommand: MapZoomCommand?
    @Binding var nearbyRestaurantSearchRequest: NearbyRestaurantSearchRequest?
    let initialCenterCoordinate: CLLocationCoordinate2D?
    let colorScheme: ColorScheme
    //This is called when SwiftUI needs the UIKit map for the first time.
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero) //This is where the actual Apple map object is constructed.
        mapView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        //It is then configured
        mapView.delegate = context.coordinator //Send your map-related delegate events to this coordinator object.
        mapView.showsCompass = true
        mapView.showsScale = true
        //food related filter is set. This affects which points of interest MapKit displays on the map, but it does not prevent the user from tapping another coordinate.
        mapView.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .bakery,
            .brewery,
            .cafe,
            .foodMarket,
            .restaurant,
            .winery
        ])
        //When the tap gesture succeeds, call handleMapTap(_:) on the coordinator.
        //this defines what gesture to recognize (a tap), who should receive the callback (context.coordinator),
        //which method to call (handleMapTap(_:)). But at this point, it is not connected to the map yet.
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tapGesture.numberOfTouchesRequired = 1
        tapGesture.cancelsTouchesInView = false //MKMapView already has its own gestures for dragging, zooming, rotating
        //and selecting built-in map content. Setting this to false helps avoid completely swallowing the map’s normal interactions when the custom recognizer activates.
        tapGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(tapGesture) //attaches the recognizer to the map

        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapLongPress(_:)))
        longPressGesture.cancelsTouchesInView = false
        longPressGesture.delegate = context.coordinator
        //registers the recognizer with the map so UIKit sends the map’s touch events to it and it can detect presses and call the coordinator.
        mapView.addGestureRecognizer(longPressGesture)

        return mapView
    }
    //SwiftUI calls updateUIView when it needs to synchronize the UIKit view with current SwiftUI state.
    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        mapView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        context.coordinator.configureInitialRegionIfNeeded(on: mapView)
        context.coordinator.updateAnnotation(on: mapView)
        context.coordinator.applyZoomCommandIfNeeded(on: mapView)
    }
    //The coordinator is a helper object that connects UIKit callbacks and gestures back to the SwiftUI wrapper.
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self) //SwiftUI calls makeCoordinator() when setting up the representable and makes the resulting object available as context.coordinator
    }
//    It has three jobs:
//    Receive tap and long-press gesture actions.
//    Act as the map view delegate.
//    Update the SwiftUI binding through parent.
    //Unlike the SwiftUI struct SelectableMapView, this class instance persists while the represented map view exists.
    //UIKit APIs expect a stable class instance
    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: SelectableMapView //So the coordinator can reach parent.selectedLocation and parent.zoomCommand
        private var didSetInitialRegion = false
        private var lastZoomCommandID: UUID?

        init(parent: SelectableMapView) {
            self.parent = parent
        }

        func configureInitialRegionIfNeeded(on mapView: MKMapView) {
            guard !didSetInitialRegion else { return } //Without that guard, every SwiftUI state update might reset the map’s center, preventing the user from freely panning.
            didSetInitialRegion = true //The coordinator remembers whether it has already positioned the map
            //If selectedLocation exists, center on its coordinate. Otherwise, use the saved default map point before falling back to LA.
            let coordinate = parent.selectedLocation?.coordinate
                ?? parent.initialCenterCoordinate
                ?? CLLocationCoordinate2D(
                    latitude: 34.0522,
                    longitude: -118.2437
                )
            //A smaller delta means a closer zoom. A larger delta means a wider geographic area.
            let span = MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08) //the visible region is defined
            //the initial view appears immediately without an animation
            mapView.setRegion(MKCoordinateRegion(center: coordinate, span: span), animated: false)
        }

        func updateAnnotation(on mapView: MKMapView) {
            mapView.removeAnnotations(mapView.annotations) //The annotation logic starts by removing old annotations
            //If a location exists
            guard let selectedLocation = parent.selectedLocation else { return }
            //creates an annotation and fills it
            let annotation = MKPointAnnotation()
            annotation.coordinate = selectedLocation.coordinate
            annotation.title = selectedLocation.displayName
            annotation.subtitle = selectedLocation.formattedAddress
            //when the temporary value is first created, the annotation may display "Pinned Location," but
            //Later, when reverse geocoding replaces the location, updateUIView runs again and recreates the annotation using the improved name and address
            mapView.addAnnotation(annotation) //adding a new annotation
        }

        func applyZoomCommandIfNeeded(on mapView: MKMapView) {
            guard let zoomCommand = parent.zoomCommand,
                  zoomCommand.id != lastZoomCommandID else { //each command is applied once
                return
            }

            lastZoomCommandID = zoomCommand.id
            let zoomFactor = zoomCommand.direction == .zoomIn ? 0.5 : 2.0 //A smaller coordinate span means zooming in, a larger span means zooming out
            let currentSpan = mapView.region.span
            let nextSpan = MKCoordinateSpan(
                //clamps the span to prevent extreme zoom values
                latitudeDelta: min(max(currentSpan.latitudeDelta * zoomFactor, 0.001), 120),
                longitudeDelta: min(max(currentSpan.longitudeDelta * zoomFactor, 0.001), 120)
            )
            let nextRegion = MKCoordinateRegion(center: mapView.region.center, span: nextSpan)
            mapView.setRegion(mapView.regionThatFits(nextRegion), animated: true)
        }
        //the coordinator receives tap and long-press events
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            //Verify the tap finished              Recover the map view
            guard gesture.state == .ended, let mapView = gesture.view as? MKMapView else { return }
            //                      Get the screen point. This returns a CGPoint (x = 185 y = 320)
            //That is a pixel-like position within the view. It is not yet latitude and longitude.
            selectCoordinate(from: gesture.location(in: mapView), on: mapView)
        }

        @objc func handleMapLongPress(_ gesture: UILongPressGestureRecognizer) {
            //A long press remains active for some time and can continue changing as the finger moves.
            //Using .began ensures the location is selected once, when the long press first becomes recognized, rather than repeatedly as it continues.
            guard gesture.state == .began, let mapView = gesture.view as? MKMapView else { return }
            selectCoordinate(from: gesture.location(in: mapView), on: mapView)
            //The map coordinate conversion requires the touch point to be measured within the actual MKMapView, so we attach it to mapView
        }
        //The coordinator then converts the touch position into a coordinate
        private func selectCoordinate(from point: CGPoint, on mapView: MKMapView) {
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            //sends that result back into SwiftUI state
            //At this moment, the app knows only the geographic coordinate.
            //So it creates a valid fallback value w/ "Pinned location" and nil for the address
            parent.selectedLocation = DishLocation( //tapping or long-pressing the map updates its local state.
                //Because the coordinator writes through the binding parent.selectedLocation the actual state changed is: MapLocationPickerView.selectedLocation
                restaurantName: "Pinned location",
                formattedAddress: nil,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            parent.nearbyRestaurantSearchRequest = NearbyRestaurantSearchRequest(coordinate: coordinate)
        }
        //The coordinator also allows simultaneous gesture recognition
        //Allow my custom gesture and another map gesture to be recognized together.
        //This helps the map remain interactive while also supporting pin placement.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "SelectedLocation"
            //The visual pin that appears on screen is an annotation view: MKMarkerAnnotationView
            //MKPointAnnotation is the location data
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView.annotation = annotation
            annotationView.canShowCallout = true
            annotationView.markerTintColor = UIColor(Color.accentPrimary)
            return annotationView
        }
    }
}

#Preview("Map Location Picker") {
    MapLocationPickerView(
        initialLocation: DishLocation(
            restaurantName: "Tuna Sushi Bar",
            formattedAddress: "120 S Los Angeles St\nLos Angeles, CA 90012\nUnited States",
            latitude: 34.0496,
            longitude: -118.2427
        ),
        onConfirm: { _ in }
    )
}
