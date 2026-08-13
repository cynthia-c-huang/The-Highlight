import CoreLocation
import Foundation

struct DishLocation: Equatable, Hashable {
    let restaurantName: String?
    let formattedAddress: String?
    let latitude: Double
    let longitude: Double

    init(
        restaurantName: String?,
        formattedAddress: String?,
        latitude: Double,
        longitude: Double
    ) {
        self.restaurantName = restaurantName?.trimmedNilIfEmpty
        self.formattedAddress = formattedAddress?.trimmedNilIfEmpty
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var coordinateKey: String {
        "\(latitude.rounded(toPlaces: 6)),\(longitude.rounded(toPlaces: 6))"
    }

    var displayName: String {
        restaurantName ?? "Pinned location"
    }

    var displayAddress: String {
        formattedAddress ?? "Address unavailable"
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
