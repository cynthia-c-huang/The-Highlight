import SwiftUI

public extension Color {
    // Semantic colors backed by Asset Catalog
    static let backgroundPrimary: Color = Color("Background Cream", bundle: .main)
    static let backgroundDarkPrimary: Color = Color("Background Dark", bundle: .main)
    static let accentPrimary: Color = Color("Terracotta Orange", bundle: .main)
    static let textPrimary: Color = Color("Dark Purple", bundle: .main)
    static let surfacePrimary: Color = Color("Gold", bundle: .main)
    static let accentSecondary: Color = Color("Dusty Mauve", bundle: .main)
    static let containerPrimary: Color = Color("Container", bundle: .main)

    static func descriptionTagBackground(for tag: String) -> Color {
        switch tag.normalizedDescriptionTag {
        case "sweet", "umami", "dense", "airy",
            "aromatic", "earthy", "caramelized", "smooth", "stretchy", "velvety":
            return .accentSecondary
        case "spicy", "smoky", "chewy", "salty",
            "citrusy", "meaty", "peppery", "brothy", "charred", "crunchy", "firm":
            return .accentPrimary
        case "tangy", "buttery", "refreshing", "crispy", "tender", "fluffy", "creamy", "flaky",
            "cheesy", "garlicky", "sour", "baked", "chunky", "moist", "saucy":
            return .surfacePrimary
        default:
            return .surfacePrimary
        }
    }
}

private extension String {
    var normalizedDescriptionTag: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

#if DEBUG
// Helper kept for future preview-specific fallbacks if needed.
private extension Color {
    static func fallback(_ named: String, default color: Color) -> Color { color }
}
#endif
