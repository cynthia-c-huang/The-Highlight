import Foundation
import Supabase

final class ProfilePreferencesService {
    static let shared = ProfilePreferencesService()

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetchCurrentUser() async throws -> User {
        try await client.auth.user()
    }

    func updateUserMetadata(_ metadata: [String: AnyJSON]) async throws -> User {
        try await client.auth.update(user: UserAttributes(data: metadata))
    }

    func requestEmailChange(to email: String) async throws -> User {
        try await client.auth.update(user: UserAttributes(email: email))
    }

    func resendVerificationEmail(to email: String) async throws {
        try await client.auth.resend(email: email, type: .signup)
    }
}
