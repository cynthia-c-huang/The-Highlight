import Combine
import Foundation
import Supabase

final class DishDiscoveryService {
    static let shared: DishDiscoveryService = {
        let client = SupabaseManager.shared.client
        return DishDiscoveryService(supabase: client)
    }()

    private let supabase: SupabaseClient

    private init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    func fetchPublishedDishes() async throws -> [DishReference] {
        #if DEBUG
        let clock = ContinuousClock()
        let requestStart = clock.now
        #endif

        let response = try await supabase
            .from("dish_references")
            .select()
            .eq("content_status", value: "published")
            .order("name", ascending: true)
            .execute()

        #if DEBUG
        let requestDuration = requestStart.duration(to: clock.now)
        let decodeStart = clock.now
        #endif

        let dishes = try makeDecoder().decode([DishReference].self, from: response.data)

        #if DEBUG
        let decodeDuration = decodeStart.duration(to: clock.now)
        print("[DishDiscoveryTiming] catalog Supabase request: \(DishDiscoveryPerformanceLogger.milliseconds(for: requestDuration)) ms")
        print("[DishDiscoveryTiming] catalog decode: \(DishDiscoveryPerformanceLogger.milliseconds(for: decodeDuration)) ms")
        #endif

        return dishes
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

@MainActor
final class DishCatalogStore: ObservableObject {
    typealias DishFetcher = () async throws -> [DishReference]

    @Published private(set) var dishes: [DishReference]
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasLoadedSuccessfully: Bool

    private let fetchPublishedDishes: DishFetcher
    private let usesPreviewData: Bool

    init(
        previewDishes: [DishReference]? = nil,
        fetchPublishedDishes: @escaping DishFetcher = { try await DishDiscoveryService.shared.fetchPublishedDishes() }
    ) {
        self.dishes = previewDishes ?? []
        self.hasLoadedSuccessfully = previewDishes != nil
        self.fetchPublishedDishes = fetchPublishedDishes
        self.usesPreviewData = previewDishes != nil
    }

    func loadIfNeeded() async {
        guard !usesPreviewData, !hasLoadedSuccessfully else { return }
        await loadCatalog()
    }

    func refresh() async {
        guard !usesPreviewData else { return }
        await loadCatalog()
    }

    private func loadCatalog() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        #if DEBUG
        let clock = ContinuousClock()
        let loadStart = clock.now
        #endif

        do {
            dishes = try await fetchPublishedDishes()
            hasLoadedSuccessfully = true

            #if DEBUG
            let loadDuration = loadStart.duration(to: clock.now)
            print("[DishDiscoveryTiming] catalog store load: \(DishDiscoveryPerformanceLogger.milliseconds(for: loadDuration)) ms")
            #endif
        } catch {
            errorMessage = "Unable to load dish discovery right now. Please try again."

            #if DEBUG
            let loadDuration = loadStart.duration(to: clock.now)
            print("[DishDiscoveryTiming] catalog store load failed after \(DishDiscoveryPerformanceLogger.milliseconds(for: loadDuration)) ms: \(error.localizedDescription)")
            #endif
        }

        isLoading = false
    }
}

#if DEBUG
enum DishDiscoveryPerformanceLogger {
    @MainActor private static var cardTapStarts: [UUID: ContinuousClock.Instant] = [:]

    nonisolated static func milliseconds(for duration: Duration) -> String {
        let components = duration.components
        let milliseconds = Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
        return String(format: "%.1f", milliseconds)
    }

    @MainActor
    static func recordDishCardTap(_ dish: DishReference) {
        cardTapStarts[dish.id] = ContinuousClock().now
        print("[DishDiscoveryTiming] dish card tapped: \(dish.name)")
    }

    @MainActor
    static func logDetailAppeared(for dish: DishReference) {
        guard let tapStart = cardTapStarts[dish.id] else {
            print("[DishDiscoveryTiming] detail appeared for \(dish.name) without a recorded card tap")
            return
        }

        let duration = tapStart.duration(to: ContinuousClock().now)
        cardTapStarts[dish.id] = nil
        print("[DishDiscoveryTiming] card tap to detail appear for \(dish.name): \(milliseconds(for: duration)) ms")
    }
}
#endif
