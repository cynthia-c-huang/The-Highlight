import CoreLocation
import Foundation
import MapKit

enum LocationFormatting {
    static func dishLocation(from mapItem: MKMapItem, fallbackName: String? = nil) -> DishLocation? {
        let coordinate = mapItem.location.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }

        let formattedAddress = formattedAddress(from: mapItem)
        let restaurantName = displayName(
            name: mapItem.name,
            address: formattedAddress,
            fallbackName: fallbackName
        )
        //extracts place name, formatted address latitude, longitude and converts them into the app's model.
        return DishLocation(
            restaurantName: restaurantName,
            formattedAddress: formattedAddress,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    static func pinnedLocation(
        latitude: Double,
        longitude: Double,
        mapItem: MKMapItem?
    ) -> DishLocation {
        if let mapItem,
           let location = dishLocation(from: mapItem, fallbackName: "Pinned location") {
            return DishLocation(
                restaurantName: location.restaurantName ?? "Pinned location",
                formattedAddress: location.formattedAddress,
                latitude: latitude,
                longitude: longitude
            )
        }

        return DishLocation(
            restaurantName: "Pinned location",
            formattedAddress: nil,
            latitude: latitude,
            longitude: longitude
        )
    }

    private static func formattedAddress(from mapItem: MKMapItem) -> String? {
        mapItem.addressRepresentations?.fullAddress(includingRegion: true, singleLine: false)
            ?? mapItem.address?.fullAddress.trimmedNilIfEmpty
    }

    private static func displayName(
        name: String?,
        address: String?,
        fallbackName: String?
    ) -> String? {
        guard let trimmedName = name?.trimmedNilIfEmpty else {
            return fallbackName?.trimmedNilIfEmpty
        }

        if trimmedName == address?.trimmedNilIfEmpty {
            return fallbackName?.trimmedNilIfEmpty
        }

        return trimmedName
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
