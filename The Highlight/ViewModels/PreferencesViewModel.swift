import Combine
import Foundation
import MapKit
import Supabase
import UIKit

//its properties and ordinary methods are isolated to the main actor.
//That is appropriate because it changes UI-observed state like
//selectedAppearance
//isLoading
//statusMessage
//errorMessage
//username
//profileImage
@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var email: String = ""
    @Published var profileImage: UIImage?
    @Published var defaultMapStartingPoint: String = ""
    @Published var selectedAppearance: AppAppearance = .system
    @Published var isLoading: Bool = false
    @Published var isSavingProfile: Bool = false
    @Published var isRequestingEmailVerification: Bool = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let service: ProfilePreferencesService
    private let mapPreferenceStore: MapPreferenceStore //MapPreferenceStore is a separate object responsible for saving and loading the user’s default map starting point. Because the default map location is used outside Preferences, i.e. for MapPickerView, it is not defined in PreferencesViewModel. If the data only lived inside PreferencesViewModel, it would disappear when the Preferences screen closed.
    private let userDefaults: UserDefaults
    private var currentUser: User?
    private var currentEmail: String = ""
    private var hasLoaded: Bool = false

    private let profileImageDataKey = "preferences.profileImageData"

    init(
        service: ProfilePreferencesService? = nil,
        mapPreferenceStore: MapPreferenceStore? = nil,
        //the app’s usual local key-value preference store.
        userDefaults: UserDefaults = .standard
    ) {
        self.service = service ?? ProfilePreferencesService.shared
        self.mapPreferenceStore = mapPreferenceStore ?? MapPreferenceStore.shared
        self.userDefaults = userDefaults
    }

    func load() async {
        guard !hasLoaded else { return } //SwiftUI tasks may be triggered more than once during a view’s lifecycle. The guard prevents duplicate loading
        hasLoaded = true
        loadLocalPreferences() //Before making a Supabase request, local preferences load first
        //because appearance is local device state, the local appearance control can be restored immediately, even if
        //the network is slow, Supabase fails, or account metadata cannot be loaded.
        isLoading = true
        errorMessage = nil
        //Loading account data
        do {
            let user = try await service.fetchCurrentUser() //fetches the current Supabase user and loads relevant info
            currentUser = user
            currentEmail = user.email ?? ""
            username = preferredUsername(from: user)
            email = currentEmail
        } catch {
            errorMessage = "Unable to load account preferences: \(error.localizedDescription)"
        }

        isLoading = false
    }
    //It saves:
//    username to Supabase user metadata,
//    default map location through MapPreferenceStore,
//    appearance again through saveLocalPreferences() (although redundant)
    func saveProfilePreferences() async -> Bool {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMapStartingPoint = defaultMapStartingPoint.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUsername.isEmpty else {
            errorMessage = "Username cannot be empty."
            statusMessage = nil
            return false
        }

        isSavingProfile = true
        errorMessage = nil
        statusMessage = nil

        defer {
            isSavingProfile = false
        }

        let resolvedMapStartingPoint: DefaultMapStartingPoint?
        do {
            resolvedMapStartingPoint = try await resolveDefaultMapStartingPoint(from: trimmedMapStartingPoint)
        } catch {
            errorMessage = "Could not find \"\(trimmedMapStartingPoint)\" as a city or county. Try a more specific place."
            return false
        }

        do {
            var metadata = currentUser?.userMetadata ?? [:] //username is remote
            metadata["username"] = .string(trimmedUsername)
            metadata["display_name"] = .string(trimmedUsername)
            let updatedUser = try await service.updateUserMetadata(metadata)
            currentUser = updatedUser
            username = preferredUsername(from: updatedUser)

            if let resolvedMapStartingPoint {
                mapPreferenceStore.save(resolvedMapStartingPoint)
                defaultMapStartingPoint = resolvedMapStartingPoint.displayName
            } else {
                mapPreferenceStore.clearDefaultMapStartingPoint()
                defaultMapStartingPoint = ""
            }

            saveLocalPreferences()
            statusMessage = "Preferences saved."
            return true
        } catch {
            errorMessage = "Unable to save preferences: \(error.localizedDescription)"
            return false
        }
    }

    func requestEmailVerification() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isValidEmail(trimmedEmail) else {
            errorMessage = "Enter a valid email address."
            statusMessage = nil
            return
        }

        isRequestingEmailVerification = true
        errorMessage = nil
        statusMessage = nil

        do {
            if trimmedEmail.caseInsensitiveCompare(currentEmail) == .orderedSame {
                try await service.resendVerificationEmail(to: trimmedEmail)
                statusMessage = "Verification email requested."
            } else {
                let updatedUser = try await service.requestEmailChange(to: trimmedEmail)
                currentUser = updatedUser
                currentEmail = updatedUser.email ?? currentEmail
                statusMessage = "Check \(trimmedEmail) to verify the email change."
            }
        } catch {
            errorMessage = "Unable to request email verification: \(error.localizedDescription)"
        }

        isRequestingEmailVerification = false
    }

    func updateProfileImage(with data: Data) {
        guard let image = UIImage(data: data) else {
            errorMessage = "Unable to read that photo."
            statusMessage = nil
            return
        }

        let resizedImage = image.resizedToFit(maxDimension: 512)
        profileImage = resizedImage

        if let jpegData = resizedImage.jpegData(compressionQuality: 0.78) {
            userDefaults.set(jpegData, forKey: profileImageDataKey)
            statusMessage = "Profile picture updated."
            errorMessage = nil
        } else {
            errorMessage = "Unable to save that photo."
            statusMessage = nil
        }
    }

    func clearProfileImage() {
        profileImage = nil
        userDefaults.removeObject(forKey: profileImageDataKey)
        statusMessage = "Profile picture removed."
        errorMessage = nil
    }

    func updateAppearancePreference(_ appearance: AppAppearance) {
        selectedAppearance = appearance
        saveLocalPreferences() //Persist the setting
    }

    private func loadLocalPreferences() {
        if let imageData = userDefaults.data(forKey: profileImageDataKey) {
            profileImage = UIImage(data: imageData)
        }

        defaultMapStartingPoint = mapPreferenceStore.defaultMapStartingPointDisplayName()
        selectedAppearance = AppAppearance.stored(in: userDefaults)
    }

    private func saveLocalPreferences() {
        userDefaults.set(selectedAppearance.rawValue, forKey: AppAppearance.preferenceKey)
    }

    private func resolveDefaultMapStartingPoint(from query: String) async throws -> DefaultMapStartingPoint? {
        guard !query.isEmpty else { return nil }

        let request = MKLocalSearch.Request(naturalLanguageQuery: query)
        request.resultTypes = [.address]

        let response = try await startSearch(with: request)
        guard let mapItem = response.mapItems.first else {
            throw DefaultMapStartingPointResolutionError.noResults
        }

        guard let location = LocationFormatting.dishLocation(from: mapItem, fallbackName: query) else {
            throw DefaultMapStartingPointResolutionError.invalidCoordinate
        }

        let startingPoint = DefaultMapStartingPoint(
            displayName: location.displayName,
            latitude: location.latitude,
            longitude: location.longitude
        )

        guard startingPoint.isValid else {
            throw DefaultMapStartingPointResolutionError.invalidCoordinate
        }

        return startingPoint
    }

    private func startSearch(with request: MKLocalSearch.Request) async throws -> MKLocalSearch.Response {
        try await withCheckedThrowingContinuation { continuation in
            MKLocalSearch(request: request).start { response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let response {
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(throwing: DefaultMapStartingPointResolutionError.noResults)
                }
            }
        }
    }

    private func preferredUsername(from user: User) -> String {
        if let username = user.userMetadata["username"]?.stringValue, !username.isEmpty {
            return username
        }

        if let displayName = user.userMetadata["display_name"]?.stringValue, !displayName.isEmpty {
            return displayName
        }

        if let email = user.email, let emailPrefix = email.split(separator: "@").first {
            return String(emailPrefix)
        }

        return ""
    }

    private func isValidEmail(_ value: String) -> Bool {
        let parts = value.split(separator: "@")
        guard parts.count == 2 else { return false }
        return parts[1].contains(".")
    }
}

private enum DefaultMapStartingPointResolutionError: Error {
    case noResults
    case invalidCoordinate
}

private extension UIImage {
    func resizedToFit(maxDimension: CGFloat) -> UIImage {
        let largestDimension = max(size.width, size.height)
        guard largestDimension > maxDimension else { return self }

        let scale = maxDimension / largestDimension
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
