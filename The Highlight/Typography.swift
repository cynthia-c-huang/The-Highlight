import SwiftUI

public enum AppFontRole {
    case header   // Barriecito
    case body     // Cantarell Regular
    case bodyBold // Cantarell Bold (template for future use)
    case bodyItalic // Cantarell Italic (template)
    case bodyBoldItalic // Cantarell Bold Italic (template)
}

public struct AppTypography {
    // Font names must match those registered in Info.plist (UIAppFonts) and the internal PostScript names.
    // Update the names below if the actual internal names differ.
    public struct Names {
        public static let barriecito = "Barriecito-Regular"
        public static let cantarellRegular = "Cantarell-Regular"
        public static let cantarellBold = "Cantarell-Bold"
        public static let cantarellItalic = "Cantarell-Italic"
        public static let cantarellBoldItalic = "Cantarell-BoldItalic"
    }

    public static func font(_ role: AppFontRole, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch role {
        case .header:
            // Barriecito is display style; ignore weight and use provided size
            return Font.custom(Names.barriecito, size: size)
        case .body:
            return Font.custom(Names.cantarellRegular, size: size)
        case .bodyBold:
            return Font.custom(Names.cantarellBold, size: size)
        case .bodyItalic:
            return Font.custom(Names.cantarellItalic, size: size)
        case .bodyBoldItalic:
            return Font.custom(Names.cantarellBoldItalic, size: size)
        }
    }
}

public extension View {
    func appHeaderFont(size: CGFloat) -> some View {
        self.font(AppTypography.font(.header, size: size))
    }

    func appBodyFont(size: CGFloat) -> some View {
        self.font(AppTypography.font(.body, size: size))
    }

    // Templates for future use
    func appBodyBoldFont(size: CGFloat) -> some View {
        self.font(AppTypography.font(.bodyBold, size: size))
    }

    func appBodyItalicFont(size: CGFloat) -> some View {
        self.font(AppTypography.font(.bodyItalic, size: size))
    }

    func appBodyBoldItalicFont(size: CGFloat) -> some View {
        self.font(AppTypography.font(.bodyBoldItalic, size: size))
    }
}
