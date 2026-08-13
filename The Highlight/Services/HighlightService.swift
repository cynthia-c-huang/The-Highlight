import Foundation
import Supabase
final class HighlightService {
    static let shared: HighlightService = { //creates one shared HighlightService instance
        let client = SupabaseManager.shared.client
        return HighlightService(supabase: client)
    }()
    private let supabase: SupabaseClient
    private let bucket = "highlight-photos"
    private let signedPhotoURLCache = SignedPhotoURLCache()
    private init(supabase: SupabaseClient) { //private constructor so other code cannot casually create new service instances.
        self.supabase = supabase
    }
    func saveHighlight(params: SaveParams) async throws {
        let user = try await supabase.auth.session.user //This retrieves the user from the active Supabase session.
        guard let userID = UUID(uuidString: user.id.uuidString) else { //produces the UUID placed into the database row’s user_id
            throw NSError(domain: "HighlightService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid user id"])
        }
        let photoPath = try await uploadPhotoIfNeeded(userID: userID, data: params.imageData, ext: params.imageFileExtension)
        struct InsertRow: Encodable { //an internal type shaped to match the Supabase table column names.
            let user_id: UUID
            let dish_name: String
            let location_type: String
            let date_eaten: Date?
            let tags: [String]
            let photo_path: String?
            let rating: Double
            let memory_note: String?
            let restaurant_name: String?
            let formatted_address: String?
            let latitude: Double?
            let longitude: Double?
            let dish_reference_id: UUID?
            let occasion_id: UUID? //notice the stored Highlight does NOT store the Occasion object itself, only the ID. Therefore, selecting a meal does not embed meal data into the Highlight. It writes only the occasion’s UUID. That avoids repeating the occasion title across every dish row.
        }
//creating a row using the parameters passed into the function. Note that storage contains the actual JPEG file, but Database has the text path pointing to that JPEG

        let row = InsertRow(
            user_id: userID,
            dish_name: params.dishName,
            location_type: params.locationType,
            date_eaten: params.dateEaten,
            tags: params.tags,
            photo_path: photoPath,
            rating: params.rating,
            memory_note: params.memoryNote,
            restaurant_name: params.restaurantName,
            formatted_address: params.formattedAddress,
            latitude: params.latitude,
            longitude: params.longitude,
            dish_reference_id: params.dishReferenceID,
            occasion_id: params.occasionID
        )
        _ = try await supabase.from("highlights").insert(row).execute() /* inserting into Supabase. Note that the upload may succeed, but the insert may fail (edge case: the uploaded file may remain in Storage without a matching database row.*/
        try await syncOccasionDateIfNeeded(params: params) //runs after a Highlight is inserted or updated. If the dish belongs to an occasion, make that occasion’s date and the dates of all dishes in that occasion match the date just saved on this dish.
        
    } //successfully return to AddDishView
    func updateHighlight(_ highlight: Highlight, params: SaveParams) async throws {
        let user = try await supabase.auth.session.user
        guard let userID = UUID(uuidString: user.id.uuidString) else { /*obtains the UUID, which ensures two things. If there is a new photo, place it in the current user’s storage folder. Restrict the database update to a row owned by the current user. */
            throw NSError(domain: "HighlightService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid user id"])
        }
        let uploadedPhotoPath = try await uploadPhotoIfNeeded(userID: userID, data: params.imageData, ext: params.imageFileExtension) //upload replacement if one exists.
        let shouldUpdatePhotoPath = uploadedPhotoPath != nil || params.removesExistingPhoto
// One update model handles all three photo cases:
// omit photo_path to preserve the existing photo,
// encode a new path to replace it,
// or encode null to remove it.
        struct UpdateRow: Encodable {
            let dish_name: String
            let location_type: String
            let date_eaten: Date?
            let tags: [String]
            let rating: Double
            let memory_note: String?
            let restaurant_name: String?
            let formatted_address: String?
            let latitude: Double?
            let longitude: Double?
            let dish_reference_id: UUID?
            let occasion_id: UUID?
            let photo_path: String?
            let shouldEncodePhotoPath: Bool
            enum CodingKeys: String, CodingKey {
                case dish_name
                case location_type
                case date_eaten
                case tags
                case rating
                case memory_note
                case restaurant_name
                case formatted_address
                case latitude
                case longitude
                case dish_reference_id
                case occasion_id
                case photo_path
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(dish_name, forKey: .dish_name)
                try container.encode(location_type, forKey: .location_type)
                try container.encodeIfPresent(date_eaten, forKey: .date_eaten)
                try container.encode(tags, forKey: .tags)
                try container.encode(rating, forKey: .rating)
                try container.encodeNullable(memory_note, forKey: .memory_note) //this helper explicitly writes either the value or null
                try container.encodeNullable(restaurant_name, forKey: .restaurant_name)
                try container.encodeNullable(formatted_address, forKey: .formatted_address)
                try container.encodeNullable(latitude, forKey: .latitude)
                try container.encodeNullable(longitude, forKey: .longitude)
                try container.encodeNullable(dish_reference_id, forKey: .dish_reference_id)
                try container.encodeNullable(occasion_id, forKey: .occasion_id)
                if shouldEncodePhotoPath {
                    try container.encodeNullable(photo_path, forKey: .photo_path)
                }
            }
        }
        let row = UpdateRow(
            dish_name: params.dishName,
            location_type: params.locationType,
            date_eaten: params.dateEaten,
            tags: params.tags,
            rating: params.rating,
            memory_note: params.memoryNote,
            restaurant_name: params.restaurantName,
            formatted_address: params.formattedAddress,
            latitude: params.latitude,
            longitude: params.longitude,
            dish_reference_id: params.dishReferenceID ?? highlight.dishReferenceID,
            occasion_id: params.occasionID,
            photo_path: uploadedPhotoPath,
            shouldEncodePhotoPath: shouldUpdatePhotoPath
        )
        _ = try await supabase //Update database photo_path
            .from("highlights")
            .update(row)
            .eq("id", value: highlight.id.uuidString)
            .eq("user_id", value: userID.uuidString)
            .execute()
        try await syncOccasionDateIfNeeded(params: params)
        //This covers both removal and replacement. Removal: shouldUpdatePhotoPath = true, previousPhotoPath = old path, uploadedPhotoPath = nil, old path != nil -> delete old object
        //Replacement: shouldUpdatePhotoPath = true, previousPhotoPath = old path, uploadedPhotoPath = new path, old path != new path, -> delete old object
        //When keeping the existing photo, shouldUpdatePhotoPath = false
        if shouldUpdatePhotoPath,
           let previousPhotoPath = highlight.photo_path,
           previousPhotoPath != uploadedPhotoPath {
            await signedPhotoURLCache.invalidate(path: previousPhotoPath)
            try await deletePhoto(at: previousPhotoPath) //deletePhoto is a helper that deletes previous Storage object.
        }
        //When editing a dish’s occasion, this handles moving a dish's meal and removing a dish's meal. If no other Highlights reference the old occasion, it gets deleted
        if let previousOccasionID = highlight.occasion_id,
           previousOccasionID != params.occasionID {
            try? await OccasionService.shared.deleteOccasionIfUnused(id: previousOccasionID)
        }
    }

    func updateDishReference(
        highlightID: UUID,
        dishReferenceID: UUID?
    ) async throws {
        let user = try await supabase.auth.session.user
        let userID = user.id.uuidString

        struct DishReferenceUpdateRow: Encodable {
            let dish_reference_id: UUID?

            enum CodingKeys: String, CodingKey {
                case dish_reference_id
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeNullable(dish_reference_id, forKey: .dish_reference_id)
            }
        }

        _ = try await supabase
            .from("highlights")
            .update(DishReferenceUpdateRow(dish_reference_id: dishReferenceID))
            .eq("id", value: highlightID.uuidString)
            .eq("user_id", value: userID)
            .execute()
    }

    func deleteHighlight(_ highlight: Highlight) async throws {
        let user = try await supabase.auth.session.user
        guard let userID = UUID(uuidString: user.id.uuidString) else {
            throw NSError(domain: "HighlightService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid user id"])
        }
        //deletion is restricted by both the row ID and current user ID
        _ = try await supabase
            .from("highlights")
            .delete()
            .eq("id", value: highlight.id.uuidString)
            .eq("user_id", value: userID.uuidString)
            .execute()
        //if a photo path exists
        if let photoPath = highlight.photo_path {
            await signedPhotoURLCache.invalidate(path: photoPath)
            try? await deletePhoto(at: photoPath) //photo deletion uses try?. That means: database-row deletion failure throws, photo-deletion failure is ignored.
            //So a rare storage failure could leave an orphaned file even though the database row was successfully deleted.
        }

        if let occasionID = highlight.occasion_id {
            try? await OccasionService.shared.deleteOccasionIfUnused(id: occasionID)
        }
    }

    private func uploadPhotoIfNeeded(userID: UUID, data: Data?, ext: String?) async throws -> String? {
        guard let data, let ext, !data.isEmpty else { return nil } //If the data or extension is missing, return nil. So, saving without a photo is valid
        let photoID = UUID().uuidString
        let userFolder = userID.uuidString.lowercased()
        let objectPath = "\(userFolder)/\(photoID).\(ext)" /* Ex. 9781d37b-e752-4a1e-8920-d6b0f9662f18/
a-new-random-uuid.jpg. The first UUID identifies the user folder. The second gives the photo a unique filename. */
//Then the bytes are uploaded to Supabase storage
        _ = try await supabase.storage.from(bucket).upload(
            objectPath,
            data: data,
            options: FileOptions(cacheControl: "3600", contentType: contentType(for: ext), upsert: false)
        )
        return objectPath //The function returns the path, not the full image bytes or a permanent public URL.
    }

    private func deletePhoto(at path: String) async throws {
        _ = try await supabase.storage.from(bucket).remove(paths: [path])
    }

    private func syncOccasionDateIfNeeded(params: SaveParams) async throws {
        guard let occasionID = params.occasionID else { return } //Check whether the dish belongs to a meal
        try await OccasionService.shared.syncDate(params.dateEaten, forOccasionID: occasionID) //
    }

/* Your storage bucket is private. That means an ordinary public internet URL should not permanently expose its files. A signed URL is a temporary URL that grants permission to access one specific private file. */
    func signedURL(for path: String, expiresIn seconds: Int = 3600) async throws -> URL {
        if let cachedURL = await signedPhotoURLCache.url(for: path, expiresIn: seconds) {
            #if DEBUG
            print("[DishDiscoveryTiming] signed image URL cache hit for \(path)")
            #endif
            return cachedURL
        }

        #if DEBUG
        let clock = ContinuousClock()
        let requestStart = clock.now
        #endif

        let signedURL = try await supabase.storage.from(bucket).createSignedURL(path: path, expiresIn: seconds)
        await signedPhotoURLCache.store(signedURL, for: path, expiresIn: seconds)

        #if DEBUG
        let requestDuration = requestStart.duration(to: clock.now)
        print("[DishDiscoveryTiming] signed image URL request for \(path): \(DishDiscoveryPerformanceLogger.milliseconds(for: requestDuration)) ms")
        #endif

        return signedURL
    }
    private func contentType(for ext: String) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        default: return "application/octet-stream"
        }
    }
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.decodeSupabaseDate)
        return decoder
    }
    nonisolated private static func decodeSupabaseDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        if let timestamp = try? container.decode(Double.self) {
            return Date(timeIntervalSince1970: timestamp)
        }
        let value = try container.decode(String.self)
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }
        let internetFormatter = ISO8601DateFormatter()
        internetFormatter.formatOptions = [.withInternetDateTime]
        if let date = internetFormatter.date(from: value) {
            return date
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX", "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX", "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid Supabase date: \(value)"
        )
    }

    func fetchHighlights() async throws -> [Highlight] { //throws means it may fail and pass an error to its caller. On success, it returns an array of Highlight values
        // Get current user id
        let user = try await supabase.auth.session.user //A session represents the currently logged-in user and their authentication credentials. If it fails, execution stops and the error travels back to HomeView.
        let userID = user.id.uuidString //user.id is the user’s identifier. .uuidString converts it into a String, because the query below passes it as a filter value.

        #if DEBUG
        let clock = ContinuousClock()
        let requestStart = clock.now
        #endif

        // Fetch rows for this user, newest first
        let response = try await supabase //This is a chained API call. Each line adds another instruction to the query.
            .from("highlights") //run the query against the highlights table
            .select() //select rows
            .eq("user_id", value: userID) //filter by the current user
            .order("created_at", ascending: false) //sort newest first, the created_at column.
            .execute() //sends the query. After .execute(), response contains the result returned by Supabase, response.data

        #if DEBUG
        let requestDuration = requestStart.duration(to: clock.now)
        let decodeStart = clock.now
        #endif

        let highlights = try makeDecoder().decode([Highlight].self, from: response.data) /*decodes the JSON from the raw response data into [Highlight]. [Highlight].self tells the decoder what it should try to reproduce. Note that the Highlight model must conform to Decodable or Codable for this to work. The JSON column names and Swift model properties must also match, either directly or through CodingKeys. We use makeDecoder because Supabase data may arrive in several formats*/

        #if DEBUG
        let decodeDuration = decodeStart.duration(to: clock.now)
        print("[DishDiscoveryTiming] highlights Supabase request: \(DishDiscoveryPerformanceLogger.milliseconds(for: requestDuration)) ms")
        print("[DishDiscoveryTiming] highlights decode: \(DishDiscoveryPerformanceLogger.milliseconds(for: decodeDuration)) ms")
        #endif

        return highlights //array travels back to caller
    }
}

private actor SignedPhotoURLCache {
    private struct CacheKey: Hashable {
        let path: String
        let expiresIn: Int
    }

    private struct Entry {
        let url: URL
        let expiresAt: Date
    }

    private var entries: [CacheKey: Entry] = [:]
    private let refreshLeadTime: TimeInterval = 60

    func url(for path: String, expiresIn seconds: Int) -> URL? {
        let key = CacheKey(path: path, expiresIn: seconds)
        guard let entry = entries[key] else { return nil }

        if entry.expiresAt.timeIntervalSince(Date()) > refreshLeadTime {
            return entry.url
        }

        entries[key] = nil
        return nil
    }

    func store(_ url: URL, for path: String, expiresIn seconds: Int) {
        guard seconds > 0 else { return }

        let key = CacheKey(path: path, expiresIn: seconds)
        entries[key] = Entry(
            url: url,
            expiresAt: Date().addingTimeInterval(TimeInterval(seconds))
        )
        removeExpiredEntries()
    }

    func invalidate(path: String) {
        entries = entries.filter { $0.key.path != path }
    }

    private func removeExpiredEntries() {
        let now = Date()
        entries = entries.filter { $0.value.expiresAt.timeIntervalSince(now) > refreshLeadTime }
    }
}

private extension KeyedEncodingContainer {
    mutating func encodeNullable<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}
struct SaveParams {
    let dishName: String
    let locationType: String        // "home" or "restaurant"
    let dateEaten: Date?            // optional
    let tags: [String]              // text[] in DB
    let rating: Double
    let memoryNote: String?
    let restaurantName: String?
    let formattedAddress: String?
    let latitude: Double?
    let longitude: Double?
    let dishReferenceID: UUID?
    let occasionID: UUID?
    let imageData: Data?            // optional
    let imageFileExtension: String? // e.g., "jpg", "png", "heic"
    let removesExistingPhoto: Bool

    init(
        dishName: String,
        locationType: String,
        dateEaten: Date?,
        tags: [String],
        rating: Double,
        memoryNote: String?,
        restaurantName: String?,
        formattedAddress: String?,
        latitude: Double?,
        longitude: Double?,
        dishReferenceID: UUID? = nil,
        occasionID: UUID?,
        imageData: Data?,
        imageFileExtension: String?,
        removesExistingPhoto: Bool
    ) {
        self.dishName = dishName
        self.locationType = locationType
        self.dateEaten = dateEaten
        self.tags = tags
        self.rating = rating
        self.memoryNote = memoryNote
        self.restaurantName = restaurantName
        self.formattedAddress = formattedAddress
        self.latitude = latitude
        self.longitude = longitude
        self.dishReferenceID = dishReferenceID
        self.occasionID = occasionID
        self.imageData = imageData
        self.imageFileExtension = imageFileExtension
        self.removesExistingPhoto = removesExistingPhoto
    }
}
