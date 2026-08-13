import Foundation
import Supabase
import SwiftUI
import Combine
@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = true //controls whether RootView displays the fullscreen loading page
    @Published var authError: String?
    private let client = SupabaseManager.shared.client
    
    init() {
        Task {
            await checkSession()
            for await state in client.auth.authStateChanges { /*It listens to a stream of authentication events from Supabase. The loop does not behave like a normal finite array loop. It waits for future events.*/
                self.isAuthenticated = state.session != nil /*If Supabase provides a session, this evaluates to true. Since isAuthenticated is @Published, SwiftUI notices the change, and RootView updates accordingly.*/
                if state.session != nil { self.authError = nil } /*If Supabase reports a valid session, any previous login error is cleared.*/
                self.isLoading = false //Whenever an authentication state arrives, the manager marks the authentication operation as finished.
            }
        }
    }
    
    func checkSession() async {
        do {
            _ = try await client.auth.session /*This asks the Supabase client for the current session. The expression can throw an error, so it uses try await. The underscore means to retrieve the session, but do not store the returned session value.*/
            isAuthenticated = true //only if the above succeeds
        } catch {
            isAuthenticated = false //If retrieving the session throws, the code treats that as no valid session.
        }
        isLoading = false //This executes whether the session lookup succeeded or failed.
    }
    //The successful sign-in causes Supabase to emit an auth-state change. The listener in init() handles it:
    func signIn(email: String, password: String) async {
        isLoading = true
        authError = nil
        do {
            try await client.auth.signIn(email: email, password: password) /*This is the line that actually sends the login request to Supabase. Await is used because the result does not arrive instantly, and try is used because the request may fail (i.e., incorrect credentials, network failure, invalid email format, etc.)*/
        } catch {
            authError = error.localizedDescription /*if Supabase login fails and throws an error, this stores the error. The error variable is automatically available inside catch. localizedDescription converts the error into a user-readable string. Because authError is @Published, Swift notices the change*/
            isLoading = false
        }
    }
//Because signOut() uses throws, it does not catch its own errors. The caller must handle them.
    func signOut() async throws {
        try await client.auth.signOut()
        isAuthenticated = false
    }
}

