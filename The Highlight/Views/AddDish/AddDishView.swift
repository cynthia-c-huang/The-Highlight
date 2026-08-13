import SwiftUI
import PhotosUI

struct AddDishView: View {
    enum Mode { //supports two modes, create or edit. Callers who omit mode default to create
        case create
        case edit(Highlight) //The .edit case contains an associated value: the complete highlight being edited.

        var title: String {
            switch self {
            case .create: return "ADD DISH"
            case .edit: return "EDIT DISH" //title changes based on add/edit mode
            }
        }

        var saveButtonTitle: String {
            switch self {
            case .create: return "Save highlight"
            case .edit: return "Save changes" //save button changes based on add/edit mode
            }
        }

        var saveButtonIcon: String {
            switch self {
            case .create: return "heart.fill"
            case .edit: return "sparkles"
            }
        }
    }

    enum Context: String, CaseIterable { //The database stores lowercase strings, but the UI uses enum cases
        case home = "Home"
        case restaurant = "Restaurant"

        var databaseValue: String {
            rawValue.lowercased()
        }

        static func fromDatabaseValue(_ value: String) -> Context {
            allCases.first { $0.databaseValue == value.lowercased() } ?? .home
        }
    }

    enum Chip: String, CaseIterable, Identifiable {
        case salty = "Salty", sweet = "Sweet", spicy = "Spicy", tangy = "Tangy", smoky = "Smoky", umami = "Umami", buttery = "Buttery", refreshing = "Refreshing", crispy = "Crispy", tender = "Tender", fluffy = "Fluffy", chewy = "Chewy", dense = "Dense", airy = "Airy", creamy = "Creamy", flaky = "Flaky"
        var id: String { rawValue }
        var color: Color {
            Color.descriptionTagBackground(for: rawValue)
        }
    }

    let isFirstTime: Bool
    let mode: Mode
    private let initialOccasion: Occasion? //the occasion that should be initially selected
    private let initialDishReference: DishReference?
    private let previewOccasions: [Occasion]?
    private let shouldLoadRemoteOccasions: Bool
    private let initiallySelectedOccasionID: UUID?
    var onSaveComplete: (() -> Void)? = nil
    //The form’s initial @State values are also defined directly in the view. These properties are the form’s temporary working memory, meaning it contains what the user has typed, but it is not yet stored in Supabase.
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    //These survive while AddDishView stays alive
    @State private var dishName: String = "" //declares managed state
    @State private var selectedContext: Context = .home
    @State private var selectedDate: Date? = nil
    @State private var selectedRating: Double? = nil //is just the current slider selection until the user saves.
    @State private var memoryNote: String = ""
    @State private var showDatePicker: Bool = false
    @State private var selectedChips: Set<Chip> = [] //UI stores descriptor chips as a set to avoid duplicates
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var existingPhotoURL: URL? = nil //temporary URL needed only for displaying the image
    @State private var isExistingPhotoRemoved: Bool = false
    @State private var selectedLocation: DishLocation? = nil
    @State private var availableOccasions: [Occasion] = [] //the list displayed as recent meal chips
    @State private var selectedOccasionID: UUID? = nil //the current form selection that will be saved
    @State private var selectedDishReferenceID: UUID? = nil
    @State private var isLoadingOccasions = false
    @State private var occasionError: String? = nil
    @State private var newOccasionTitle = ""
    @State private var newOccasionDate = Date()
    @State private var newOccasionUsesDate = false
    @State private var newOccasionLocation: DishLocation? = nil
    @State private var newOccasionError: String? = nil
    @State private var isCreatingOccasion = false
    @State private var occasionToDelete: Occasion?
    @State private var isDeletingOccasion = false
    @State private var deleteOccasionError: String? = nil
    //If a user creates a new meal, never saves a dish, and closes AddDishView, then without cleanup, Supabase would contain an empty occasion.
    @State private var sessionCreatedOccasionIDs: Set<UUID> = [] //Occasions created while this form was open
    @State private var sessionSavedOccasionIDs: Set<UUID> = [] //Occasions that were actually attached to a dish that saved successfully. Together, the code later checks if any occasions were created and unused, then deletes those from Supabase.
    //These determine which secondary UI is visible
    @State private var isShowingDateSheet: Bool = false
    @State private var isShowingLocationSearch: Bool = false
    @State private var isShowingMapPicker: Bool = false
    @State private var isShowingNewOccasionSheet = false
    @State private var isShowingSavedMealDialog = false
    @State private var scrollToTopRequest = 0

    @State private var isSaving: Bool = false
    @State private var saveError: String? = nil

    private static let formTopID = "AddDishFormTop"

    init(
        isFirstTime: Bool = false,
        mode: Mode = .create,
        initialOccasion: Occasion? = nil,
        initialDishReference: DishReference? = nil,
        previewOccasions: [Occasion]? = nil,
        onSaveComplete: (() -> Void)? = nil
    ) {
        self.isFirstTime = isFirstTime
        self.mode = mode
        self.initialOccasion = initialOccasion
        self.initialDishReference = initialDishReference
        self.previewOccasions = previewOccasions
        self.shouldLoadRemoteOccasions = previewOccasions == nil
        //The purpose of startingOccasionID is to determine which meal chip should appear selected when the form first opens
        let startingOccasionID = Self.initialSelectedOccasionID(for: mode, initialOccasion: initialOccasion)
        self.initiallySelectedOccasionID = startingOccasionID
        self.onSaveComplete = onSaveComplete
        let startingOccasions = Self.mergedOccasions(
            previewOccasions ?? [],
            initialOccasion: initialOccasion,
            pinnedOccasionID: startingOccasionID //The “pinned” ID likely tells mergedOccasions to make sure this selected meal remains in the displayed list, even if it would not otherwise appear among the recent meals.
                //That matters in edit mode. An old dish may belong to an old occasion that is not among the eight newest meals
        )
        _availableOccasions = State(initialValue: startingOccasions)

        if case .edit(let highlight) = mode { //If mode is the .edit case, extract its associated Highlight into a local constant named highlight.
            //Then it initializes each @State property using the existing row
            _dishName = State(initialValue: highlight.dish_name) //_ syntax refers to the underlying State<String> property wrapper, or the SwiftUI State container holding that value. This line initializes the wrapper.
            _selectedContext = State(initialValue: Context.fromDatabaseValue(highlight.location_type)) /*Its implementation searches the known cases and converts to the lowercase “home” or “restaurant” the database expects, and it defaults to .home if the value is unrecognized. */
            _selectedDate = State(initialValue: highlight.date_eaten)
            _selectedRating = State(initialValue: highlight.rating)
            _memoryNote = State(initialValue: highlight.memoryNote ?? "")
            _selectedLocation = State(initialValue: highlight.dishLocation)
            //The underscore is necessary because the initializer is configuring the State wrapper itself rather than assigning to the wrapped state after initialization.
            _selectedOccasionID = State(initialValue: highlight.occasion_id)
            _selectedDishReferenceID = State(initialValue: highlight.dishReferenceID)
            /*The database model contains [String], but the UI uses Set<Chip>, so highlight.tags.compactMap(...) converts every string into an enum Chip case. compactMap drops strings that no longer correspond to a valid Chip. That means old or unexpected database data does not crash the form; it simply will not appear selected. */
            _selectedChips = State(initialValue: Set(highlight.tags.compactMap(Chip.init(rawValue:))))
        } else {
            if let initialDishReference {
                _dishName = State(initialValue: initialDishReference.name)
                _selectedDishReferenceID = State(initialValue: initialDishReference.id)
            }

            if let initialOccasion { //prefill behavior: When a user taps “Add another dish from this meal,” the next form inherits the same occasion, date, location, and restaurant context.
                _selectedOccasionID = State(initialValue: initialOccasion.id)
                _selectedDate = State(initialValue: initialOccasion.date)
                _selectedLocation = State(initialValue: initialOccasion.dishLocation)
                if initialOccasion.restaurantName != nil || initialOccasion.formattedAddress != nil {
                    _selectedContext = State(initialValue: .restaurant)
                }
            }
        }
    }

    private var theme: AddDishTheme {
        AddDishTheme(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            ScrollViewReader { scrollProxy in
                ScrollView {
                VStack(spacing: 16) {
                // Top Nav Row
                AppTopNavigationRow(
                    title: mode.title,
                    leadingAction: { dismiss() }
                )
                .id(Self.formTopID)
                .padding(.horizontal)

                // Photo Upload Card
                photoUploadCard //calls a view

                // Dish Name Field
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Dish name", isRequiredIncomplete: dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    HStack {
                        TextField("Spicy miso carbonara", text: $dishName) //In edit mode, this still works as normal
                            .font(AppTypography.font(.body, size: 16))
                            .foregroundColor(theme.primaryText)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                    }
                    .background(theme.fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // Segmented Row
                HStack(spacing: 8) {
                    ForEach(Context.allCases, id: \.self) { ctx in
                        PillButton(title: ctx.rawValue, isSelected: selectedContext == ctx, selectedColor: .surfacePrimary) {
                            selectedContext = ctx
                        }
                    }
                    Button {
                        isShowingDateSheet = true
                    } label: {
                        if let date = selectedDate {
                            PillButtonContent(title: formattedDate(date), isSelected: false, selectedColor: .surfacePrimary, icon: "calendar")
                        } else {
                            PillButtonContent(title: "Select Date", isSelected: false, selectedColor: .surfacePrimary, icon: "calendar")
                        }
                    }
                }
                .padding(.horizontal)
                    /*A binding means the child location UI can mutate the selectedLocation state owned by AddDishView. If a user searches or chooses a map point, the state becomes a new DishLocation. If they remove the location, selectedLocation = nil */
                DishLocationSection(
                    selectedLocation: $selectedLocation,
                    isSearchVisible: $isShowingLocationSearch,
                    onChooseMap: { isShowingMapPicker = true } /*onChooseMap is a closure passed down from AddDishView into DishLocationSection. Its job is simply to tell AddDishView that the user wants to open the map picker now.*/
                )
                .padding(.horizontal)

                occasionSection
                    .padding(.horizontal)

                // Rating Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        sectionLabel("Rating", isRequiredIncomplete: selectedRating == nil)

                        Spacer()

                        if let selectedRating {
                            Text(formatRating(selectedRating))
                                .appHeaderFont(size: 24)
                                .foregroundColor(theme.primaryText)
                        }
                    }
                    //the slider visually begins around 5.0, but selectedRating can still remain nil until the user interacts with it.
                    Slider(
                        value: Binding(
                            get: { selectedRating ?? 5.0 },
                            set: { selectedRating = roundedRating($0) }
                        ),
                        in: 1.0...10.0,
                        step: 0.5
                    )
                    .tint(.accentPrimary)

                    HStack {
                        Text("1")
                        Spacer()
                        Text("10")
                    }
                    .appBodyFont(size: 11)
                    .foregroundColor(theme.secondaryText)
                }
                .padding(.vertical)
                .background(theme.sectionBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Description/Chips Section
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("Dish description (choose 3)")
                    Wrap(chips: Chip.allCases, selected: $selectedChips, maxSelection: 3)
                }
                .padding(.vertical)
                .background(theme.sectionBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Memory Note Field
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Memory note")

                    TextEditor(text: $memoryNote)
                        .font(AppTypography.font(.body, size: 15))
                        .foregroundColor(theme.primaryText)
                        .frame(minHeight: 88)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(theme.fieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // Save Button
                Button(action: {
                    Task {
                        await saveHighlight() //Task creates an asynchronous context so the code may use await
                    }
                }) {
                    HStack {
                        if isSaving { //button changes appearance while saving
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .accentPrimary))
                        } else {
                            Image(systemName: mode.saveButtonIcon)
                                .foregroundColor(.accentPrimary)
                        }
                        Text(mode.saveButtonTitle)
                            .appBodyFont(size: 16)
                            .foregroundColor(.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                    //The Save button is disabled when selectedRating == nil, preventing normal button taps without a rating and when it is currently saving
                .disabled(isSaving || selectedRating == nil)
                .opacity(selectedRating == nil ? 0.6 : 1)
                .padding(.horizontal)

                if let error = saveError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                }
                .padding(.top, 12)
                .padding(.bottom, 24)
                }
                .onChange(of: scrollToTopRequest) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scrollProxy.scrollTo(Self.formTopID, anchor: .top)
                    }
                }
            //The sheet is created by AddDishView, but the actual state lives in the parent selectedDate, When the sheet
            //disappears, SwiftUI removes the sheet content, but AddDishView is still alive, so selectedDate remains stored.
            //That is why the date pill can show the chosen date after the sheet closes.
            .sheet(isPresented: $isShowingDateSheet) { //Present a sheet whenever isShowingDateSheet is true, and remove it when that value becomes false. The $ passes a Binding<Bool>, so the sheet system can both read and update that state.
                VStack(spacing: 12) { //the sheet contains a Date picker and actions
                    Text("Select a date")
                        .appBodyFont(size: 16)
                        .foregroundColor(theme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    //So before the user chooses anything, the calendar visually opens to today.
                    //The date picker binds directly to AddDishView’s state. The date is therefore stored in the parent AddDishView, not inside a separate date-picker view.
                    DatePicker("", selection: Binding(get: { selectedDate ?? Date() /*@State private var selectedDate: Date? = nil is a Date?, not a Date. The optional exists because “no date selected yet” is a valid form state. the getter returns: selectedDate if one exists or the current date if selectedDate is nil*/ }, set: { selectedDate = $0 } /*When the user selects a date, the picker supplies that date as $0, which is shorthand for the first closure argument.*/), displayedComponents: .date) //tells the picker to show only calendar-date components, not time.
                        .datePickerStyle(.graphical) //uses the large calendar-style interface rather than a wheel or compact field.
                        .labelsHidden()
                        .tint(.accentPrimary)
                        .foregroundColor(theme.primaryText)
                        .padding(.horizontal)

                    Button { isShowingDateSheet = false } label: { //the sheet disappears, but selectedDate remains because AddDishView still owns it.
                        Text("Done")
                            .appBodyBoldFont(size: 15)
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.surfacePrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    Button {
                        selectedDate = nil
                        isShowingDateSheet = false
                    } label: {
                        Text("Delete Date")
                            .appBodyBoldFont(size: 15)
                            .foregroundColor(.red.opacity(selectedDate == nil ? 0.45 : 0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedDate == nil)
                    .padding(.horizontal)
                }
                .padding(.vertical, 18)
                .background(theme.background)
                .presentationDetents([.medium, .large]) //This tells SwiftUI the sheet can rest at two heights: .medium or .large. The user can usually drag the sheet between them.
            }
            .sheet(isPresented: $isShowingMapPicker) {
                //When this sheet appears, use MapLocationPickerView as its contents.
                MapLocationPickerView(initialLocation: selectedLocation) { location in //If AddDish already has a location, the picker starts with it.
                    selectedLocation = location
                    isShowingLocationSearch = false
                }
            }
            .sheet(isPresented: $isShowingNewOccasionSheet) {
                newOccasionSheet
            }
            .sheet(isPresented: $isShowingSavedMealDialog) {
                savedMealSheet //The form itself is reused rather than pushing another AddDishView onto the navigation stack.
            }
            .alert("Delete this meal?", isPresented: isShowingDeleteOccasionConfirmation) {
                Button("Cancel", role: .cancel) {
                    occasionToDelete = nil //That makes the Boolean binding false, so the alert disappears.
                }
                Button("Delete Meal", role: .destructive) {
                    let occasion = occasionToDelete //The code first copies the optional state. The copy is useful because the alert may dismiss and alter occasionToDelete. The local constant preserves the occasion chosen by the user.
                    Task {
                        if let occasion {
                            await deleteOccasion(occasion)
                        }
                    }
                }
            } message: {
                Text("This removes the meal grouping only. The dishes stay saved.")
            }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadExistingPhotoIfNeeded() //in edit mode, this loads the remote image
            await loadOccasionsIfNeeded()
        }
        .task(id: selectedPhoto) { //This task watches for changes to that PhotoPickerItem
            guard let item = selectedPhoto else { return } //reference to the Photos library selection
            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                selectedImage = img //decoded local UI image the app can preview and later compress
            }
        }
        .onDisappear {
            cleanupUnusedCreatedOccasions()
        }
    }

    private func sectionLabel(_ title: String, isRequiredIncomplete: Bool = false) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .appBodyFont(size: 14)
                .foregroundColor(theme.primaryText)

            if isRequiredIncomplete {
                Image(systemName: "sparkle")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.red)
                    .accessibilityLabel("Required")
            }
        }
    }

    private var photoUploadCard: some View {
        ZStack(alignment: .topTrailing) { //layers the photo picker/card and the x button above it in the top-right corner
            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                photoCardContent
            }
            .buttonStyle(.plain)

            if canRemovePhoto { //The x button is only added when canRemovePhoto is true.
                removePhotoButton
            }
        }
        .padding(.horizontal)
    }

    private var photoCardContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.photoBackground)
            if let image = selectedImage { // Show new local image
                GeometryReader { proxy in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            } else if !isExistingPhotoRemoved, let existingPhotoURL { // Show old remote image
                AsyncImage(url: existingPhotoURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .success(let image):
                        GeometryReader { proxy in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                        }
                    case .failure:
                        photoFallbackIcon
                    @unknown default:
                        photoFallbackIcon
                    }
                }
            } else {
                photoPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    private var photoPlaceholder: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.placeholderIconBackground)
                    .frame(width: 48, height: 48)
                Image(systemName: "camera")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }
            Text("Add the delicious proof")
                .appBodyFont(size: 16)
                .foregroundColor(theme.primaryText)
            Text("Upload a photo or keep it as a memory note.")
                .appBodyFont(size: 12)
                .foregroundColor(theme.secondaryText)
        }
        .padding(20)
    }

    private var photoFallbackIcon: some View {
        Image(systemName: "photo")
            .font(.system(size: 28, weight: .semibold))
            .foregroundColor(theme.secondaryText)
    }

    private var removePhotoButton: some View {
        Button(action: removeCurrentPhoto) { //Tapping it calls removeCurrentPhoto()
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(theme.primaryText)
                .frame(width: 32, height: 32)
                .background(theme.removeButtonBackground)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.14), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .padding(10)
        .accessibilityLabel("Remove photo")
    }

    private var occasionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("Meal or occasion")

                Spacer()

                if isLoadingOccasions {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text("Recent meals")
                .appBodyFont(size: 12)
                .foregroundColor(theme.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    newOccasionButton

                    ForEach(recentOccasions) { occasion in
                        occasionOption(occasion) //Each option containsthe meal selection button and a small delete button
                    }
                }
                .padding(.vertical, 2)
            }

            if recentOccasions.isEmpty, !isLoadingOccasions, occasionError == nil {
                Text("No recent meals yet. Create one to group this dish.")
                    .appBodyFont(size: 12)
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let occasionError {
                Text(occasionError)
                    .appBodyFont(size: 12)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let deleteOccasionError {
                Text(deleteOccasionError)
                    .appBodyFont(size: 12)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical)
        .background(theme.sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var savedMealSheet: some View {
        VStack(spacing: 14) {
            Button {
                resetForAnotherDishFromMeal() //does NOT reset selectedOccasionID, selectedDate, selectedLocation, selectedContext, and availableOccasions. Therefore, dish-specific state resets, but meal-shared state remains
            } label: {
                Text("Add another dish from this meal")
                    .appBodyBoldFont(size: 15)
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentSecondary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .appBodyBoldFont(size: 15)
                    .foregroundColor(theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.fieldBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(theme.background)
        .presentationDetents([.height(170)])
        .interactiveDismissDisabled()
    }
    //button formatting for each meal
    private func occasionOptionButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .appBodyFont(size: 13)
                .fontWeight(.bold)
                .lineLimit(1)
                .foregroundColor(isSelected ? theme.occasionSelectedText : theme.primaryText)
                .padding(.vertical, 9)
                .padding(.horizontal, 13)
                .frame(minHeight: 38)
                .background(isSelected ? theme.occasionSelectedBackground : theme.occasionActionBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.occasionStrokeColor(isSelected: isSelected), lineWidth: isSelected ? 1.8 : 1.2)
                }
        }
        .buttonStyle(.plain)
    }

    private var newOccasionButton: some View {
        Button {
            prepareNewOccasionSheet()
            isShowingNewOccasionSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text("New meal")
                    .appBodyFont(size: 13)
                    .fontWeight(.bold)
            }
            .foregroundColor(.textPrimary)
            .padding(.vertical, 9)
            .padding(.horizontal, 13)
            .frame(minHeight: 38)
            .background(theme.occasionActionBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.accentSecondary, lineWidth: 1.2)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 7)
        .padding(.trailing, 7)
    }

    private func occasionOption(_ occasion: Occasion) -> some View {
        ZStack(alignment: .topTrailing) {
            occasionOptionButton(
                title: occasion.displayTitle,
                isSelected: selectedOccasionID == occasion.id
            ) {
                selectOccasion(occasion)
            }
            .padding(.top, 7)
            .padding(.trailing, 7)

            Button {
                occasionToDelete = occasion //The alert’s presentation binding is derived from that optional
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(theme.primaryText)
                    .frame(width: 18, height: 18)
                    .background(theme.removeButtonBackground)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.accentSecondary, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(isDeletingOccasion)
            .accessibilityLabel("Delete meal")
        }
    }

    private var newOccasionSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meal title")
                            .appBodyFont(size: 14)
                            .foregroundColor(theme.primaryText)

                        TextField("Birthday dinner", text: $newOccasionTitle)
                            .appBodyFont(size: 15)
                            .foregroundColor(theme.primaryText)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 13)
                            .background(theme.fieldBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Toggle(isOn: $newOccasionUsesDate) {
                        Text("Use a meal date")
                            .appBodyFont(size: 14)
                            .foregroundColor(theme.primaryText)
                    }
                    .tint(.accentPrimary)

                    if newOccasionUsesDate {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                sectionLabel("Meal date")

                                Spacer()

                                Text(formattedDate(newOccasionDate))
                                    .appBodyFont(size: 14)
                                    .foregroundColor(theme.primaryText)
                            }

                            DatePicker(
                                "",
                                selection: $newOccasionDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .tint(.accentPrimary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .appBodyFont(size: 14)
                            .foregroundColor(theme.primaryText)

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.accentSecondary)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(newOccasionLocation?.displayName ?? "No meal location")
                                    .appBodyFont(size: 14)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.primaryText)

                                if let newOccasionLocationDetailText {
                                    Text(newOccasionLocationDetailText)
                                        .appBodyFont(size: 12)
                                        .foregroundColor(theme.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.fieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        HStack(spacing: 10) {
                            Button("Use dish location") {
                                newOccasionLocation = selectedLocation
                            }
                            .disabled(selectedLocation == nil)

                            Button("Clear") {
                                newOccasionLocation = nil
                            }
                            .disabled(newOccasionLocation == nil)
                        }
                        .appBodyFont(size: 13)
                        .foregroundColor(.accentPrimary)
                    }

                    if let newOccasionError {
                        Text(newOccasionError)
                            .appBodyFont(size: 13)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(24)
            }
            .background(theme.background)
            .navigationTitle("New meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isShowingNewOccasionSheet = false
                    } label: {
                        Text("Cancel")
                            .appBodyFont(size: 15)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await createOccasion()
                        }
                    } label: {
                        if isCreatingOccasion {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Create")
                                .appBodyFont(size: 15)
                        }
                    }
                    .disabled(isCreatingOccasion)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var existingPhotoPath: String? { //checks whether the form is editing an existing Highlight. It is a stable identifier needed for deletion
        //If so, it retrieves that row’s permanent Storage path (NOT signed URL). In create mode, there is no preexisting highlight or photo, so it returns nil.
        if case .edit(let highlight) = mode {
            return highlight.photo_path
        }

        return nil
    }

    private var canRemovePhoto: Bool { //A newly selected image exists or an existing database photo still exists
        selectedImage != nil || (!isExistingPhotoRemoved && existingPhotoPath != nil) //existingPhotoPath is a computed property that checks whether the form is editing an existing Highlight.
    }

    private var recentOccasions: [Occasion] {
        Array(availableOccasions.prefix(8)) //limits the horizontal list to eight items.
    }

    private var newOccasionLocationDetailText: String? {
        guard let newOccasionLocation else {
            return "Use the dish location before creating a meal."
        }

        if newOccasionLocation.restaurantName != nil {
            return nil
        }

        return newOccasionLocation.displayAddress
    }

    private var isCreateMode: Bool {
        if case .create = mode {
            return true
        }

        return false
    }
    //static means it belongs to the AddDishView type itself, not to one already-created view instance.
    private static func initialSelectedOccasionID(for mode: Mode, initialOccasion: Occasion?) -> UUID? {
        //edit mode uses the dish’s currently stored occasion relationship.
        if case .edit(let highlight) = mode { //The .edit case contains an associated Highlight .edit(highlight), so this is pattern matching
            return highlight.occasion_id //If mode is the .edit case, extract the associated Highlight and call it highlight, then return the occasion id
        }

        return initialOccasion?.id //in create mode, an initial occasion may or may not be supplied
    }
    //mergedOccasions returns all unique occasions passed to it, plus initialOccasion when that occasion was not already present.
    private static func mergedOccasions(
        _ occasions: [Occasion],
        initialOccasion: Occasion?,
        pinnedOccasionID: UUID? = nil
    ) -> [Occasion] {
        var merged = [Occasion]()
        var seenIDs = Set<UUID>()

        if let pinnedOccasionID { //The pinned occasion is the occasion that should be kept at the beginning of the list, usually because it starts selected.
            let pinnedOccasion = initialOccasion?.id == pinnedOccasionID
                ? initialOccasion //This prioritizes the already-provided full object when it is the correct one, avoiding an unnecessary search.
                : occasions.first { $0.id == pinnedOccasionID }

            if let pinnedOccasion { //Put the selected/pinned occasion first, if it can find it.
                merged.append(pinnedOccasion)
                seenIDs.insert(pinnedOccasion.id)
            }
        }

        if let initialOccasion { //Include initialOccasion, even if it was not in the supplied array.
            if !seenIDs.contains(initialOccasion.id) {
                merged.append(initialOccasion)
                seenIDs.insert(initialOccasion.id)
            }
        }

        for occasion in occasions where !seenIDs.contains(occasion.id) { //Add all remaining occasions, avoiding duplicate IDs
            merged.append(occasion)
            seenIDs.insert(occasion.id)
        }

        return merged
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func roundedRating(_ value: Double) -> Double {
        min(max((value * 2).rounded() / 2, 1.0), 10.0)
    }

    private func formatRating(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func normalizedMemoryNote() -> String? {
        let trimmedNote = memoryNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNote.isEmpty ? nil : trimmedNote
    }

    private func selectOccasion(_ occasion: Occasion) {
        if selectedOccasionID == occasion.id {
            selectedOccasionID = nil //unselect the current occassion
            return
        }

        selectedOccasionID = occasion.id //Tapping a different meal simply replaces the ID

        guard isCreateMode else { return } //In create mode, meal metadata can conveniently fill blank date and location fields. In edit mode, changing the meal should not unexpectedly overwrite the dish’s existing values, only the occasionID.
        //Only filling empty values respects values the user already entered.
        if selectedDate == nil {
            selectedDate = occasion.date //set the current date to the occasion's date
        }
        
        if selectedLocation == nil, let location = occasion.dishLocation {
            selectedLocation = location //set the location and context to the occasion's
            selectedContext = .restaurant
        }
    }
    //since occasionToDelete is not a bool, but an Occasion?, we must create a computed binding.
    //That is preferable to keeping two potentially inconsistent variables such as:
    //@State var isShowingAlert = false
    //@State var occasionToDelete: Occasion?
    //With two variables, you could accidentally have isShowingAlert = true and occasionToDelete = nil
    //The current design prevents that mismatch.
    private var isShowingDeleteOccasionConfirmation: Binding<Bool> {
        Binding(
            get: { occasionToDelete != nil }, //if occasionToDelete contains an Occasion, then this is true → show alert
            //if occasionToDelete is nil, this is false → hide alert
            //SwiftUI may set the alert binding back to false when the alert closes.
            set: { isPresented in
                if !isPresented {
                    occasionToDelete = nil //This clears the stored deletion target.
                }
            }
        )
    }

    @MainActor
    private func deleteOccasion(_ occasion: Occasion) async {
        guard !isDeletingOccasion else { return } //Prevent duplicate deletion requests

        isDeletingOccasion = true //The x buttons are disabled: .disabled(isDeletingOccasion)
        deleteOccasionError = nil //Clear any old error

        do {
            if shouldLoadRemoteOccasions { //Check whether this is real app data or preview data
                try await OccasionService.shared.deleteOccasion(id: occasion.id)
                onSaveComplete?()
            }
            //In preview modee, it skips Supabase and only changes the local preview array.
            availableOccasions.removeAll { $0.id == occasion.id } //Because it is @State, SwiftUI redraws the recent-meal chips
            if selectedOccasionID == occasion.id { //This only runs when the deleted meal was currently selected.
                selectedOccasionID = nil //clear the current selection
            }
            //Remove it from session-tracking sets. If a meal was created during this session and deleted, this bookkeeping prevents cleanupUnusedCreatedOccasions() from attempting to delete the meal again when the view disappears.
            sessionCreatedOccasionIDs.remove(occasion.id)
            sessionSavedOccasionIDs.remove(occasion.id)
            //Clear the alert target and loading state
            occasionToDelete = nil
            isDeletingOccasion = false
        } catch {
            deleteOccasionError = "Unable to delete meal: \(error.localizedDescription)"
            occasionToDelete = nil
            isDeletingOccasion = false
        }
    }
    //This preloads the new meal form from the current dish (date & location)
    private func prepareNewOccasionSheet() {
        newOccasionTitle = ""
        newOccasionDate = selectedDate ?? Date()
        newOccasionUsesDate = selectedDate != nil
        newOccasionLocation = selectedLocation
        newOccasionError = nil
    }

    @MainActor
    private func loadOccasionsIfNeeded() async {
        guard shouldLoadRemoteOccasions else { return } //The guard keeps previews offline, where shouldLoadRemoteOccasions is set with self.shouldLoadRemoteOccasions = previewOccasions == nil in the initializer

        isLoadingOccasions = true
        occasionError = nil

        do {
            let fetchedOccasions = try await OccasionService.shared.fetchOccasions()
            //mergedOccasions ensures that an initially selected occasion remains available and likely pinned even if it is not among the latest fetched entries.
            availableOccasions = Self.mergedOccasions(
                fetchedOccasions,
                initialOccasion: initialOccasion,
                pinnedOccasionID: initiallySelectedOccasionID
            )
        } catch {
            occasionError = "Meals could not be loaded."
        }

        isLoadingOccasions = false
    }

    @MainActor
    private func createOccasion() async {
        guard !isCreatingOccasion else { return }

        isCreatingOccasion = true
        newOccasionError = nil

        let trimmedTitle = newOccasionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = OccasionSaveParams(
            title: trimmedTitle.isEmpty ? nil : trimmedTitle,
            date: newOccasionUsesDate ? newOccasionDate : nil,
            restaurantName: newOccasionLocation?.restaurantName,
            formattedAddress: newOccasionLocation?.formattedAddress,
            latitude: newOccasionLocation?.latitude,
            longitude: newOccasionLocation?.longitude
        )
        
        do {
            let occasion: Occasion
            if shouldLoadRemoteOccasions { //Then it chooses real or preview creation
                occasion = try await OccasionService.shared.createOccasion(params: params)
                sessionCreatedOccasionIDs.insert(occasion.id)
            } else {
                occasion = previewOccasion(params: params)
            }

            availableOccasions = Self.mergedOccasions(
                [occasion] + availableOccasions,
                initialOccasion: initialOccasion,
                pinnedOccasionID: initiallySelectedOccasionID
            )
            selectOccasion(occasion)
            isShowingNewOccasionSheet = false
        } catch {
            newOccasionError = error.localizedDescription
        }

        isCreatingOccasion = false
    }

    private func previewOccasion(params: OccasionSaveParams) -> Occasion {
        Occasion(
            id: UUID(),
            user_id: HomeView.previewUserID,
            title: params.title,
            date: params.date,
            restaurantName: params.restaurantName,
            formattedAddress: params.formattedAddress,
            latitude: params.latitude,
            longitude: params.longitude,
            created_at: Date()
        )
    }

    private func cleanupUnusedCreatedOccasions() {
        guard shouldLoadRemoteOccasions else { return }
        //extracts the unused occasions that have no highlights attached
        let unusedOccasionIDs = sessionCreatedOccasionIDs.subtracting(sessionSavedOccasionIDs)
        guard !unusedOccasionIDs.isEmpty else { return }

        Task {
            for occasionID in unusedOccasionIDs { //The service checks whether any dishes reference the occasion before deleting it
                try? await OccasionService.shared.deleteOccasionIfUnused(id: occasionID)
            }
        }
    }

    private func removeCurrentPhoto() {
        if selectedImage != nil { //This applies when the user has just selected a replacement or new image.
            selectedPhoto = nil //the PhotosPicker selection
            selectedImage = nil //the decoded UIImage shown in the form
            //Because the image was not uploaded yet, there is nothing to delete from Supabase.
            //In edit mode, because isExistingPhotoRemoved is still false, the original remote photo can appear again.
        } else if existingPhotoPath != nil { //This applies when no new local image is currently selected, but the edited highlight has an existing Storage path.
            isExistingPhotoRemoved = true //records that Save should remove the old object.
            existingPhotoURL = nil //removes the temporary display URL from the UI.
        }
    }

    @MainActor
    //the form must be in edit mode and the existing highlight must have a photo path.
    private func loadExistingPhotoIfNeeded() async {
        guard case .edit(let highlight) = mode, let path = highlight.photo_path, !isExistingPhotoRemoved else {
            return
        }

        let signedURL = try? await HighlightService.shared.signedURL(for: path)//requests a signedURL
        if !isExistingPhotoRemoved {
            existingPhotoURL = signedURL
        }
    }

    private func saveHighlight() async {
        //This removes spaces and line breaks from the beginning and end.
        let trimmedName = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            saveError = "Dish name cannot be empty."
            return
        }

        guard let selectedRating else { //the function still validates the rating again after the save button is disabled
            saveError = "Rating is required."
            return
        }

        isSaving = true //displays the spinner and disables the button
        saveError = nil//removes any error from a previous attempt
 
        // Prepare image data and extension
        /*Supabase Storage needs bytes, represented by Data. Even if the original selection was PNG or HEIC, this code converts the selected image into JPEG before upload.*/
        var imageData: Data? = nil
        var imageExt: String? = nil
        if let img = selectedImage { //A replacement image is prepared only when one was selected, so in edit mode, if none was selected, the existing remote photo is not redownloaded, recompressed, and reuploaded.
            if let jpegData = img.jpegData(compressionQuality: 0.85) { //is a value between 0-1  balancing image quality and file size.
                imageData = jpegData
                imageExt = "jpg"
            }
        }

        let tags = selectedChips.map(\.rawValue) //transforms the selected enum cases into Strings because the database expects [String]
        /*form data is assembled into one value. SaveParams acts as a package containing everything the service needs. Instead of passing 12 separate arguments, the view constructs one structured value.*/
        //params captures the form’s new desired state. It does not represent only changed fields. For text, dates, tags, rating, and location, it includes the entire current form state. The image is the exception: it includes image bytes only when a new photo was selected.

        do {
            let savedOccasionID = selectedOccasionID
            let params = SaveParams(
                dishName: trimmedName,
                locationType: selectedContext.databaseValue,
                dateEaten: selectedDate,
                tags: tags,
                rating: selectedRating,
                memoryNote: normalizedMemoryNote() /*trims whitespace and returns nil if the note is empty or the trimmed note otherwise*/,
                restaurantName: selectedLocation?.restaurantName /*If selectedLocation exists, retrieve its restaurant name. Otherwise produce nil. That allows location to remain optional.*/,
                formattedAddress: selectedLocation?.formattedAddress,
                latitude: selectedLocation?.latitude,
                longitude: selectedLocation?.longitude,
                dishReferenceID: selectedDishReferenceID,
                occasionID: savedOccasionID,
                imageData: imageData,
                imageFileExtension: imageExt,
                removesExistingPhoto: isExistingPhotoRemoved //AddDishView does not directly delete from Storage. It packages the instruction to do so
            )

            switch mode { //The same view supports both operations
            case .create:
                try await HighlightService.shared.saveHighlight(params: params) //This is where responsibility moves from the UI layer to the service layer.
            case .edit(let highlight):
                try await HighlightService.shared.updateHighlight(highlight, params: params) //In edit mode, the service receives both the original Highlight, which contains its row ID and existing photo path, and the new SaveParams, which contains the form’s edited values.
            }

            if let savedOccasionID { //This records that the newly created occasion was actually used by a saved dish
                sessionSavedOccasionIDs.insert(savedOccasionID) //sessionSavedOccasionIDs tracks which occasions were actually used by a successfully saved dish during the current AddDishView session
                updateAvailableOccasion(id: savedOccasionID, date: selectedDate)
            }
            onSaveComplete?() //calls the optional callback passed from HomeView, refreshHighlightsAfterSave(), which starts an asynchronous task to call loadHighlights()
            if isCreateMode, savedOccasionID != nil {
                isSaving = false
                isShowingSavedMealDialog = true //Instead of dismissing immediately, the form presents "add another dish from this meal"
            } else {
                dismiss() //closes the current navigation destination and return to the previous screen. Notice the reload task is started before dismissal.
            }
        } catch { //if any operation throws (fails), the screen remains open, displays the error, and re-enables the Save button.
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    private func resetForAnotherDishFromMeal() {
        dishName = ""
        selectedDishReferenceID = nil
        selectedRating = nil
        selectedChips = []
        memoryNote = ""
        selectedPhoto = nil
        selectedImage = nil
        existingPhotoURL = nil
        isExistingPhotoRemoved = false
        saveError = nil
        isSaving = false
        isShowingSavedMealDialog = false
        scrollToTopRequest += 1 //after resetting, the form scrolls back to the dish-name field
    }

    private func updateAvailableOccasion(id: UUID, date: Date?) {
        availableOccasions = availableOccasions.map { occasion in
            guard occasion.id == id else { return occasion }
            var updatedOccasion = occasion
            updatedOccasion.date = date
            return updatedOccasion
        }
    }

    private struct AddDishTheme {
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

        var sectionBackground: Color {
            background
        }

        var fieldBackground: Color {
            isDark ? .textPrimary : .containerPrimary
        }

        var occasionActionBackground: Color {
            isDark ? Color.accentSecondary.opacity(0.82) : Color.accentSecondary.opacity(0.44)
        }

        var occasionSelectedBackground: Color {
            isDark ? .backgroundDarkPrimary : .accentSecondary
        }

        var occasionSelectedText: Color {
            isDark ? .accentSecondary : .textPrimary
        }

        func occasionStrokeColor(isSelected: Bool) -> Color {
            isSelected ? .accentSecondary : .accentSecondary
        }

        var photoBackground: Color {
            isDark ? .textPrimary : Color.accentSecondary.opacity(0.35)
        }

        var placeholderIconBackground: Color {
            isDark ? Color.backgroundDarkPrimary.opacity(0.82) : .backgroundPrimary
        }

        var removeButtonBackground: Color {
            isDark ? .textPrimary : Color.backgroundPrimary.opacity(0.92)
        }
    }
}
// MARK: - Reusable Components

private struct PillButton: View {
    let title: String
    var isSelected: Bool
    var selectedColor: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            PillButtonContent(title: title, isSelected: isSelected, selectedColor: selectedColor)
        }
    }
}

private struct PillButtonContent: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var isSelected: Bool
    var selectedColor: Color
    var icon: String? = nil

    private var theme: PillTheme {
        PillTheme(colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon) }
            Text(title).appBodyFont(size: 12)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? selectedColor : theme.unselectedBackground)
        .clipShape(Capsule())
        .foregroundColor(isSelected ? .textPrimary : theme.primaryText)
    }

    private struct PillTheme {
        let colorScheme: ColorScheme

        var primaryText: Color {
            colorScheme == .dark ? .backgroundPrimary : .textPrimary
        }

        var unselectedBackground: Color {
            colorScheme == .dark ? .textPrimary : .containerPrimary
        }
    }
}

private struct Wrap: View {
    @Environment(\.colorScheme) private var colorScheme

    let chips: [AddDishView.Chip]
    @Binding var selected: Set<AddDishView.Chip>
    var maxSelection: Int

    private var theme: ChipTheme {
        ChipTheme(colorScheme: colorScheme)
    }

    var body: some View {
        FlexibleView(data: chips, spacing: 8, alignment: .leading) { chip in
            let isSelected = selected.contains(chip)
            Button {
                if isSelected {
                    selected.remove(chip)
                } else if selected.count < maxSelection {
                    selected.insert(chip)
                }
            } label: {
                Text(chip.rawValue)
                    .appBodyFont(size: 12)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(isSelected ? chip.color : theme.unselectedBackground)
                    .clipShape(Capsule())
                    .overlay {
                        if colorScheme == .dark {
                            Capsule()
                                .stroke(chip.color, lineWidth: isSelected ? 1.8 : 1)
                        }
                    }
                    .foregroundColor(isSelected ? .textPrimary : theme.primaryText)
            }
        }
    }

    private struct ChipTheme {
        let colorScheme: ColorScheme

        var primaryText: Color {
            colorScheme == .dark ? .backgroundPrimary : .textPrimary
        }

        var unselectedBackground: Color {
            colorScheme == .dark ? Color.backgroundDarkPrimary.opacity(0.72) : .containerPrimary
        }
    }
}

private struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable, Data.Element: Identifiable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    init(data: Data, spacing: CGFloat = 8, alignment: HorizontalAlignment = .leading, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return GeometryReader { geometry in
            ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
                ForEach(Array(data), id: \.self) { item in
                    content(item)
                        .padding(.all, 4)
                        .alignmentGuide(.leading, computeValue: { d in
                            if abs(width - d.width) > geometry.size.width {
                                width = 0
                                height -= d.height
                            }
                            let result = width
                            if item.id == data.first?.id { width = 0 } else { width -= d.width }
                            return result
                        })
                        .alignmentGuide(.top, computeValue: { _ in
                            let result = height
                            if item.id == data.first?.id { height = 0 }
                            return result
                        })
                }
            }
        }
        .frame(height: 160)
    }
}

#Preview {
    AddDishView()
}

#Preview("Add Dish Existing Meal") {
    AddDishView(
        initialOccasion: HomeView.previewOccasions.first,
        previewOccasions: HomeView.previewOccasions
    )
}
#Preview("Add Dish From Catalog") {
    AddDishView(
        initialDishReference: DishReference.previewCatalog[0],
        previewOccasions: HomeView.previewOccasions
    )
}
