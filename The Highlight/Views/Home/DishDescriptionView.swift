import SwiftUI

struct DishDescriptionView: View {
    private let initialHighlight: Highlight //This is the dish that was tapped. It is a normal constant, not state, so DishDescriptionView does not directly mutate it.
    //Its most important long-term role is preserving the dish’s ID. Even after an edit, the ID remains the stable way to find the same database row.
    @Binding private var highlights: [Highlight] //It is a connection to the parent’s array.
    private let occasions: [Occasion]
    private let previewImageAssets: [UUID: String] //This maps preview highlight IDs to local Asset Catalog image names. This lets Xcode previews show local food images without contacting Supabase.
    var onSaveComplete: (() -> Void)? = nil //After an edit or deletion, run my refresh logic.
    var onDeleteComplete: (([Highlight]) -> Void)? = nil //It receives the updated highlight array. That allows Dishes or Map to inspect whether any dishes remain.

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    //Photo state: These control loading and displaying the dish image.
    @State private var photoURL: URL?
    @State private var loadedRemotePhotoPath: String?
    @State private var didFinishLoadingRemotePhoto = false
    @State private var isShowingExpandedPhoto = false
    //Delete state: These control the confirmation alert, loading spinner, button disabling, and error message.
    @State private var isShowingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String?
    //Refresh state: This stores a newly fetched copy of the dish after an edit.
    @State private var refreshedHighlight: Highlight?
    @State private var refreshedOccasions: [Occasion]? //optional newer copy fetched by this screen. Since it is optional, it has two states:
    //nil → this screen has not fetched a newer occasion list
    //[Occasion] → this screen has fetched and stored a newer list
    @State private var expandedMealHighlight: Highlight?
    @State private var selectedRelatedHighlight: Highlight?

    init(
        highlight: Highlight,
        highlights: Binding<[Highlight]> = .constant([]) /*constant([]) makes the view easier to preview or construct without a real parent binding. A constant binding can be read, but changes will not propagate to a real owner.*/,
        occasions: [Occasion] = [],
        previewImageAssets: [UUID: String] = [:],
        onSaveComplete: (() -> Void)? = nil,
        onDeleteComplete: (([Highlight]) -> Void)? = nil
    ) {
        self.initialHighlight = highlight
        self._highlights = highlights //Because highlights is wrapped in @Binding, the underlying property-wrapper storage is named _highlights. This line stores the binding connection itself.
        self.occasions = occasions
        self.previewImageAssets = previewImageAssets
        self.onSaveComplete = onSaveComplete
        self.onDeleteComplete = onDeleteComplete
    }

    private var theme: Theme {
        Theme(colorScheme: colorScheme) //The local Theme maps .light or .dark to page-specific colors:
    }

    private var highlight: Highlight { //three possible versions of the current highlight
        //First, look for the dish in the latest bound parent array.
        //If it is not found there, use the locally refreshed version.
        //If neither is available, use the original tapped value.
        highlights.first { $0.id == initialHighlight.id /*This searches the current parent array for the same UUID.*/} ?? refreshedHighlight ?? initialHighlight
        //refreshedHighlight: This is a fallback copy fetched directly by the description screen after editing. It is useful when the parent refresh has not completed yet or the parent callback behaves differently in previews.
            //initialHighlight: This guarantees that the screen always has something to display, even before any refresh occurs.
    }
    //the one Occasion belonging to the displayed Highlight
    private var currentOccasion: Occasion? {
        //current Highlight: read occasion_id, then search Occasion array for matching id
        guard let occasionID = highlight.occasion_id else { return nil }
        return currentOccasions.first { $0.id == occasionID }
    }

    private var relatedHighlights: [Highlight] {
        guard let occasionID = highlight.occasion_id else { return [] }
        return highlights
            .filter { $0.occasion_id == occasionID && $0.id != highlight.id } //same occasion and not the dish currently being viewed
            .sorted { first, second in
                (first.date_eaten ?? first.created_at) > (second.date_eaten ?? second.created_at)
            }
    }

    private var childPreviewOccasions: [Occasion]? {
        previewImageAssets.isEmpty ? nil : currentOccasions
    }
    ////whichever occasion array is currently preferred
    //When DishDescriptionView first opens, it receives an occasion array from its parent so refreshedOccasions == nil. Later, after editing a dish or changing its meal, the detail screen may fetch the latest occasions from Supabase and assign refreshedOccasions = fetchedOccasions.
    //The purpose is to let the detail screen update itself immediately without requiring the entire navigation hierarchy to disappear and be recreated.
    private var currentOccasions: [Occasion] {
        refreshedOccasions ?? occasions //The ?? operator means use the value on the left when it is not nil; otherwise use the value on the right.
    }

    private var isShowingRelatedHighlightGallery: Binding<Bool> {
        Binding(
            get: { expandedMealHighlight != nil },
            set: { isPresented in
                if !isPresented {
                    expandedMealHighlight = nil
                }
            }
        )
    }

    private var relatedMealGallerySelection: Binding<UUID> {
        Binding(
            get: {
                expandedMealHighlight?.id ?? relatedHighlights.first?.id ?? UUID()
            },
            set: { selectedID in
                expandedMealHighlight = relatedHighlights.first { $0.id == selectedID }
            }
        )
    }

    private var imageSource: HomeView.HighlightImageSource { //recall the enum itself is defined in HomeView.swift:
//    case remote(path: String)
//    case asset(name: String)
//    case placeholder
//    This enum lets the detail screen handle three fundamentally different image situations using one value.
        if let assetName = previewImageAssets[highlight.id] { //If an Xcode preview supplies an asset mapping, the local image is used.
            return .asset(name: assetName)
        }

        if let photoPath = highlight.photo_path { //the object path inside the private Supabase Storage bucket. The view must convert that path into a temporary signed URL.
            return .remote(path: photoPath)
        }

        return .placeholder //The screen renders a fallback image icon
    }

    private func imageSource(for relatedHighlight: Highlight) -> HomeView.HighlightImageSource {
        if let assetName = previewImageAssets[relatedHighlight.id] {
            return .asset(name: assetName)
        }

        if let photoPath = relatedHighlight.photo_path {
            return .remote(path: photoPath)
        }

        return .placeholder
    }

    var body: some View {
        //GeometryReader supplies information about the available screen size through proxy.size.height to calculate the photo height. It does not use GeometryReader to position every element manually. It mainly uses it to make the photo responsive.
        GeometryReader { proxy in
            ZStack { //The ZStack places the background behind the scrolling content. The background extends behind the safe area, while the ScrollView sits above it.
                theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) { //the screen is intentionally broken into smaller computed views and helper methods rather than placing everything directly in body
                        AppTopNavigationRow(
                            title: "DESCRIPTION",
                            leadingAction: { dismiss() }
                        )

                        photoSection(height: photoHeight(for: proxy.size.height))
                        dishSummarySection

                        if let capturedDateText {
                            Text(capturedDateText)
                                .appBodyFont(size: 14)
                                .foregroundColor(theme.secondaryText)
                        }

                        occasionSummarySection
                        dishDescriptorsSection
                        relatedDishesSection
                        memoryNoteSection
                        addAnotherDishFromMealButton
                        deleteSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
            }
        }
        .navigationBarBackButtonHidden(true) //The system navigation controls are hidden
        .toolbar(.hidden, for: .navigationBar)
        .task(id: imageSource) { //This means the task runs when the screen appears, and reruns when imageSource changes. That second behavior matters after editing
            await loadPhotoURL()
        }
        .fullScreenCover(isPresented: $isShowingExpandedPhoto) {
            expandedPhotoView
        }
        .fullScreenCover(isPresented: isShowingRelatedHighlightGallery) {
            relatedHighlightsGallery
        }
        .navigationDestination(item: $selectedRelatedHighlight) { relatedHighlight in
            //related dishes open another detail screen while preserving the shared highlight binding, the occasion list, preview image mappings, and save/delete callbacks.
            DishDescriptionView(
                highlight: relatedHighlight,
                highlights: $highlights,
                occasions: occasions,
                previewImageAssets: previewImageAssets,
                onSaveComplete: onSaveComplete,
                onDeleteComplete: onDeleteComplete
            )
        }
        .alert("Delete this dish?", isPresented: $isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { //Using role: .destructive tells SwiftUI this is a destructive action and gives it appropriate platform styling.
                Task { //The Task is needed because deleteDish() is asynchronous.
                    await deleteDish()
                }
            }
        } message: {
            Text("This removes the dish from your saved highlights.")
        }
    }

    private func photoSection(height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            if imageSource.hasImage { //for .asset and .remote, hasImage is true. For .placeholder, it is false.
                photoContent(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipped()
                    .background(theme.photoBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .onTapGesture {
                        isShowingExpandedPhoto = true //When the Boolean becomes true, SwiftUI presents the full-screen photo view.
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Expand photo")
            } else {
                photoContent(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .background(theme.photoBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

            NavigationLink { //This is where editing now begins. The current computed highlight is passed, not necessarily the old initialHighlight. That means if the detail screen has already refreshed once, a second edit starts with the newest values.
                AddDishView(
                    mode: .edit(highlight),
                    initialOccasion: currentOccasion,
                    previewOccasions: childPreviewOccasions,
                    onSaveComplete: handleEditSaveComplete
                )
                //the callback handleEditSaveComplete triggers two refresh routes. The parent refresh (from Home, this is refreshHighlightsAfterSave, which starts loadHighlights() and replaces Home’s array from Supabase) and
                //a local detail refresh await refreshHighlightAfterEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.editButtonForeground)
                    .frame(width: 38, height: 38)
                    .background(theme.editButtonBackground)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.16), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .padding(12)
            .accessibilityLabel("Edit dish")
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private var dishSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(highlight.dish_name)
                .appHeaderFont(size: 34)
                .foregroundColor(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            //rating
            Text("\(formattedRating) / 10")
                .appHeaderFont(size: 28)
                .foregroundColor(.accentPrimary)

            HStack(alignment: .top, spacing: 10) {
                Label(sourceTitle, systemImage: sourceIconName)
                    .font(AppTypography.font(.body, size: 14))
                    .foregroundColor(theme.primaryText)

                Text(locationText)
                    .appBodyFont(size: 14)
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder //@ViewBuilder allows SwiftUI’s result-builder system to interpret conditional view code. It turns the two conceptual branches into views:
    //currentOccasion exists → return the VStack
    //currentOccasion is nil → return EmptyView
    private var occasionSummarySection: some View {
        if let currentOccasion { //If currentOccasion is nil, @ViewBuilder produces no visible section.
            VStack(alignment: .leading, spacing: 10) {
                Text("Meal")
                    .appBodyBoldFont(size: 15)
                    .foregroundColor(theme.primaryText)

                Text(currentOccasion.displayTitle)
                    .appBodyFont(size: 15)
                    .foregroundColor(theme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dishDescriptorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This dish was...")
                .appBodyBoldFont(size: 15)
                .foregroundColor(theme.primaryText)

            if descriptorChips.isEmpty {
                Text("No descriptors selected")
                    .appBodyFont(size: 14)
                    .foregroundColor(theme.secondaryText)
            } else {
                HStack(spacing: 8) {
                    ForEach(descriptorChips) { chip in
                        Text(chip.rawValue)
                            .appBodyBoldFont(size: 12)
                            .foregroundColor(.textPrimary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(chip.color)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var relatedDishesSection: some View {
        if currentOccasion != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("Also from this meal")
                    .appBodyBoldFont(size: 15)
                    .foregroundColor(theme.primaryText)

                if relatedHighlights.isEmpty {
                    Text("No other dishes saved with this meal yet.")
                        .appBodyFont(size: 14)
                        .foregroundColor(theme.secondaryText)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(relatedHighlights) { relatedHighlight in
                                Button {
                                    expandedMealHighlight = relatedHighlight //Tapping a card does not immediately navigate. It first opens a full-screen gallery
                                } label: {
                                    RelatedMealDishCard(
                                        highlight: relatedHighlight,
                                        imageSource: imageSource(for: relatedHighlight),
                                        theme: theme
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var memoryNoteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This Highlight was...")
                .appBodyBoldFont(size: 15)
                .foregroundColor(theme.primaryText)

            Text(memoryNoteText)
                .appBodyFont(size: 15)
                .foregroundColor(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.noteBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var addAnotherDishFromMealButton: some View {
        if let currentOccasion {
            NavigationLink {
                AddDishView(
                    initialOccasion: currentOccasion,
                    previewOccasions: childPreviewOccasions,
                    onSaveComplete: onSaveComplete
                )
            } label: {
                Text("Add another dish from this meal")
                    .appBodyBoldFont(size: 14)
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.accentSecondary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                isShowingDeleteConfirmation = true //This bool controls .alert("Delete this dish?", isPresented: $isShowingDeleteConfirmation)
            } label: {
                HStack(spacing: 10) {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .bold))
                    }

                    Text(isDeleting ? "Deleting..." : "Delete Dish")
                        .appBodyBoldFont(size: 15)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.deleteButtonBackground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)

            if let deleteErrorMessage {
                Text(deleteErrorMessage)
                    .appBodyFont(size: 13)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 6)
    }

    private var expandedPhotoView: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            photoContent(contentMode: .fit) //The same image-loading function is reused, but .fit ensures the whole image is visible rather than cropped.
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { //can be closed on tap
                    isShowingExpandedPhoto = false
                }

            Button { //or through the x button
                isShowingExpandedPhoto = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.52))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .padding(.trailing, 18)
            .accessibilityLabel("Close photo")
        }
    }

    private var relatedHighlightsGallery: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if relatedHighlights.isEmpty {
                Text("No other dishes saved with this meal yet.")
                    .appBodyFont(size: 16)
                    .foregroundColor(.white)
                    .padding(24)
            } else {
                //The gallery uses a paged TabView and tags each page with the Highlight UUID. The initial selected page corresponds to the card that was tapped.
                TabView(selection: relatedMealGallerySelection) {
                    ForEach(relatedHighlights) { relatedHighlight in
                        relatedHighlightGalleryPage(relatedHighlight)
                            .tag(relatedHighlight.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: relatedHighlights.count > 1 ? .automatic : .never))
            }

            Button {
                expandedMealHighlight = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.52))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .padding(.trailing, 18)
            .accessibilityLabel("Close related dish")
        }
    }

    private func relatedHighlightGalleryPage(_ relatedHighlight: Highlight) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 28)

            RelatedMealImageView(
                imageSource: imageSource(for: relatedHighlight),
                contentMode: .fit,
                photoBackground: Color.black,
                fallbackIconColor: .white.opacity(0.72)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 10) {
                Text(relatedHighlight.dish_name)
                    .appHeaderFont(size: 28)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("\(formattedRating(for: relatedHighlight)) / 10")
                    .appHeaderFont(size: 24)
                    .foregroundColor(.accentPrimary)

                Button {
                    openRelatedDescription(relatedHighlight)
                } label: {
                    Text("View Dish")
                        .appBodyBoldFont(size: 15)
                        .foregroundColor(.backgroundDarkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
    }

    @ViewBuilder //photoContent uses @ViewBuilder because it returns different kinds of SwiftUI views depending on imageSource
        //A function returning some View normally needs to return one concrete underlying view type.
    // But these branches return different types: Image, AsyncImage, fallbackPhoto
    private func photoContent(contentMode: ContentMode) -> some View {
        //contentMode accepts either .fill for the normal card or .fit for the expanded view
        switch imageSource { //@ViewBuilder lets SwiftUI interpret conditional and switch-based view construction:
        case .asset(let name): //local asset, no asynchronous loading is needed.
            Image(name)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        case .remote: //verifies that the current source is remote,
            if case .remote(let path) = imageSource,
               loadedRemotePhotoPath == path, //the signed URL belongs to this exact path,
               let photoURL { //a URL was successfully produced.
                //phase is the argument passed into the closure by AsyncImage. It represents the current state of the image request.
                AsyncImage(url: photoURL) { phase in //AsyncImage downloads and renders it
                    switch phase { //The cases do not determine what gets passed into AsyncImage. They determine what your UI returns after AsyncImage reports its current state.
                    case .empty: //if loading is not finished
                        loadingPhoto //show loading UI
                    case .success(let image): //let image extracts the successfully loaded SwiftUI Image into a local constant image
                        image
                            .resizable() //and then we configure it
                            .aspectRatio(contentMode: contentMode)
                    case .failure: //If loading has finished but no usable URL is present.
                        fallbackPhoto
                    @unknown default: //This is defensive handling for any future AsyncImagePhase cases Apple might add. If SwiftUI introduces a phase this version of the code does not recognize, show the fallback rather than failing to compile or render unpredictably.
                        fallbackPhoto
                    }
                }
            } else if didFinishLoadingRemotePhoto { //didFinishLoadingRemotePhoto distinguishes not finished yet to finished but failed in obtaining the signedURL
                fallbackPhoto //finished but failed
            } else {
                loadingPhoto //not finished yet
            }
        case .placeholder:
            fallbackPhoto
        }
    }

    private var loadingPhoto: some View {
        Rectangle()
            .fill(theme.photoBackground)
            .overlay {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentPrimary))
            }
    }

    private var fallbackPhoto: some View {
        Rectangle()
            .fill(theme.photoBackground)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(theme.secondaryText)
            }
    }

    private func photoHeight(for availableHeight: CGFloat) -> CGFloat {
        min(max(availableHeight * 0.34, 270), 360) //The intended target is 34% of the available height, but it is constrained to a minimum of 270 and maximum of 360
        //This prevents the image from becoming too short on small screens or excessively tall on large ones.
    }
    //converts ratings into clean whole or half values
    private var formattedRating: String {
        formattedRating(for: highlight)
    }

    private func formattedRating(for highlight: Highlight) -> String {
        let halfStepRating = Int((highlight.rating * 2).rounded())
        if halfStepRating.isMultiple(of: 2) {
            return "\(halfStepRating / 2)" //avoids displaying 9.0 when 9 is sufficient, for example
        }
        return "\(halfStepRating / 2).5"
    }

    private func openRelatedDescription(_ relatedHighlight: Highlight) {
        expandedMealHighlight = nil //It dismisses the gallery first

        Task { @MainActor in
            await Task.yield() //yields one UI cycle
            selectedRelatedHighlight = relatedHighlight //sets the navigation item
        }
    }

    private var sourceTitle: String {
        //Any non-restaurant value defaults visually to Home.
        //highlight.location_type.lowercased() reads the stored value and compares it to "restaurant"
        //If the condition is true, use "Restaurant", otherwise use "Home"
        highlight.location_type.lowercased() == "restaurant" ? "Restaurant" : "Home"
    }

    private var sourceIconName: String {
        highlight.location_type.lowercased() == "restaurant" ? "fork.knife" : "house.fill"
    }

    private var locationText: String {
        //Restaurant name is considered more concise and user-friendly, so it is preferred over the full address.
        if let restaurantName = highlight.restaurantName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !restaurantName.isEmpty {
            return "Location: \(restaurantName)"
        }

        if let formattedAddress = highlight.formattedAddress?.trimmingCharacters(in: .whitespacesAndNewlines),
           !formattedAddress.isEmpty {
            //Newline-separated addresses are converted to comma-separated text
            return "Location: \(formattedAddress.replacingOccurrences(of: "\n", with: ", "))"
        }

        return "Location: none"
    }

    private var capturedDateText: String? {
        guard let date = highlight.date_eaten else { return nil }
        return "Captured \(date.formatted(.dateTime.month(.wide).day().year()))"
    }
    //The database model stores chips as strings, while AddDishView formats them as Chips. This converts them.
    private var descriptorChips: [AddDishView.Chip] {
        //This preserves the chip colors defined in AddDishView.Chip. For every stored string, it searches all known chip cases.
        highlight.tags.compactMap { tag in //Because it uses compactMap, unknown strings are dropped. That avoids a crash if old database data contains a descriptor no longer supported by the app.
            AddDishView.Chip.allCases.first {
                //The comparison is case-insensitive
                $0.rawValue.localizedCaseInsensitiveCompare(tag) == .orderedSame
            }
        }
    }

    private var memoryNoteText: String {
        guard let memoryNote = highlight.memoryNote?.trimmingCharacters(in: .whitespacesAndNewlines),
              !memoryNote.isEmpty else {
            return "No memory note saved."
        }

        return memoryNote
    }

    @MainActor
    private func loadPhotoURL() async {
        photoURL = nil //First it resets previous state
        loadedRemotePhotoPath = nil //This prevents an old image URL from being accidentally displayed while a new one is loading.
        didFinishLoadingRemotePhoto = false
        //checks the source, only a .remote case needs a network request. Local assets and placeholders do not need signed URLs.
        guard case .remote(let path) = imageSource else {
            didFinishLoadingRemotePhoto = true
            return
        }

        photoURL = try? await HighlightService.shared.signedURL(for: path) //The bucket is private, so this generates a temporary permission-bearing URL for one file.
        loadedRemotePhotoPath = path //The view later checks that the URL belongs to the currently requested path.
        //This prevents a timing issue if imageSource changes but the old path finishes loading late.
        //The code only displays photoURL when loadedRemotePhotoPath == path
        didFinishLoadingRemotePhoto = true
    }

    private func handleEditSaveComplete() {
        onSaveComplete?() //calling parent refresh

        Task {
            await refreshHighlightAfterEdit() //local refresh
        }
    }

    @MainActor
    private func refreshHighlightAfterEdit() async {
        //Fetches all current rows, writes them through the parent binding
        guard let updatedHighlights = try? await HighlightService.shared.fetchHighlights() else {
            return
        }

        if previewImageAssets.isEmpty {
            refreshedOccasions = try? await OccasionService.shared.fetchOccasions()
        }
        highlights = updatedHighlights
        //finds the one currently being displayed, and stores that row locally as a fallback. $0 means the current array element being examined.
        refreshedHighlight = updatedHighlights.first { $0.id == initialHighlight.id } //first is used because updatedHighlights is an array, but the screen only needs the one highlight whose ID matches the dish currently being viewed.
        //For an array, this form array.first { condition } searches from the beginning and return the first element that satisfies the condition.
    }

    @MainActor
    private func deleteDish() async {
        guard !isDeleting else { return } //This prevents duplicate requests if the user somehow triggers deletion multiple times.
        //The UI reacts by disabling the button, showing a spinner, and changing the title to “Deleting...”.
        isDeleting = true
        deleteErrorMessage = nil
        
        do {
            try await HighlightService.shared.deleteHighlight(highlight) //service call
            let updatedHighlights = try await fetchHighlightsAfterDelete()
            highlights = updatedHighlights //parent binding is updated, updates the original array owned by Home.
            refreshedHighlight = nil
            onSaveComplete?()
            dismiss() //When the last dish is deleted, DishDescriptionView dismisses itself first.

            if updatedHighlights.isEmpty { //Was the deleted dish the final dish? Then DishesView or MapView may also dismiss, because there is nothing left for that screen to show.
                Task { @MainActor in //This schedules the following UI work on the main actor.
                    await Task.yield() //temporarily gives SwiftUI a chance to process the first dismiss(). It lets other pending work run first.
                    onDeleteComplete?(updatedHighlights) //callback passed through in MapView and DishesView
                    // optinal callback syntax ?() means call it only if a callback was provided.
                }
            }
        } catch {
            deleteErrorMessage = "Unable to delete dish: \(error.localizedDescription)"
            isDeleting = false
        }
    }

    @MainActor //because it reads UI-related properties such as highlights, previewImageAssets, and initialHighlight, and its result is immediately used to update SwiftUI state
    //decides how to get the updated highlight list after a deletion, depending on whether the screen is running with preview data or real Supabase data.
    private func fetchHighlightsAfterDelete() async throws -> [Highlight] {
        if !previewImageAssets.isEmpty { //the screen is showing local preview data -- in normal app use, this is empty [:]. In previews, it maps highlight UUID → local image asset name
            return highlights.filter { $0.id != initialHighlight.id } //creates a new array containing every highlight except the deleted one
        }

        return try await HighlightService.shared.fetchHighlights() //asks Supabase for the user’s current highlight rows. Because the dish was just deleted, the returned array should no longer include it.
    }

    private struct RelatedMealDishCard: View {
        let highlight: Highlight
        let imageSource: HomeView.HighlightImageSource
        let theme: Theme

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                RelatedMealImageView(
                    imageSource: imageSource,
                    contentMode: .fill,
                    photoBackground: theme.photoBackground,
                    fallbackIconColor: theme.secondaryText
                )
                .frame(width: 144, height: 116)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(highlight.dish_name)
                    .appBodyBoldFont(size: 13)
                    .foregroundColor(theme.primaryText)
                    .lineLimit(2)
            }
            .frame(width: 144, alignment: .leading)
        }
    }

    private struct RelatedMealImageView: View {
        let imageSource: HomeView.HighlightImageSource
        let contentMode: ContentMode
        let photoBackground: Color
        let fallbackIconColor: Color

        @State private var photoURL: URL?
        @State private var loadedRemotePhotoPath: String?
        @State private var didFinishLoadingRemotePhoto = false

        var body: some View {
            Group {
                switch imageSource {
                case .asset(let name):
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                case .remote:
                    if case .remote(let path) = imageSource,
                       loadedRemotePhotoPath == path,
                       let photoURL {
                        AsyncImage(url: photoURL) { phase in
                            switch phase {
                            case .empty:
                                loadingPhoto
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: contentMode)
                            case .failure:
                                fallbackPhoto
                            @unknown default:
                                fallbackPhoto
                            }
                        }
                    } else if didFinishLoadingRemotePhoto {
                        fallbackPhoto
                    } else {
                        loadingPhoto
                    }
                case .placeholder:
                    fallbackPhoto
                }
            }
            .task(id: imageSource) {
                await loadPhotoURL()
            }
        }

        private var loadingPhoto: some View {
            Rectangle()
                .fill(photoBackground)
                .overlay {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentPrimary))
                }
        }

        private var fallbackPhoto: some View {
            Rectangle()
                .fill(photoBackground)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(fallbackIconColor)
                }
        }

        @MainActor
        private func loadPhotoURL() async {
            photoURL = nil
            loadedRemotePhotoPath = nil
            didFinishLoadingRemotePhoto = false

            guard case .remote(let path) = imageSource else {
                didFinishLoadingRemotePhoto = true
                return
            }

            photoURL = try? await HighlightService.shared.signedURL(for: path)
            loadedRemotePhotoPath = path
            didFinishLoadingRemotePhoto = true
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

        var secondaryText: Color {
            primaryText.opacity(0.72)
        }

        var photoBackground: Color {
            isDark ? .textPrimary : Color.accentSecondary.opacity(0.35)
        }

        var noteBackground: Color {
            isDark ? .textPrimary : .containerPrimary
        }

        var editButtonBackground: Color {
            isDark ? Color.backgroundDarkPrimary.opacity(0.88) : Color.backgroundPrimary.opacity(0.92)
        }

        var editButtonForeground: Color {
            isDark ? .backgroundPrimary : .textPrimary
        }

        var deleteButtonBackground: Color {
            isDark ? .textPrimary : .containerPrimary
        }
    }
}

#Preview("Dish Description") {
    NavigationStack {
        DishDescriptionView(
            highlight: HomeView.previewHighlights[2],
            highlights: .constant(HomeView.previewHighlights),
            occasions: HomeView.previewOccasions,
            previewImageAssets: HomeView.previewImageAssets
        )
    }
}

#Preview("Dish Description With Meal") {
    NavigationStack {
        DishDescriptionView(
            highlight: HomeView.previewHighlights[0],
            highlights: .constant(HomeView.previewHighlights),
            occasions: HomeView.previewOccasions,
            previewImageAssets: HomeView.previewImageAssets
        )
    }
}

#Preview("Dish Description Dark") {
    NavigationStack {
        DishDescriptionView(
            highlight: HomeView.previewHighlights[2],
            highlights: .constant(HomeView.previewHighlights),
            occasions: HomeView.previewOccasions,
            previewImageAssets: HomeView.previewImageAssets
        )
    }
    .preferredColorScheme(.dark)
}
