import CoreLocation
import Foundation

struct DefaultMapStartingPoint: Equatable {
    let displayName: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isValid: Bool {
        CLLocationCoordinate2DIsValid(coordinate)
        && (-90...90).contains(latitude)
        && (-180...180).contains(longitude)
        && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

final class MapPreferenceStore {
    static let shared = MapPreferenceStore()

    private enum Keys {
        static let displayName = "preferences.defaultMapStartingPoint"
        static let latitude = "preferences.defaultMapStartingPoint.latitude"
        static let longitude = "preferences.defaultMapStartingPoint.longitude"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func defaultMapStartingPointDisplayName() -> String {
        defaultMapStartingPoint()?.displayName ?? userDefaults.string(forKey: Keys.displayName) ?? ""
    }

    func defaultMapStartingPoint() -> DefaultMapStartingPoint? {
        guard let displayName = userDefaults.string(forKey: Keys.displayName)?.trimmedNilIfEmpty,
              userDefaults.object(forKey: Keys.latitude) != nil,
              userDefaults.object(forKey: Keys.longitude) != nil else {
            return nil
        }

        let preference = DefaultMapStartingPoint(
            displayName: displayName,
            latitude: userDefaults.double(forKey: Keys.latitude),
            longitude: userDefaults.double(forKey: Keys.longitude)
        )

        return preference.isValid ? preference : nil
    }

    func save(_ startingPoint: DefaultMapStartingPoint) {
        guard startingPoint.isValid else {
            clearDefaultMapStartingPoint()
            return
        }

        userDefaults.set(startingPoint.displayName, forKey: Keys.displayName)
        userDefaults.set(startingPoint.latitude, forKey: Keys.latitude)
        userDefaults.set(startingPoint.longitude, forKey: Keys.longitude)
    }

    func clearDefaultMapStartingPoint() {
        userDefaults.removeObject(forKey: Keys.displayName)
        userDefaults.removeObject(forKey: Keys.latitude)
        userDefaults.removeObject(forKey: Keys.longitude)
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
