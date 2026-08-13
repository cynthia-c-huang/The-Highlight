import SwiftUI

struct HighlightLinkPickerView: View {
    let dish: DishReference
    @Binding private var highlights: [Highlight]

    private let previewImageAssets: [UUID: String]
    private let usesPreviewData: Bool
    var onLinkComplete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var isLinking = false
    @State private var linkErrorMessage: String?

    init(
        dish: DishReference,
        highlights: Binding<[Highlight]>,
        previewImageAssets: [UUID: String] = [:],
        usesPreviewData: Bool = false,
        onLinkComplete: (() -> Void)? = nil
    ) {
        self.dish = dish
        _highlights = highlights
        self.previewImageAssets = previewImageAssets
        self.usesPreviewData = usesPreviewData
        self.onLinkComplete = onLinkComplete
    }

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AppTopNavigationRow(
                        title: "LINK",
                        leadingAction: { dismiss() }
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Link a Highlight")
                            .appHeaderFont(size: 32)
                            .foregroundColor(theme.primaryText)

                        Text("Choose one of your saved Highlights to attach to \(dish.name).")
                            .appBodyFont(size: 15)
                            .foregroundColor(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    searchBar

                    if let linkErrorMessage {
                        Text(linkErrorMessage)
                            .appBodyFont(size: 13)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if filteredHighlights.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredHighlights) { highlight in
                                highlightRow(highlight)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.accentPrimary)

            TextField("", text: $searchText, prompt: Text("Search your Highlights...").foregroundColor(theme.secondaryText.opacity(0.78)))
                .appBodyFont(size: 15)
                .foregroundColor(theme.primaryText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.secondaryText.opacity(0.72))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(theme.controlBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.accentPrimary)

            Text("No available Highlights")
                .appHeaderFont(size: 24)
                .foregroundColor(theme.primaryText)

            Text(searchText.isEmpty ? "Highlights already linked to another catalog dish are hidden for now." : "Try a different search.")
                .appBodyFont(size: 14)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func highlightRow(_ highlight: Highlight) -> some View {
        let isAlreadyLinked = highlight.dishReferenceID == dish.id

        return HStack(spacing: 12) {
            thumbnail(for: highlight)
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(highlight.dish_name)
                    .appBodyBoldFont(size: 16)
                    .foregroundColor(theme.primaryText)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text("\(formattedRating(for: highlight)) / 10")
                        .appBodyBoldFont(size: 12)
                        .foregroundColor(.accentPrimary)

                    if let date = highlight.date_eaten {
                        Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .appBodyFont(size: 12)
                            .foregroundColor(theme.secondaryText)
                    }
                }
            }

            Spacer()

            Button {
                Task {
                    await attach(highlight)
                }
            } label: {
                if isAlreadyLinked {
                    Text("Linked")
                        .appBodyBoldFont(size: 12)
                        .foregroundColor(.accentPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 11)
                        .background(theme.controlBackground)
                        .clipShape(Capsule())
                } else if isLinking {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 58, height: 34)
                } else {
                    Text("Attach")
                        .appBodyBoldFont(size: 12)
                        .foregroundColor(.textPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 11)
                        .background(Color.surfacePrimary)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
            .disabled(isAlreadyLinked || isLinking)
        }
        .padding(14)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func thumbnail(for highlight: Highlight) -> some View {
        if let assetName = previewImageAssets[highlight.id] {
            Image(assetName)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                theme.photoFallbackBackground
                Image(systemName: "photo")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(theme.secondaryText)
            }
        }
    }

    private var filteredHighlights: [Highlight] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return highlights
            .filter { highlight in
                highlight.dishReferenceID == nil || highlight.dishReferenceID == dish.id
            }
            .filter { highlight in
                guard !query.isEmpty else { return true }
                return searchableText(for: highlight).localizedCaseInsensitiveContains(query)
            }
            .sorted { first, second in
                (first.date_eaten ?? first.created_at) > (second.date_eaten ?? second.created_at)
            }
    }

    private func searchableText(for highlight: Highlight) -> String {
        [
            highlight.dish_name,
            highlight.tags.joined(separator: " "),
            highlight.memoryNote ?? "",
            highlight.restaurantName ?? "",
            highlight.formattedAddress ?? ""
        ]
        .joined(separator: " ")
    }

    private func formattedRating(for highlight: Highlight) -> String {
        let halfStepRating = Int((highlight.rating * 2).rounded())
        if halfStepRating.isMultiple(of: 2) {
            return "\(halfStepRating / 2)"
        }
        return "\(halfStepRating / 2).5"
    }

    @MainActor
    private func attach(_ highlight: Highlight) async {
        guard !isLinking else { return }

        isLinking = true
        linkErrorMessage = nil

        do {
            if usesPreviewData {
                highlights = highlights.map { currentHighlight in
                    currentHighlight.id == highlight.id
                        ? currentHighlight.withDishReferenceID(dish.id)
                        : currentHighlight
                }
            } else {
                try await HighlightService.shared.updateDishReference(
                    highlightID: highlight.id,
                    dishReferenceID: dish.id
                )
                highlights = try await HighlightService.shared.fetchHighlights()
            }

            onLinkComplete?()
            dismiss()
        } catch {
            linkErrorMessage = "Unable to link that Highlight. Please try again."
            #if DEBUG
            print("[DishDiscovery] Highlight attach failed: \(error.localizedDescription)")
            #endif
        }

        isLinking = false
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

        var secondaryText: Color {
            primaryText.opacity(0.72)
        }

        var controlBackground: Color {
            isDark ? .textPrimary : .containerPrimary
        }

        var cardBackground: Color {
            isDark ? .textPrimary : .containerPrimary
        }

        var photoFallbackBackground: Color {
            isDark ? Color.backgroundDarkPrimary.opacity(0.7) : Color.backgroundPrimary.opacity(0.55)
        }
    }
}

#Preview("Highlight Link Picker") {
    let previewHighlights = HomeView.previewHighlights.map { highlight in
        highlight.id == HomeView.ahBongSoftServeID
            ? highlight.withDishReferenceID(DishReference.previewKimchiJjigaeID)
            : highlight
    }

    HighlightLinkPickerView(
        dish: DishReference.previewCatalog[0],
        highlights: .constant(previewHighlights),
        previewImageAssets: HomeView.previewImageAssets,
        usesPreviewData: true
    )
}
