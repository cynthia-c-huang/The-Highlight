import SwiftUI

struct AppTopNavigationRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var showsBackButton: Bool = true
    var leadingAction: () -> Void
    var trailingSystemName: String? = nil
    var trailingBackground: Color = Color.clear
    var trailingForeground: Color? = nil
    var trailingIconSize: CGFloat = 16
    var trailingAction: (() -> Void)? = nil

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }

    var body: some View {
        HStack {
            if showsBackButton {
                AppCircleIconButton(
                    systemName: "chevron.left",
                    background: theme.iconBackground,
                    foreground: theme.primaryText,
                    action: leadingAction
                )
            } else {
                Color.clear
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Text(title)
                .appHeaderFont(size: 24)
                .foregroundColor(theme.primaryText)

            Spacer()

            trailingIcon
        }
    }

    @ViewBuilder
    private var trailingIcon: some View {
        if let trailingSystemName {
            if let trailingAction {
                AppCircleIconButton(
                    systemName: trailingSystemName,
                    background: trailingBackground,
                    foreground: trailingForeground ?? theme.primaryText,
                    iconSize: trailingIconSize,
                    action: trailingAction
                )
            } else {
                AppCircleIconContent(
                    systemName: trailingSystemName,
                    background: trailingBackground,
                    foreground: trailingForeground ?? theme.primaryText,
                    iconSize: trailingIconSize
                )
                .accessibilityHidden(true)
            }
        } else {
            Color.clear
                .frame(width: 36, height: 36)
        }
    }

    private struct Theme {
        let colorScheme: ColorScheme

        private var isDark: Bool {
            colorScheme == .dark
        }

        var primaryText: Color {
            isDark ? .backgroundPrimary : .textPrimary
        }

        var iconBackground: Color {
            isDark ? .textPrimary : Color.backgroundPrimary.opacity(0.8)
        }
    }
}

struct AppCircleIconButton: View {
    let systemName: String
    let background: Color
    let foreground: Color
    var iconSize: CGFloat = 16
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppCircleIconContent(
                systemName: systemName,
                background: background,
                foreground: foreground,
                iconSize: iconSize
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AppCircleIconContent: View {
    let systemName: String
    let background: Color
    let foreground: Color
    let iconSize: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: iconSize, weight: .bold))
            .foregroundColor(foreground)
            .frame(width: 36, height: 36)
            .background(background)
            .clipShape(Circle())
    }
}

#Preview {
    AppTopNavigationRow(
        title: "DISHES",
        leadingAction: {}
    )
    .padding()
    .background(Color.backgroundPrimary)
}
