import SwiftUI
import Supabase

struct RegisterView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }
    
    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(theme.primaryText)
                    .padding(.bottom, 20)
                
                VStack(spacing: 16) {
                    TextField("", text: $email, prompt: Text("Email").foregroundColor(theme.secondaryText))
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .foregroundColor(theme.primaryText)
                        .padding()
                        .background(theme.fieldBackground)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    
                    SecureField("", text: $password, prompt: Text("Password").foregroundColor(theme.secondaryText))
                        .foregroundColor(theme.primaryText)
                        .padding()
                        .background(theme.fieldBackground)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    
                    SecureField("", text: $confirmPassword, prompt: Text("Confirm Password").foregroundColor(theme.secondaryText))
                        .foregroundColor(theme.primaryText)
                        .padding()
                        .background(theme.fieldBackground)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                }
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: signUp) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign Up")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.surfacePrimary)
                    .foregroundColor(.textPrimary)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.top, 40)
        }
    }
    
    func signUp() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await SupabaseManager.shared.client.auth.signUp(email: email, password: password)
                // If email confirmation is required, handle it here.
                dismiss()
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
