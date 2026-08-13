/*RootView acts as the app’s traffic controller: it decides which top-level screen should be visible based on authentication state.*/
import SwiftUI
struct RootView: View {
    @EnvironmentObject private var authManager: AuthManager //This retrieves the same AuthManager instance that was inserted in The_HighlightApp
    @Environment(\.colorScheme) private var colorScheme

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }

    var body: some View {
        Group { //Group is an invisible SwiftUI container. It simply lets you treat several conditional branches as one view.
            if authManager.isLoading { //This branch appears while the app is determining the authentication state or processing a login.
                ZStack { //The first view becomes the background, and the second appears above it.
                    theme.background.ignoresSafeArea() //Normally, SwiftUI avoids certain system-controlled regions, such as the status bar area, the home indicator area, screen edges affected by notches, but this allows the background color to extend across the entire screen.
                    ProgressView("Loading...") //shows a loading spinner and a text label.
                        .progressViewStyle(CircularProgressViewStyle(tint: .highlightTerracotta))
                        .foregroundColor(theme.primaryText)
                }
            } else if authManager.isAuthenticated { //isLoading == false and isAuthenticated == true. The user is no longer waiting, and the app believes a valid session exists.
                HomeView()
            } else { //isLoading == false and isAuthenticated == false
                AuthView() //the screen where the user enters their email and password and initiates login.
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated) //this animates Login View -> Home View
    }

    private struct Theme {
        let colorScheme: ColorScheme

        private var isDark: Bool {
            colorScheme == .dark
        }

        var background: Color {
            isDark ? .backgroundDarkPrimary : .highlightCream
        }

        var primaryText: Color {
            isDark ? .backgroundPrimary : .highlightEspresso
        }
    }
}
