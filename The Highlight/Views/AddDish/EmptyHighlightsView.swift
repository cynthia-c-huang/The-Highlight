import SwiftUI
struct EmptyHighlightsView: View {
    @Environment(\.colorScheme) private var colorScheme

    var onSaveComplete: (() -> Void)? = nil //This declares an optional closure property. () -> Void means it’s a function that takes no parameters and returns nothing. ? means that onSaveComplete can either contain a callback (A callback is just a function you give to another piece of code so it can call that function later) or nil. Since the default is nil, this allows the preview to compile EmptyHighlightsView without providing a callback.

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: 32) {
                VStack(spacing: 6) {
                    Text("SAVE YOUR FIRST")
                        .appHeaderFont(size: 28)
                        .foregroundColor(theme.primaryText)
                        .tracking(1)
                    Text("HIGHLIGHT")
                        .appHeaderFont(size: 28)
                        .foregroundColor(theme.highlightText)
                        .tracking(1)
                }
    //forwards the callback again, passing its own onSaveComplete property into AddDishView. isFirstTime tells AddDishView that it was opened through the first-highlight flow.
                NavigationLink(destination: AddDishView(isFirstTime: true, onSaveComplete: onSaveComplete)) {
                    ZStack {
                        Hexagon()
                            .fill(Color.accentSecondary)
                            .frame(width: 80, height: 88)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("Add your first highlight")
                }
            }
            .padding()
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

        var primaryText: Color {
            isDark ? .backgroundPrimary : .textPrimary
        }

        var highlightText: Color {
            isDark ? .backgroundPrimary : .accentPrimary
        }
    }
}
private struct Hexagon: Shape { //custom Shape
    func path(in rect: CGRect) -> Path {
        let w = rect.size.width
        let h = rect.size.height
        let points: [CGPoint] = [ //constructs 6 points
            CGPoint(x: 0.5*w, y: 0),
            CGPoint(x: w, y: 0.25*h),
            CGPoint(x: w, y: 0.75*h),
            CGPoint(x: 0.5*w, y: h),
            CGPoint(x: 0, y: 0.75*h),
            CGPoint(x: 0, y: 0.25*h)
        ]
        var path = Path()
        path.move(to: points[0]) //and connects them
        for p in points.dropFirst() { path.addLine(to: p) }
        path.closeSubpath() //connects the last point back to the first.
        return path
    }
}
#Preview {
    NavigationStack { EmptyHighlightsView() }
}
