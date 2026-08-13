import Foundation
import Supabase

struct OccasionSaveParams {
    let title: String?
    let date: Date?
    let restaurantName: String?
    let formattedAddress: String?
    let latitude: Double?
    let longitude: Double?
}

final class OccasionService {
    static let shared: OccasionService = {
        let client = SupabaseManager.shared.client
        return OccasionService(supabase: client)
    }()

    private let supabase: SupabaseClient

    private init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    func createOccasion(params: OccasionSaveParams) async throws -> Occasion {
        let user = try await supabase.auth.session.user
        guard let userID = UUID(uuidString: user.id.uuidString) else {
            throw NSError(domain: "OccasionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid user id"])
        }
        //creates the model locally
        let occasion = Occasion(
            id: UUID(),
            user_id: userID,
            title: params.title,
            date: params.date,
            restaurantName: params.restaurantName,
            formattedAddress: params.formattedAddress,
            latitude: params.latitude,
            longitude: params.longitude,
            created_at: Date()
        )
        //defines a database-shaped row. This separate type exists because the Swift UI model uses restaurantName and formattedAddress while Supabase expects snake_case
        struct InsertRow: Encodable {
            let id: UUID
            let user_id: UUID
            let title: String?
            let date: Date?
            let restaurant_name: String?
            let formatted_address: String?
            let latitude: Double?
            let longitude: Double?
            let created_at: Date
        }

        let row = InsertRow(
            id: occasion.id,
            user_id: userID,
            title: params.title,
            date: params.date,
            restaurant_name: params.restaurantName,
            formatted_address: params.formattedAddress,
            latitude: params.latitude,
            longitude: params.longitude,
            created_at: occasion.created_at
        )
        //inserting
        _ = try await supabase
            .from("occasions")
            .insert(row)
            .execute()

        return occasion //The returned Occasion is the same object the service assembled before insertion. It is not decoded from Supabase’s response. That is efficient, although it assumes the inserted database values match the locally generated values
    }

    func fetchOccasions() async throws -> [Occasion] {
        let user = try await supabase.auth.session.user
        let userID = user.id.uuidString

        let response = try await supabase
            .from("occasions")
            .select()
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .execute()

        return try makeDecoder().decode([Occasion].self, from: response.data)
    }

    func fetchOccasion(id: UUID) async throws -> Occasion? {
        let user = try await supabase.auth.session.user
        let userID = user.id.uuidString

        let response = try await supabase
            .from("occasions")
            .select()
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userID)
            .limit(1)
            .execute()

        return try makeDecoder().decode([Occasion].self, from: response.data).first
    }

    func fetchHighlights(occasionID: UUID) async throws -> [Highlight] {
        let user = try await supabase.auth.session.user
        let userID = user.id.uuidString

        let response = try await supabase
            .from("highlights")
            .select()
            .eq("user_id", value: userID)
            .eq("occasion_id", value: occasionID.uuidString)
            .order("created_at", ascending: false)
            .execute()

        return try makeDecoder().decode([Highlight].self, from: response.data)
    }

    func syncDate(_ date: Date?, forOccasionID occasionID: UUID) async throws {
        let user = try await supabase.auth.session.user
        let userID = user.id.uuidString

        struct OccasionDateUpdateRow: Encodable {
            let date: Date?

            enum CodingKeys: String, CodingKey {
                case date
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeNullable(date, forKey: .date)
            }
        }

        struct HighlightDateUpdateRow: Encodable {
            let date_eaten: Date?

            enum CodingKeys: String, CodingKey {
                case date_eaten
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeNullable(date_eaten, forKey: .date_eaten)
            }
        }

        _ = try await supabase //updates the occasions table: Find the current user’s occasion with this ID and set its date column to the supplied date.
            .from("occasions")
            .update(OccasionDateUpdateRow(date: date))
            .eq("id", value: occasionID.uuidString)
            .eq("user_id", value: userID)
            .execute()

        _ = try await supabase //Update every dish in that occasion
            .from("highlights")
            .update(HighlightDateUpdateRow(date_eaten: date)) //Find all the current user’s Highlights whose occasion_id matches and set their date_eaten to the same date.
            .eq("occasion_id", value: occasionID.uuidString)
            .eq("user_id", value: userID)
            .execute()
    }
    //                             V receives the occasion ID
    func deleteOccasionIfUnused(id: UUID) async throws {
        //The function does not receive the full Occasion object because it only needs the occasion’s ID to search for linked Highlights and delete the matching occasion if none exist.
        let remainingHighlights = try await fetchHighlights(occasionID: id) //fetches every Highlight linked to that occasion
        guard remainingHighlights.isEmpty else { return } //Continue only if remainingHighlights.isEmpty is true. Otherwise, leave the function.

        try await deleteOccasion(id: id)
    }

    func deleteOccasion(id: UUID) async throws {
        let user = try await supabase.auth.session.user
        let userID = user.id.uuidString
        //deletes the row only if occasion.id matches the supplied ID and occasion.user_id matches the logged-in user
        _ = try await supabase
            .from("occasions")
            .delete()
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userID)
            .execute()
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
