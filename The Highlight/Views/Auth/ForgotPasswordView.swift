import SwiftUI
import Supabase

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var isLoading = false

    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }
    
    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("Reset Password")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(theme.primaryText)
                    .padding(.bottom, 20)
                TextField("", text: $email, prompt: Text("Email").foregroundColor(theme.secondaryText))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .foregroundColor(theme.primaryText)
                    .padding()
                    .background(theme.fieldBackground)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                if let message {
                    Text(message)
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                Button(action: resetPassword) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send Reset Link")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 40)
        }
    }
    
    func resetPassword() {
        isLoading = true
        errorMessage = nil
        message = nil
        Task {
            do {
                try await SupabaseManager.shared.client.auth.resetPasswordForEmail(email)
                message = "Password reset link sent to your email."
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private struct Theme {
        let colorScheme: ColorScheme

        private var isDark: Bool {
            colorScheme == .dark
        }

        var background: Color {
            isDark ? .backgroundDarkPrimary : .backgroundPrimary
        }

        var fieldBackground: Color {
            isDark ? .textPrimary : .white
        }

        var primaryText: Color {
            isDark ? .backgroundPrimary : .textPrimary
        }

        var secondaryText: Color {
            primaryText.opacity(0.62)
        }
    }
}
