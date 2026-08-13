import Foundation

struct Highlight: Identifiable, Codable, Hashable {
    let id: UUID
    let user_id: UUID
    let dish_name: String
    let location_type: String // "home" or "restaurant"
    let date_eaten: Date?
    let tags: [String]
    let photo_path: String?
    let rating: Double
    let memoryNote: String?
    let restaurantName: String?
    let formattedAddress: String?
    let latitude: Double?
    let longitude: Double?
    let dishReferenceID: UUID?
    let occasion_id: UUID? //A dish belongs to a meal only through this optional field. The Occasion does not contain an array of dishes. Instead, each Highlight stores the foreign key pointing back to its occasion.
    let created_at: Date

    init(
        id: UUID,
        user_id: UUID,
        dish_name: String,
        location_type: String,
        date_eaten: Date?,
        tags: [String],
        photo_path: String?,
        rating: Double,
        memoryNote: String?,
        restaurantName: String?,
        formattedAddress: String?,
        latitude: Double?,
        longitude: Double?,
        dishReferenceID: UUID? = nil,
        occasion_id: UUID?,
        created_at: Date
    ) {
        self.id = id
        self.user_id = user_id
        self.dish_name = dish_name
        self.location_type = location_type
        self.date_eaten = date_eaten
        self.tags = tags
        self.photo_path = photo_path
        self.rating = rating
        self.memoryNote = memoryNote
        self.restaurantName = restaurantName
        self.formattedAddress = formattedAddress
        self.latitude = latitude
        self.longitude = longitude
        self.dishReferenceID = dishReferenceID
        self.occasion_id = occasion_id
        self.created_at = created_at
    }

    var dishLocation: DishLocation? {
        guard let latitude, let longitude else { return nil }
        return DishLocation(
            restaurantName: restaurantName,
            formattedAddress: formattedAddress,
            latitude: latitude,
            longitude: longitude
        )
    }

    func withDishReferenceID(_ dishReferenceID: UUID?) -> Highlight {
        Highlight(
            id: id,
            user_id: user_id,
            dish_name: dish_name,
            location_type: location_type,
            date_eaten: date_eaten,
            tags: tags,
            photo_path: photo_path,
            rating: rating,
            memoryNote: memoryNote,
            restaurantName: restaurantName,
            formattedAddress: formattedAddress,
            latitude: latitude,
            longitude: longitude,
            dishReferenceID: dishReferenceID,
            occasion_id: occasion_id,
            created_at: created_at
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case dish_name
        case location_type
        case date_eaten
        case tags
        case photo_path
        case rating
        case memoryNote = "memory_note" //Swift uses camel case, memoryNote, but Supabase uses snake_case, so this maps them accordingly. Without this mapping, Swift would look for a key named memoryNote and fail to find it from Supabase.
        case restaurantName = "restaurant_name"
        case formattedAddress = "formatted_address"
        case latitude
        case longitude
        case dishReferenceID = "dish_reference_id"
        case occasion_id //Since they already match exactly, Swift does not need a custom string.
        case created_at
    }
}
