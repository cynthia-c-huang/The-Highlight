//HomeView
//- decides when to load
//- shows loading, content, empty, or error UI
//- stores fetched highlights for display
//
//HighlightService
//- communicates with Supabase
//- obtains the authenticated user
//- performs the database query
//- decodes rows into [Highlight]

import SwiftUI
struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject private var dishCatalogStore: DishCatalogStore
    @Environment(\.colorScheme) private var colorScheme //if this is light, all descendants of RootView see colorScheme == .light
    
    @State private var highlights: [Highlight] = [] //Since this property is state, SwiftUI rerenders the parts of the screen that depend on it.
    @State private var occasions: [Occasion] = []
    @State private var isLoading: Bool = false
    @State private var loadError: String? = nil
    @State private var selectedFeaturedIndex: Int = 0
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
//The enum represents three possible sources for a highlight image. This enum gives the rest of the UI one consistent way to talk about images, even though they may come from different places.
    enum HighlightImageSource: Hashable {
        case remote(path: String) //This image is stored remotely in Supabase Storage, and this is its storage path. The associated path string travels with the enum case.
        case asset(name: String) //This image is bundled locally inside the Xcode asset catalog.
        case placeholder //This highlight does not currently have an image, so display a fallback graphic.
        var hasImage: Bool {
            switch self {
            case .remote, .asset:
                return true
            case .placeholder:
                return false
            }
        }
    }
    private let previewImageAssets: [UUID: String]
    private let previewOccasions: [Occasion]?
    private let previewDishes: [DishReference]?
    private let shouldLoadRemoteHighlights: Bool
    init(
        previewHighlights: [Highlight]? = nil,
        previewImageAssets: [UUID: String] = [:],
        previewOccasions: [Occasion]? = nil,
        previewDishes: [DishReference]? = nil
    ) {
        _highlights = State(initialValue: previewHighlights ?? [])
        _occasions = State(initialValue: previewOccasions ?? [])
        self.previewImageAssets = previewImageAssets
        self.previewOccasions = previewOccasions
        self.previewDishes = previewDishes
        self.shouldLoadRemoteHighlights = previewHighlights == nil
    }
    private var featuredHighlights: [Highlight] { //featuredHighlights contains at most four highlights that have some real image source.
//highlights = fetchHighlights() orders rows by newest created_at first, so a newly created highlight with a photo is likely to enter the featured list.
        let highlightsWithPhotos = highlights.filter { imageSource(for: $0).hasImage } //hasImage returns true for .remote and .asset and false for .placeholder
        return Array(highlightsWithPhotos.prefix(4))
    }
    private var displayedFeaturedHighlights: [Highlight] {
//If at least one highlight has an image, use photo-backed highlights.
//If none has an image, use the first four highlights anyway and show placeholders.
        featuredHighlights.isEmpty ? Array(highlights.prefix(4)) : featuredHighlights
    }
    private var topHighlights: [Highlight] {
//sorts by rating, highest first, then recency, newest first when ratings tie
        Array(
            highlights
                .sorted { first, second in
                    if first.rating != second.rating {
                        return first.rating > second.rating
                    }
                    return recencyDate(for: first) > recencyDate(for: second)
                }
                .prefix(4)
        )
    }
    private var theme: HomeTheme { //HomeTheme converts scheme into page design
        HomeTheme(colorScheme: colorScheme)
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    theme.background
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 0) {
                            // Top Navbar Section
                            VStack(spacing: 20) {
                                // Logo Row
                                HStack {
                                    Spacer()
                                    
                                    Image(theme.logoAssetName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 50)
                                        .accessibilityLabel("App Logo")
                                    Text("The Highlight")
                                        .appHeaderFont(size: 30)
                                        .foregroundColor(theme.appTitle)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                // Nav Buttons
                                HStack {
                                    NavigationLink { //When you push Dishes, Map, or AddDish, Home usually remains alive underneath.
                                        DishesView(
                                            highlights: $highlights,
                                            occasions: occasions,
                                            previewImageAssets: previewImageAssets,
                                            onSaveComplete: refreshHighlightsAfterSave
                                        )
                                    } label: {
                                        navButtonView(icon: "fork.knife", title: "Dishes")
                                    }
                                    .foregroundColor(theme.text)
                                    Spacer()
                                    NavigationLink {
                                        MapView(
                                            highlights: $highlights,
                                            occasions: occasions,
                                            previewImageAssets: previewImageAssets,
                                            onSaveComplete: refreshHighlightsAfterSave
                                        )
                                    } label: {
                                        navButtonView(icon: "map", title: "Map")
                                    }
                                    .foregroundColor(theme.text)
                                    Spacer()
        /*This does not call refreshHighlightsAfterSave() immediately. Notice the absence of parentheses. Instead, it passes this function itself as a value so another view can call it later (closure callback: Swift functions can be passed around like other values.) */
                                    NavigationLink {
                                        DiscoverDishesView(
                                            highlights: $highlights,
                                            occasions: occasions,
                                            previewImageAssets: previewImageAssets,
                                            previewDishes: previewDishes,
                                            previewOccasions: previewOccasions,
                                            usesPreviewData: !shouldLoadRemoteHighlights,
                                            onSaveComplete: refreshHighlightsAfterSave
                                        )
                                    } label: {
                                        navButtonView(icon: "sparkle.magnifyingglass", title: "Discover")
                                    } //When the user taps Discover, the NavigationLink pushes the shared catalog browser onto the navigation stack.
                                    .foregroundColor(theme.text)
                                    Spacer()
                                    Menu {
                                        Section("Signed in") {
                                            NavigationLink(destination: PreferencesView(savedHighlightCount: highlights.count)) {
                                                Label("Preferences", systemImage: "gear")
                                            }
                                            Button(role: .destructive, action: {
                                                Task {
                                                    try? await authManager.signOut()
                                                }
                                            }) {
                                                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                            }
                                        }
                                    } label: {
                                        navButtonView(icon: "person.crop.circle", title: "Profile")
                                    }
                                    .foregroundColor(theme.text)
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 16)
                            }
                            .padding(.top, 50) // Adjust for safe area
                            .background(theme.navigationBackground)
                            
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 350)
                                    .background(theme.background)
                            } else if let loadError { //if the highlights were failed to be fetched
                                VStack(spacing: 12) {
                                    Text("Unable to load highlights")
                                        .appHeaderFont(size: 24)
                                        .foregroundColor(theme.text)
                                    Text(loadError)
                                        .appBodyFont(size: 13)
                                        .foregroundColor(theme.text.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                    Button {
                                        Task {
                                            await loadHighlights() //Try again button starts another asynchronous task
                                        }
                                    } label: {
                                        Text("Try Again")
                                            .appBodyFont(size: 14)
                                            .foregroundColor(theme.text)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 18)
                                            .background(theme.retryButtonBackground)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, minHeight: 350)
                                .background(theme.background)
                            } else if highlights.isEmpty { //result of highlights determines whether the user sees the slideshow or the empty view
                                EmptyHighlightsView(onSaveComplete: refreshHighlightsAfterSave)
                                    .frame(maxWidth: .infinity, minHeight: 350)
                                    .background(theme.background)
                            } else {
                                // Slideshow Area
                                ZStack(alignment: .bottom) {
                                    TabView(selection: $selectedFeaturedIndex) { /* the slideshow selection is bound to selectedFeaturedIndex. The $ passes a binding, meaning TabView can both read which page should currently be selected and update the value when the user swipes to another page*/
                                        ForEach(Array(displayedFeaturedHighlights.enumerated()) /*the data*/, id: \.element.id /*tells SwiftUI that each item’s stable identity is the highlight’s UUID.*/) { index, highlight in
                                            FeaturedHighlightSlide(
                                                highlight: highlight,
                                                imageSource: imageSource(for: highlight),
                                                textColor: theme.featuredOverlayText //Home makes the theme decision and passes down the final visual value.
                                            ) /*Each highlighted record gets its own FeaturedHighlightSlide, which receives two pieces of data, the highlight and the imageSource. The highlight provides text such as the dish name and location type. The imageSource tells the slide how to obtain its image.*/
                                                .tag(index) //Each slide is assigned an identifier. The tag is attached externally by SwiftUI as part of the parent view hierarchy.
                                        }
                                    }
                                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                    .frame(height: 350)
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            FeaturedPageDots(
                                                count: displayedFeaturedHighlights.count,
                                                selectedIndex: selectedFeaturedIndex
                                            )
                                        }
                                        .padding(.trailing, 18)
                                        .padding(.bottom, 24)
                                    }
                                    .frame(height: 350)
                                    
                                    Button {
                                        withAnimation {
                                            proxy.scrollTo("TopHighlights", anchor: .top)
                                        }
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text("TOP HIGHLIGHTS")
                                                .appBodyFont(size: 12)
                                                .fontWeight(.bold)
                                                .tracking(1)
                                                .foregroundColor(theme.featuredOverlayText)
                                            Image(systemName: "chevron.down")
                                                .font(.headline)
                                                .foregroundColor(theme.featuredOverlayText)
                                        }
                                        .padding(.bottom, 16)
                                    }
                                }
//If the displayed highlight list changes after a reload, the ID array changes, causing SwiftUI to restart the slideshow task for the new data.
                                .task(id: displayedFeaturedHighlights.map(\.id)) {
                                    await startFeaturedSlideshow()
                                }
                                
                                // Top Highlights Section
                                VStack(spacing: 24) {
                                    HStack(spacing: 8) {
                                        Text("Top Highlights")
                                            .appHeaderFont(size: 28)
                                            .foregroundColor(theme.text)
                                        
                                        Image(systemName: "sparkles")
                                            .font(.title2)
                                            .foregroundColor(.accentPrimary)
                                    }
                                    .padding(.top, 24)
                                    
                                    LazyVGrid(columns: columns, spacing: 32) {
                                        ForEach(Array(topHighlights.enumerated()), id: \.element.id) { index, highlight in
                                            NavigationLink { /*tapping a Home highlight pushes DishDescriptionView. Home passes its actual @State highlights array as a binding using $highlights, which lets the description screen update Home’s array after an edit or deletion.*/
                                                DishDescriptionView(
                                                    highlight: highlight,
                                                    highlights: $highlights,
                                                    occasions: occasions /*Dishes cannot mutate Home’s occasion array directly. Instead, occasion changes call onSaveComplete: refreshHighlightsAfterSave, which causes Home to refetch both arrays.*/,
                                                    previewImageAssets: previewImageAssets,
                                                    onSaveComplete: refreshHighlightsAfterSave
                                                )
                                            } label: {
                                                HighlightCard(
                                                    highlight: highlight,
                                                    rotationDegrees: index.isMultiple(of: 2) ? -2 : 2,
                                                    imageSource: imageSource(for: highlight),
                                                    theme: theme.highlightCard
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 100) // Space for FAB
                                }
                                .id("TopHighlights")
                                .background(theme.background)
                            }
                        }
                        .task { //starts asynchronous work while HomeView is onscreen
                            if shouldLoadRemoteHighlights { //Normal HomeView() receives no preview data, so it loads from Supabase. A preview that supplies previewHighlights does not contact Supabase.
                                Task {
                                    await dishCatalogStore.loadIfNeeded()
                                }
                                await loadHighlights()
                            }
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    
                    // Floating Action Button
                    NavigationLink(destination: AddDishView(previewOccasions: previewOccasions, onSaveComplete: refreshHighlightsAfterSave)) {
                        ZStack {
                            Circle()
                                .fill(Color.accentPrimary)
                                .frame(width: 70, height: 70)
                                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(theme.plusButtonIcon)
                        }
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
        }
    }
    private func imageSource(for highlight: Highlight) -> HighlightImageSource {
        if let assetName = previewImageAssets[highlight.id] {
            return .asset(name: assetName)
        }
        if let photoPath = highlight.photo_path {
            return .remote(path: photoPath)
        }
        return .placeholder
    }
    private func recencyDate(for highlight: Highlight) -> Date {
        highlight.date_eaten ?? highlight.created_at
    }
    
    private func refreshHighlightsAfterSave() {
        guard shouldLoadRemoteHighlights else { /*Skip remote fetching in previews. In an Xcode preview containing locally supplied sample highlights, shouldLoadRemoteHighlights == false, so the callback exits without contacting Supabase. */
            return
        }
        Task {
            await loadHighlights() //reloads highlights asynchronously
        }
    }
    @MainActor /*This method modifies UI-related state, so @MainActor ensures these state updates happen on the main actor, where interface state should be changed. */
    private func loadHighlights() async { //this is the UI-side coordinator for fetching highlights.
        isLoading = true //because isLoading is @State, SwiftUI reevaluates the body
        loadError = nil //clears previous errors
        do {
            let fetchedHighlights = try await HighlightService.shared.fetchHighlights() //service call transfers responsibility to HighlightService
            let fetchedOccasions = (try? await OccasionService.shared.fetchOccasions()) ?? [] //Occasion loading uses try?, so its failure does not enter the outer catch. That means if the highlight fetch succeeds but this fails, the dishes are still displayed and occasions is empty []. This is graceful degradation. The main dish tracker remains usable even if the meal metadata cannot be fetched. However, grouped dishes may temporarily appear to lack their meal names because the occasion_id values exist while the corresponding Occasion objects are missing.
            highlights = fetchedHighlights //if fetchHighlights succeeds, the returned array becomes the view’s local state.
            occasions = fetchedOccasions
            selectedFeaturedIndex = 0 //ensures the featured slideshow begins at its first item after new data is loaded.
        } catch {
            loadError = error.localizedDescription //The error is converted into text and stored
            highlights = []
            occasions = []
            selectedFeaturedIndex = 0
        }
        isLoading = false
    }
    @MainActor
    private func startFeaturedSlideshow() async {
        guard displayedFeaturedHighlights.count > 1 else {
            return
        }
        if selectedFeaturedIndex >= displayedFeaturedHighlights.count {
            selectedFeaturedIndex = 0
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, displayedFeaturedHighlights.count > 1 else {
                return
            }
            withAnimation(.easeInOut(duration: 0.35)) {
                selectedFeaturedIndex = (selectedFeaturedIndex + 1) % displayedFeaturedHighlights.count //The modulo operation wraps around.
            }
        }
    }
    
    private func navButton(icon: String, title: String) -> some View {
        Button(action: {}) {
            navButtonView(icon: icon, title: title)
        }
    }
    
    private func navButtonView(icon: String, title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .appBodyFont(size: 12)
                .fontWeight(.bold)
        }
        .foregroundColor(theme.text)
    }
    struct FeaturedPageDots: View {
        let count: Int
        let selectedIndex: Int
        var body: some View {
            if count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<count, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.45))
                            .frame(
                                width: index == selectedIndex ? 8 : 6,
                                height: index == selectedIndex ? 8 : 6
                            )
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color.black.opacity(0.18))
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.2), value: selectedIndex)
            }
        }
    }
    struct FeaturedHighlightSlide: View {
        let highlight: Highlight
        let imageSource: HighlightImageSource
        let textColor: Color
        @State private var photoURL: URL? = nil //This URL begins as nil because the view has not yet asked Supabase for access.
        var body: some View { /*bodies must be synchronous, meaning it needs to return a view immediately. A network call may take an unpredictable amount of time.*/
            ZStack(alignment: .bottomLeading) {
                Group {
                    switch imageSource { //selects the correct image-loading branch
                    case .asset(let name): //For .asset, there is no task or download needed
                        Image(name)
                            .resizable()
                            .scaledToFill() //Scale the image until the entire destination frame is filled, even if some portions must be cropped.
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .remote:
                        if let photoURL { //AsyncImage handles the actual download and renders the image, and the phase determines what appears
                            AsyncImage(url: photoURL) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView() //image is currently downloading
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color.accentSecondary.opacity(0.35))
                                case .success(let image): //The download succeeded, so the actual image is displayed.
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                case .failure: //The download failed.
                                    fallbackImage
                                @unknown default:
                                    fallbackImage
                                }
                            }
                        } else {
                            fallbackImage
                        }
                    case .placeholder: //For .placeholder, the fallback is displayed immediately:
                        fallbackImage
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 350, maxHeight: 350)
                .clipped() //hides portions extending beyond the 350-point frame.
                .overlay(Color.black.opacity(0.3)) //darkens the photo so the white dish and location text remain readable.
                VStack(alignment: .leading, spacing: 4) {
                    Text(highlight.location_type.uppercased())
                        .appBodyFont(size: 16)
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundColor(textColor)
                    Text(highlight.dish_name)
                        .appBodyFont(size: 18)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                }
                .padding(.horizontal)
                .padding(.bottom, 70)
            }
            .task(id: imageSource) { //This task is a modifier attached to the Group, so when this view becomes active, this task runs. It also reruns if imageSource changes. It attains the signedURL
                await loadPhotoURL()
            }
        }
        private var fallbackImage: some View {
            Rectangle()
                .fill(Color.accentSecondary.opacity(0.35))
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                )
        }
        @MainActor
        private func loadPhotoURL() async { //asks Supabase storage for a signedURL
            photoURL = nil
            guard case .remote(let path) = imageSource else {
                return
            }
            photoURL = try? await HighlightService.shared.signedURL(for: path)
        }
    }
    
    struct HighlightCard: View {
        let highlight: Highlight
        let rotationDegrees: Double
        let imageSource: HighlightImageSource
        let theme: Theme
        
        @State private var photoURL: URL? = nil

        struct Theme {
            let background: Color
            let text: Color
            let fallbackBackground: Color

            static let standard = Theme(
                background: .surfacePrimary,
                text: .textPrimary,
                fallbackBackground: Color.backgroundPrimary.opacity(0.3)
            )
        }

        init(
            highlight: Highlight,
            rotationDegrees: Double,
            imageSource: HighlightImageSource,
            theme: Theme = .standard
        ) {
            self.highlight = highlight
            self.rotationDegrees = rotationDegrees
            self.imageSource = imageSource
            self.theme = theme
        }
        
        var body: some View {
            GeometryReader { proxy in
                let side = proxy.size.width
                let imageHeight = side * 0.68
                VStack(alignment: .leading, spacing: 0) {
                    cardImage
                        .frame(width: max(side - 16, 0), height: imageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .clipped()
                        .padding(.top, 8)
                        .padding(.horizontal, 8)
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        Image(systemName: dishSourceIconName)
                            .foregroundColor(.accentSecondary)
                        Text(highlight.dish_name)
                            .appBodyFont(size: 12)
                            .fontWeight(.bold)
                            .foregroundColor(theme.text)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .frame(width: side, height: side)
                .background(theme.background)
                .cornerRadius(24)
                .overlay(alignment: .topLeading) {
                    Text(formattedRating)
                        .appHeaderFont(size: 36)
                        .foregroundColor(theme.text)
                        .offset(x: -8, y: -22)
                        .allowsHitTesting(false)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .rotationEffect(.degrees(rotationDegrees))
            .padding(.top, 16)
            .padding(.bottom, 6)
            .contentShape(RoundedRectangle(cornerRadius: 24))
            .task(id: imageSource) {
                await loadPhotoURL() //Each card is responsible for its own image-loading state.
            }
        }
        private var formattedRating: String {
            let halfStepRating = Int((highlight.rating * 2).rounded())
            if halfStepRating.isMultiple(of: 2) {
                return "\(halfStepRating / 2)"
            }
            return "\(halfStepRating / 2).5"
        }

        private var dishSourceIconName: String {
            highlight.location_type.lowercased() == "restaurant" ? "fork.knife" : "house.fill"
        }

        @ViewBuilder
        private var cardImage: some View {
            switch imageSource {
            case .asset(let name):
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .remote:
                if let url = photoURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(theme.fallbackBackground)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .failure:
                            fallbackImage
                        @unknown default:
                            fallbackImage
                        }
                    }
                } else {
                    fallbackImage
                }
            case .placeholder:
                fallbackImage
            }
        }
        private var fallbackImage: some View {
            Rectangle()
                .fill(theme.fallbackBackground)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(theme.text.opacity(0.62))
                )
        }
        @MainActor
        private func loadPhotoURL() async {
            photoURL = nil
            guard case .remote(let path) = imageSource else {
                return
            }
            photoURL = try? await HighlightService.shared.signedURL(for: path)
        }
    }

    private struct HomeTheme {
        let colorScheme: ColorScheme

        private var isDark: Bool {
            colorScheme == .dark
        }
        //The theme makes Home-specific design decisions. The global environment decides light versus dark, but the local theme decides what those modes look like for Home.
        var background: Color {
            isDark ? .backgroundDarkPrimary : .backgroundPrimary
        }

        var text: Color {
            isDark ? .backgroundPrimary : .textPrimary
        }

        var navigationBackground: Color {
            isDark ? .backgroundDarkPrimary : .accentPrimary
        }

        var appTitle: Color {
            isDark ? .accentPrimary : .textPrimary
        }

        var logoAssetName: String {
            isDark ? "AppLogo" : "AppLogoDark"
        }

        var featuredOverlayText: Color {
            isDark ? .backgroundPrimary : .white
        }

        var retryButtonBackground: Color {
            isDark ? .textPrimary : .surfacePrimary
        }

        var plusButtonIcon: Color {
            isDark ? .backgroundDarkPrimary : .white
        }

        var highlightCard: HighlightCard.Theme {
            HighlightCard.Theme(
                background: isDark ? .textPrimary : .surfacePrimary,
                text: isDark ? .backgroundPrimary : .textPrimary,
                fallbackBackground: (isDark ? Color.backgroundDarkPrimary : Color.backgroundPrimary).opacity(0.3)
            )
        }
    }
}
extension HomeView {
    static let ahBongSoftServeID = UUID(uuidString: "0A92C4F5-2084-4B1E-B46A-7B37F17748E1") ?? UUID()
    static let chickenCroffleID = UUID(uuidString: "BFD5FC7C-09F1-4020-B587-3D1ED0D3ED7F") ?? UUID()
    static let honeyChiliPorkChopsID = UUID(uuidString: "98BEF238-612B-4087-A31E-B705BB39DF32") ?? UUID()
    static let tunaSushiRollID = UUID(uuidString: "68777D11-D5AA-4D1F-89D9-985A7859A7B7") ?? UUID()
    static let previewUserID = UUID(uuidString: "9781D37B-E752-4A1E-8920-D6B0F9662F18") ?? UUID()
    static let previewMealOccasionID = UUID(uuidString: "F96C192B-9B99-4EB1-9E73-D657115D0422") ?? UUID()
    static let previewImageAssets: [UUID: String] = [
        ahBongSoftServeID: "Ah Bong Soft Serve",
        chickenCroffleID: "Chicken Croffle",
        honeyChiliPorkChopsID: "Honey Chili Pork Chops",
        tunaSushiRollID: "Tuna Sushi Roll"
    ]
    static let previewOccasions: [Occasion] = [
        Occasion(
            id: previewMealOccasionID,
            user_id: previewUserID,
            title: "Koreatown dessert crawl",
            date: Date(timeIntervalSince1970: 1_781_496_000),
            restaurantName: nil,
            formattedAddress: "Los Angeles, CA",
            latitude: 34.0659,
            longitude: -118.3090,
            created_at: Date(timeIntervalSince1970: 1_781_496_000)
        )
    ]
    static let previewHighlights: [Highlight] = [
        Highlight(
            id: ahBongSoftServeID,
            user_id: previewUserID,
            dish_name: "Ah Bong Soft Serve",
            location_type: "restaurant",
            date_eaten: Date(timeIntervalSince1970: 1_781_496_000),
            tags: ["dessert", "soft serve"],
            photo_path: nil,
            rating: 9,
            memoryNote: "Milky soft serve after dinner.",
            restaurantName: "Ah Bong",
            formattedAddress: "450 S Western Ave\nLos Angeles, CA 90020\nUnited States",
            latitude: 34.0659,
            longitude: -118.3090,
            occasion_id: previewMealOccasionID,
            created_at: Date(timeIntervalSince1970: 1_781_496_000)
        ),
        Highlight(
            id: chickenCroffleID,
            user_id: previewUserID,
            dish_name: "Chicken Croffle",
            location_type: "restaurant",
            date_eaten: Date(timeIntervalSince1970: 1_779_580_800),
            tags: ["brunch", "crispy"],
            photo_path: nil,
            rating: 8.5,
            memoryNote: "Sweet, savory, and louder than expected.",
            restaurantName: "Cafe Croffle",
            formattedAddress: "308 E 2nd St\nLos Angeles, CA 90012\nUnited States",
            latitude: 34.0494,
            longitude: -118.2401,
            occasion_id: previewMealOccasionID,
            created_at: Date(timeIntervalSince1970: 1_779_580_800)
        ),
        Highlight(
            id: honeyChiliPorkChopsID,
            user_id: previewUserID,
            dish_name: "Honey Chili Pork Chops",
            location_type: "home",
            date_eaten: Date(timeIntervalSince1970: 1_776_988_800),
            tags: ["dinner", "spicy"],
            photo_path: nil,
            rating: 9.5,
            memoryNote: "Sticky glaze, a little heat, and rice on the side.",
            restaurantName: nil,
            formattedAddress: nil,
            latitude: nil,
            longitude: nil,
            occasion_id: nil,
            created_at: Date(timeIntervalSince1970: 1_776_988_800)
        ),
        Highlight(
            id: tunaSushiRollID,
            user_id: previewUserID,
            dish_name: "Tuna Sushi Roll",
            location_type: "restaurant",
            date_eaten: Date(timeIntervalSince1970: 1_774_310_400),
            tags: ["sushi", "lunch"],
            photo_path: nil,
            rating: 8,
            memoryNote: "Clean tuna flavor with a quick homemade roll.",
            restaurantName: "Tuna Sushi Bar",
            formattedAddress: "120 S Los Angeles St\nLos Angeles, CA 90012\nUnited States",
            latitude: 34.0496,
            longitude: -118.2427,
            occasion_id: nil,
            created_at: Date(timeIntervalSince1970: 1_774_310_400)
        )
    ]
}
#Preview("Home Light With Local Food Photos") {
    HomeView(
        previewHighlights: HomeView.previewHighlights,
        previewImageAssets: HomeView.previewImageAssets,
        previewOccasions: HomeView.previewOccasions,
        previewDishes: DishReference.previewCatalog
    )
    .environmentObject(AuthManager())
    .environmentObject(DishCatalogStore(previewDishes: DishReference.previewCatalog))
    .preferredColorScheme(.light)
}
#Preview("Home Dark With Local Food Photos") {
    HomeView(
        previewHighlights: HomeView.previewHighlights,
        previewImageAssets: HomeView.previewImageAssets,
        previewOccasions: HomeView.previewOccasions,
        previewDishes: DishReference.previewCatalog
    )
    .environmentObject(AuthManager())
    .environmentObject(DishCatalogStore(previewDishes: DishReference.previewCatalog))
    .preferredColorScheme(.dark)
}
#Preview("Dish Cards With Local Food Photos") {
    ScrollView {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 32
        ) {
            ForEach(Array(HomeView.previewHighlights.enumerated()), id: \.element.id) { index, highlight in
                HomeView.HighlightCard(
                    highlight: highlight,
                    rotationDegrees: index.isMultiple(of: 2) ? -2 : 2,
                    imageSource: HomeView.previewImageAssets[highlight.id]
                        .map(HomeView.HighlightImageSource.asset(name:)) ?? .placeholder
                )
            }
        }
        .padding(24)
    }
    .background(Color.backgroundPrimary)
}
