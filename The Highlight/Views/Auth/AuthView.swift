/*This file is where the user enters credentials and starts the login request. AuthView owns a temporary form state, Supabase performs the actual authentication.
AuthView
- collects user input
- displays UI
- starts login

AuthManager
- talks to Supabase
- stores shared auth state
- handles authentication errors*/

import SwiftUI
import Supabase
struct AuthView: View {
    @State private var email = "" //These values belong specifically to this instance of AuthView.
    @State private var password = "" 
    @State private var isLoading = false //This controls the loading indicator inside the login button.
    @EnvironmentObject private var authManager: AuthManager //This retrieves the shared AuthManager created by The_HighlightApp
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Logo Section
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 40)
                                .accessibilityLabel("App Logo")
                            Text("The Highlight")
                                .appHeaderFont(size: 36)
                                .foregroundColor(.accentPrimary)
                                .tracking(2)
                        }
                        .padding(.top, 40)
                    }
                    
                    // Slogan
                    HStack(spacing: 4) {
                        Text("taste")
                            .foregroundColor(theme.primaryText)
                        Text("everything")
                            .foregroundColor(.accentPrimary)
                            .appBodyItalicFont(size: 24)
                        Text("again")
                            .foregroundColor(theme.primaryText)
                    }
                    .appBodyFont(size: 24)
                    
                    // Main Card
                    VStack(spacing: 24) {
                        // Login Icon Button
                        Button(action: { Task { await signIn() } }) { /*The closure inside action runs when the user taps the button. The login function is asynchronous (func signIn() async) so the button cannot directly use await unless it creates an asynchronous context, thus it uses Task (The task does not block the interface while the network request is happening.) That means SwiftUI can continue drawing the loading spinner, processing animations, and responding to system events while it waits for Supabase.*/
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.accentPrimary, lineWidth: 4)
                                    .frame(width: 70, height: 70)
                                
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .accentPrimary))
                                } else {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.accentPrimary)
                                }
                            }
                        }
                        .padding(.top, 16)
                        .disabled(
                            isLoading ||
                            email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || /*this also disables the button from being pressed when the email or password are empty*/
                            password.isEmpty
                        ) //The button is also disabled, so while a login request is in progress, the user cannot tap repeatedly.
                        // Fields
                        VStack(spacing: 20) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("username or email")
                                    .appBodyFont(size: 14)
                                    .foregroundColor(theme.primaryText)
                                
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(.accentPrimary)
                                    TextField("enter email", text: $email) //The dollar sign creates a Binding to the state variable. Without the dollar sign you are reading the current string.
                                        #if os(iOS)
                                        .keyboardType(.emailAddress)
                                        #endif
                                        .textInputAutocapitalization(.never)
                                        .foregroundColor(theme.primaryText)
                                        .font(AppTypography.font(.body, size: 16))
                                }
                                .padding()
                                .background(theme.fieldBackground)
                                .cornerRadius(12)
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("password")
                                        .appBodyFont(size: 14)
                                        .foregroundColor(theme.primaryText)
                                    Spacer()
                                    NavigationLink(destination: ForgotPasswordView()) {
                                        Text("forgot?")
                                            .appBodyFont(size: 12)
                                            .foregroundColor(.accentPrimary)
                                    }
                                }
                                
                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(.accentPrimary)
                                    SecureField("enter password", text: $password) //A SecureField behaves similarly to a TextField, but hides the visible characters.
                                        .foregroundColor(theme.primaryText)
                                        .font(AppTypography.font(.body, size: 16))
                                }
                                .padding()
                                .background(theme.fieldBackground)
                                .cornerRadius(12)
                            }
                        }
                        
                        if let error = authManager.authError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                    }
                    .padding(24)
                    .background(theme.cardBackground)
                    .cornerRadius(32)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    NavigationLink(destination: RegisterView()) {
                        Text("CREATE ACCOUNT")
                            .appBodyFont(size: 16)
                            .tracking(1)
                            .foregroundColor(.accentPrimary)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    func signIn() async { //This function coordinates the login from the view’s perspective.
        isLoading = true //enables the local loading state. This changes what appears inside the button
        await authManager.signIn(email: email, password: password) //passing credentials to authManager, but this view does not call Supabase directly.
        isLoading = false
    }

    private struct Theme {
        let colorScheme: ColorScheme

        private var isDark: Bool {
            colorScheme == .dark
        }

        var background: Color {
            isDark ? .backgroundDarkPrimary : .backgroundPrimary
        }

        var cardBackground: Color {
            isDark ? .textPrimary : .surfacePrimary
        }

        var fieldBackground: Color {
            isDark ? Color.backgroundDarkPrimary.opacity(0.72) : Color.accentPrimary.opacity(0.15)
        }

        var primaryText: Color {
            isDark ? .backgroundPrimary : .textPrimary
        }
    }
}
