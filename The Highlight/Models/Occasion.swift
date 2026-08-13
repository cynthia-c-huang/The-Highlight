import Foundation
//The occasion stores information shared by the meal
struct Occasion: Identifiable, Codable, Hashable {
    let id: UUID
    let user_id: UUID
    var title: String? //The fields are optional because an occasion may be as minimal as "Meal"
    var date: Date?
    var restaurantName: String?
    var formattedAddress: String?
    var latitude: Double?
    var longitude: Double?
    let created_at: Date
    //This converts the occasion’s separately stored location fields into the existing DishLocation type
    var dishLocation: DishLocation? {
        guard let latitude, let longitude else { return nil } //Both coordinates are required to construct a usable DishLocation. A restaurant name alone does not produce one here.
        return DishLocation(
            restaurantName: restaurantName,
            formattedAddress: formattedAddress,
            latitude: latitude,
            longitude: longitude
        )
    }

    var displayTitle: String { //fallback sequence: custom title → restaurant name → "Meal"
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }

        if let restaurantName = restaurantName?.trimmingCharacters(in: .whitespacesAndNewlines), !restaurantName.isEmpty {
            return restaurantName
        }

        return "Meal"
    }

    var detailText: String? { //This builds a secondary string: Jul 29, 2026 · Bestia
        let trimmedRestaurantName = restaurantName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let trimmedAddress = formattedAddress?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let details = [
            date?.formatted(.dateTime.month(.abbreviated).day().year()),
            trimmedRestaurantName,
            trimmedRestaurantName == nil ? trimmedAddress?.replacingOccurrences(of: "\n", with: ", ") : nil
        ].compactMap { $0 }

        return details.isEmpty ? nil : details.joined(separator: " · ")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case title
        case date
        case restaurantName = "restaurant_name"
        case formattedAddress = "formatted_address"
        case latitude
        case longitude
        case created_at
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
