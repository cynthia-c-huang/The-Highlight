import SwiftUI
/* AppAppearance
 → defines the available choices and persistence rules

 The_HighlightApp
 → reads the stored choice and applies it globally

 SwiftUI environment
 → tells every descendant whether it is currently light or dark

 Individual view themes
 → choose the actual palette colors for that screen */
enum AppAppearance: String/*This makes AppAppearance a raw-value enum where every case has a corresponding string*/, CaseIterable /*asks Swift to generate a collection containing all the enum’s cases*/, Hashable /*an AppAppearance value can produce a stable hash and can be used in hashed collections or as a dictionary key*/, Identifiable /*every enum value provides an identifier through an id property, making forEach easier*/ {
    case system //Each case represents one possible user preference.
    case light
    case dark
    static let preferenceKey = "preferences.appAppearance" //AppAppearance.preferenceKey == "preferences.appAppearance" (avoids retyping, it is the shared lookup name used by all readers and writers). UserDefaults contains entries like preferences.appAppearance:"dark"

    //The root applies it as .animation(AppAppearance.transitionAnimation, value: selectedAppearanceRawValue)
    //When selectedAppearanceRawValue changes, animate animatable changes in this view hierarchy using this animation.
    static let transitionAnimation: Animation = .easeInOut(duration: 0.35)

    var id: String { rawValue }
//The enum contains: var title: String, var subtitle: String, var systemImage: String
//This keeps the UI description of each appearance together with the appearance itself.
//That is why PreferencesView can do Text(viewModel.selectedAppearance.subtitle) -- the view does not need its own switch statement
    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var subtitle: String {
        switch self {
        case .system:
            return "Follow device setting"
        case .light:
            return "Light mode"
        case .dark:
            return "Dark mode"
        }
    }

    var systemImage: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
//converts your app-specific type AppAppearance into SwiftUI's type ColorScheme?
//    AppAppearance.system → nil (There is no .system case in ColorScheme. System doesn't force either one,
//    allowing the device to decide. So nil means “no override.”
//    AppAppearance.light  → ColorScheme.light
//    AppAppearance.dark   → ColorScheme.dark
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    //Reading the current stored preference
    static func stored(in userDefaults: UserDefaults = .standard) -> AppAppearance {
        guard let rawValue = userDefaults.string(forKey: preferenceKey) /*might return "dark*/,
              let appearance = AppAppearance(rawValue: rawValue) /*returns .dark*/ else {
            return .system //happens when no valid new preference exists. So brand-new installations default to following the device.
        }

        return appearance
    }
}
