import SwiftUI
import Supabase
//This is the top-level SwiftUI app object. Because it wraps RootView, it is the best place to apply a setting meant to affect the whole app.
@main
struct The_HighlightApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var dishCatalogStore = DishCatalogStore()
    //@AppStorage then watches the corresponding UserDefaults entry. When "preferences.appAppearance" changes, SwiftUI updates selectedAppearanceRawValue and reevaluates the app’s scene content.
    @AppStorage(AppAppearance.preferenceKey /*this is preferences.appAppearance*/) private var selectedAppearanceRawValue = AppAppearance.stored().rawValue //the stored string, like "light" or "dark". The default expression from .stored() returns "system."
    //turning the raw string back into an enum
    //@AppStorage gives you a string, but .preferredColorScheme needs an appearance decision.
    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: selectedAppearanceRawValue) ?? .system //If an invalid value is somehow stored, the initializer returns nil, and ?? .system is the safe fallback
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(dishCatalogStore)
            //Because the modifier is attached to RootView, all views presented underneath it inherit the resolved color scheme.
                // V SwiftUI view modifier    V the computed property from var preferredColorScheme: ColorScheme?
                .preferredColorScheme(selectedAppearance.preferredColorScheme) //note when selectedAppearance is "system," the computed property returns nil. Passing .preferredColorScheme(nil) means SwiftUI allows the device setting to decide.
                .animation(AppAppearance.transitionAnimation, value: selectedAppearanceRawValue) //value limits the animation trigger to changes in that value. It does not animate every unrelated change throughout the app.
                .onOpenURL { url in
                    Task {
                        try? await SupabaseManager.shared.client.auth.session(from: url) //error handling returns nil
                    }
                }
                #if DEBUG
                .task {
                    // Log available font families and a sample of font names to verify custom fonts are loaded
                    for family in UIFont.familyNames.sorted() {
                        let names = UIFont.fontNames(forFamilyName: family).sorted()
                        print("[Fonts] Family: \(family) -> \(names)")
                    }
                }
                #endif
        }
    }
}
