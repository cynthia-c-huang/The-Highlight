import MapKit
import SwiftUI

struct MapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Binding private var highlights: [Highlight] //Because MapView.highlights is a @Binding, MapView cannot create its own value for it. It needs the parent to supply the connection: MapView(highlights: $highlights, onSaveComplete: refreshHighlightsAfterSave)
    @State private var dishesSheetPosition: LocatedDishesSheetPosition = .collapsed
    @State private var visibleHighlightIDs: Set<UUID>? = nil
    @GestureState private var dishesSheetDragOffset: CGFloat = 0

    private let occasions: [Occasion]
    private let previewImageAssets: [UUID: String]
    var onSaveComplete: (() -> Void)? = nil
    //the initializer receives the binding: highlights: Binding<[Highlight]> is the connection supplied by Home.
    init(
        highlights: Binding<[Highlight]>,
        occasions: [Occasion] = [],
        previewImageAssets: [UUID: String] = [:],
        onSaveComplete: (() -> Void)? = nil
    ) {
        //V the binding object
        _highlights = highlights
        //              ^ the actual array value supplied by Home
        self.occasions = occasions
        self.previewImageAssets = previewImageAssets
        self.onSaveComplete = onSaveComplete
    }

    private var theme: Theme {
        Theme(colorScheme: colorScheme)
    }

    //Highlights that contain a complete, valid coordinate pair and are safe to display on the map.
    private var locatedHighlights: [Highlight] {
        highlights.filter { highlight in //a pinned location requires both coordinate fields
            guard let latitude = highlight.latitude,
                  let longitude = highlight.longitude else {
                return false
            }
            //checks valid ranges for geographic coordinates: latitude:  -90 through 90 and longitude: -180 through 180
            return (-90...90).contains(latitude) && (-180...180).contains(longitude)
        }
    }

    private var visibleLocatedHighlights: [Highlight] {
        guard let visibleHighlightIDs else {
            return locatedHighlights
        }

        return locatedHighlights.filter { visibleHighlightIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                AppTopNavigationRow(
                    title: "MAP",
                    leadingAction: { dismiss() }
                )
                .padding(.horizontal, 24)
                .padding(.top, 18)

                if locatedHighlights.isEmpty { //If filtering produces no located dishes
                    emptyState //MapView shows its empty-state UI instead of an empty map.
                } else { //When locatedHighlights is not empty, the same filtered array powers the map pins and the Located Dishes list
                    locatedMapContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var locatedMapContent: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                HighlightLocationsMapView(
                    highlights: locatedHighlights,
                    imageSourcesByHighlightID: imageSourcesByHighlightID,
                    visibleHighlightIDs: $visibleHighlightIDs,
                    colorScheme: colorScheme
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                locatedDishesSheet(availableHeight: proxy.size.height)
            }
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func locatedDishesSheet(availableHeight: CGFloat) -> some View {
        let sheetHeight = min(max(availableHeight * 0.6, 270), 430)
        let collapsedVisibleHeight: CGFloat = 76
        let collapsedOffset = max(sheetHeight - collapsedVisibleHeight, 0)
        let restingOffset = dishesSheetPosition == .expanded ? 0 : collapsedOffset
        let proposedOffset = restingOffset + dishesSheetDragOffset
        let clampedOffset = min(max(proposedOffset, 0), collapsedOffset)
        let dragGesture = DragGesture()
            .updating($dishesSheetDragOffset) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let shouldCollapse = value.translation.height > 45 || value.predictedEndTranslation.height > 90
                let shouldExpand = value.translation.height < -45 || value.predictedEndTranslation.height < -90

                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                    if shouldCollapse {
                        dishesSheetPosition = .collapsed
                    } else if shouldExpand {
                        dishesSheetPosition = .expanded
                    } else {
                        dishesSheetPosition = clampedOffset > collapsedOffset / 2 ? .collapsed : .expanded
                    }
                }
            }

        return VStack(spacing: 0) {
            VStack(spacing: 10) {
                Capsule()
                    .fill(theme.handle)
                    .frame(width: 46, height: 5)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        dishesSheetPosition = dishesSheetPosition == .expanded ? .collapsed : .expanded
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("Located Dishes")
                            .appHeaderFont(size: 26)
                            .foregroundColor(theme.primaryText)

                        Text("\(visibleLocatedHighlights.count)")
                            .font(AppTypography.font(.bodyBold, size: 13))
                            .foregroundColor(.white)
                            .frame(minWidth: 24, minHeight: 24)
                            .padding(.horizontal, 4)
                            .background(Color.accentPrimary)
                            .clipShape(Capsule())

                        Spacer()

                        Image(systemName: dishesSheetPosition == .expanded ? "chevron.down" : "chevron.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.secondaryText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            .gesture(dragGesture)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if visibleLocatedHighlights.isEmpty {
                        noVisibleDishesRow
                    } else {
                        ForEach(visibleLocatedHighlights) { highlight in
                            NavigationLink {
                                DishDescriptionView(
                                    highlight: highlight,
                                    highlights: $highlights,
                                    occasions: occasions,
                                    previewImageAssets: previewImageAssets,
                                    onSaveComplete: onSaveComplete,
                                    onDeleteComplete: handleDeleteComplete //if deleting dishes yields no more highlights
                                )
                            } label: {
                                locatedDishRow(highlight)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: sheetHeight, alignment: .top)
        .background(theme.sheetBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: -4)
        .offset(y: clampedOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: dishesSheetPosition)
    }
    //The function receives the updated array. If dishes remain, the function returns and MapView stays open.
    private func handleDeleteComplete(_ updatedHighlights: [Highlight]) {
        guard updatedHighlights.isEmpty else { return } //Continue only when the array is empty. Otherwise, exit immediately.
        dismiss()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "map")
                .font(.system(size: 42, weight: .semibold))
                .foregroundColor(.accentPrimary)

            Text("No dish locations yet")
                .appHeaderFont(size: 28)
                .foregroundColor(theme.primaryText)

            Text("Add a restaurant or pinned map spot while creating or editing a dish, and it will appear here.")
                .font(AppTypography.font(.body, size: 15))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func locatedDishRow(_ highlight: Highlight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.accentPrimary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text(highlight.dish_name)
                    .font(AppTypography.font(.bodyBold, size: 17))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(2)

                if let restaurantName = highlight.restaurantName, !restaurantName.isEmpty {
                    Text(restaurantName)
                        .font(AppTypography.font(.bodyBold, size: 13))
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                }

                if let formattedAddress = highlight.formattedAddress, !formattedAddress.isEmpty {
                    Text(formattedAddress)
                        .font(AppTypography.font(.body, size: 12))
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.secondaryText.opacity(0.8))
                .padding(.top, 6)
        }
        .padding(14)
        .background(theme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var noVisibleDishesRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.accentPrimary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text("No dishes in this map area")
                    .font(AppTypography.font(.bodyBold, size: 17))
                    .foregroundColor(theme.primaryText)

                Text("Move or zoom the map to show dishes here.")
                    .font(AppTypography.font(.body, size: 13))
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(theme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var imageSourcesByHighlightID: [UUID: HomeView.HighlightImageSource] {
        Dictionary(uniqueKeysWithValues: locatedHighlights.map { highlight in
            (highlight.id, imageSource(for: highlight))
        })
    }

    private func imageSource(for highlight: Highlight) -> HomeView.HighlightImageSource {
        if let assetName = previewImageAssets[highlight.id] {
            return .asset(name: assetName)
        }

        if let photoPath = highlight.photo_path {
            return .remote(path: photoPath)
        }

        return .placeholder
    }

    private enum LocatedDishesSheetPosition {
        case collapsed
        case expanded
    }

    private struct Theme {
        let colorScheme: ColorScheme

        private var isDark: Bool {
            colorScheme == .dark
        }

        var background: Color {
            isDark ? .backgroundDarkPrimary : .backgroundPrimary
        }

        var sheetBackground: Color {
            isDark ? .backgroundDarkPrimary : .backgroundPrimary
        }

        var rowBackground: Color {
            isDark ? .textPrimary : .containerPrimary
        }

        var primaryText: Color {
            isDark ? .backgroundPrimary : .textPrimary
        }

        var secondaryText: Color {
            primaryText.opacity(0.7)
        }

        var handle: Color {
            primaryText.opacity(0.22)
        }
    }
}

private struct HighlightAnnotationSnapshot: Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let title: String
    let subtitle: String?
    let imageSource: HomeView.HighlightImageSource

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

//wraps a UIKit MKMapView for use inside SwiftUI
private struct HighlightLocationsMapView: UIViewRepresentable {
    let highlights: [Highlight]
    let imageSourcesByHighlightID: [UUID: HomeView.HighlightImageSource]
    @Binding var visibleHighlightIDs: Set<UUID>?
    let colorScheme: ColorScheme
    //creates and configures the UIKit map
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        mapView.delegate = context.coordinator //MKMapView calls func mapVIew() automatically through its delegate system.
        mapView.showsCompass = true
        mapView.showsScale = true
        return mapView
    }
    //synchronizes the map whenever the bound highlights change
    //Because Map receives Home’s binding, when Home refetches, Home.highlights changes, MapView reevaluates
    //HighlightLocationsMapView receives new locatedHighlights, and SwiftUI calls updateUIView
    //That is how saving an edit can eventually update the map pins.
    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        mapView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let annotationSnapshots = highlights.compactMap { highlight -> HighlightAnnotationSnapshot? in
            guard let latitude = highlight.latitude, //f either coordinate is missing, that highlight does not produce an annotation. Although MapView already passes locatedHighlights, this guard provides another layer of protection inside the representable.
                  let longitude = highlight.longitude else {
                return nil
            }

            return HighlightAnnotationSnapshot(
                id: highlight.id,
                latitude: latitude,
                longitude: longitude,
                title: highlight.dish_name,
                subtitle: highlight.restaurantName ?? highlight.formattedAddress,
                imageSource: imageSourcesByHighlightID[highlight.id] ?? .placeholder
            )
        }

        guard annotationSnapshots != context.coordinator.renderedAnnotationSnapshots else { return }
        context.coordinator.renderedAnnotationSnapshots = annotationSnapshots
        //SwiftUI gives it the existing MKMapView. So updateUIView is not making a brand-new map. It receives the existing map and synchronizes its contents with the latest SwiftUI data.
        context.coordinator.highlightsByAnnotationID = [:] //clears the coordinator’s old lookup table, this dictionary associates annotation IDs with highlights
        mapView.removeAnnotations(mapView.annotations) //removes old annotations first. If the code only added new annotations, the map might retain obsolete pins if a user deleted a location/dish. Before rebuilding the annotations, the old relationships are discarded.

        //transforms each highlight into an annotation, compactMap visits every Highlight
        //For each one, it either returns a HighlightAnnotation, or returns nil, causing that highlight to be skipped
        let highlightsByID = Dictionary(uniqueKeysWithValues: highlights.map { ($0.id, $0) })
        let annotations = annotationSnapshots.map { snapshot -> HighlightAnnotation in
            let annotation = HighlightAnnotation(
                id: snapshot.id,
                imageSource: snapshot.imageSource
            )
            annotation.coordinate = snapshot.coordinate
            annotation.title = snapshot.title
            annotation.subtitle = snapshot.subtitle
            context.coordinator.highlightsByAnnotationID[annotation.id] = highlightsByID[snapshot.id] //records the annotation-to-highlight relationship
            return annotation
        } //compactMap returns the complete new array [HighlightAnnotation]

        mapView.addAnnotations(annotations) //adds the whole array to the map
        setVisibleRegion(for: annotations, on: mapView) //changes the map’s viewport so the annotations are visible.
        context.coordinator.updateVisibleHighlightIDs(in: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func setVisibleRegion(for annotations: [HighlightAnnotation], on mapView: MKMapView) {
        guard let first = annotations.first else { return }

        guard annotations.count > 1 else { //With one annotation, there is no geographic spread to calculate
            mapView.setRegion(
                MKCoordinateRegion(
                    center: first.coordinate,
                    //This ensures the map is reasonably zoomed around the single dish rather than zooming extremely close or showing the entire world.
                    span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                ),
                animated: false
            )
            return
        }
        //for displaying multiple annotations, the code creates or combines an MKMapRect containing each coordinate.
        //It expands the rectangle to include each annotation coordinate
        let mapRect = annotations.reduce(MKMapRect.null) { partialResult, annotation in
            let point = MKMapPoint(annotation.coordinate)
            let rect = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
            return partialResult.union(rect)
        }
        //display that rect with padding. The edge padding prevents pins from touching or hiding underneath the map’s borders.
        mapView.setVisibleMapRect(
            mapRect,
            edgePadding: UIEdgeInsets(top: 80, left: 60, bottom: 170, right: 60),
            animated: false
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: HighlightLocationsMapView
        var highlightsByAnnotationID: [UUID: Highlight] = [:]
        var renderedAnnotationSnapshots: [HighlightAnnotationSnapshot] = []

        init(parent: HighlightLocationsMapView) {
            self.parent = parent
        }

        //MapKit then processes each annotation and asks the coordinator for its visual annotation view
        //This function is called after annotations are added: mapView.addAnnotations(annotations)
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            //                                  ^ the specific annotation that currently needs a visual marker.
            guard annotation is HighlightAnnotation else { return nil } //custom styling should apply only to annotations representing highlights.

            let identifier = "HighlightLocation"
            //MapKit reuses annotation views for efficiency. Instead of creating a brand-new marker every time, it first checks if there's already an unused marker view with this identifier
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? HighlightPinAnnotationView
                //if not, it creates a new one
                ?? HighlightPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView.configure(with: annotation)
            return annotationView
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            updateVisibleHighlightIDs(in: mapView)
        }

        func updateVisibleHighlightIDs(in mapView: MKMapView) {
            let visibleMapRect = mapView.visibleMapRect
            let ids = Set(
                highlightsByAnnotationID.compactMap { id, highlight -> UUID? in
                    guard let latitude = highlight.latitude,
                          let longitude = highlight.longitude else {
                        return nil
                    }

                    let point = MKMapPoint(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                    return visibleMapRect.contains(point) ? id : nil
                }
            )

            guard parent.visibleHighlightIDs != ids else { return }

            Task { @MainActor in
                guard self.parent.visibleHighlightIDs != ids else { return }
                self.parent.visibleHighlightIDs = ids
            }
        }
    }
}
//custom annotation class that associates an annotation with a particular Highlight
//The annotation is the data object for a map pin.
//That can become useful if tapping a pin later needs to identify the exact highlight
//open its edit screen, show its photo, display its rating, or navigate to detail
//An ordinary MKPointAnnotation only carries generic map information unless you maintain some separate lookup.
private final class HighlightAnnotation: MKPointAnnotation {
    let id: UUID
    let imageSource: HomeView.HighlightImageSource

    init(id: UUID, imageSource: HomeView.HighlightImageSource) {
        self.id = id
        self.imageSource = imageSource
        super.init()
    }
}

private final class HighlightPinAnnotationView: MKAnnotationView {
    private var hostingController: UIHostingController<HighlightMapPinView>?

    func configure(with annotation: MKAnnotation) {
        self.annotation = annotation
        canShowCallout = true
        backgroundColor = .clear
        clipsToBounds = false

        guard let highlightAnnotation = annotation as? HighlightAnnotation else { return }

        let pinSize = highlightAnnotation.imageSource.hasImage
            ? HighlightMapPinView.photoPinSize
            : HighlightMapPinView.compactPinSize

        bounds = CGRect(origin: .zero, size: pinSize)
        centerOffset = CGPoint(x: 0, y: -pinSize.height / 2)

        let pinView = HighlightMapPinView(imageSource: highlightAnnotation.imageSource)
        if let hostingController {
            hostingController.rootView = pinView
        } else {
            let hostingController = UIHostingController(rootView: pinView)
            hostingController.view.backgroundColor = .clear
            hostingController.view.isUserInteractionEnabled = false
            hostingController.view.clipsToBounds = false
            addSubview(hostingController.view)
            self.hostingController = hostingController
        }

        hostingController?.view.frame = bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        annotation = nil
        hostingController?.rootView = HighlightMapPinView(imageSource: .placeholder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hostingController?.view.frame = bounds
    }
}

private struct HighlightMapPinView: View {
    static let photoPinSize = CGSize(width: 64, height: 76)
    static let compactPinSize = CGSize(width: 34, height: 44)

    let imageSource: HomeView.HighlightImageSource

    var body: some View {
        if imageSource.hasImage {
            PhotoTeardropPin(imageSource: imageSource)
                .frame(width: Self.photoPinSize.width, height: Self.photoPinSize.height)
        } else {
            CompactTeardropPin()
                .frame(width: Self.compactPinSize.width, height: Self.compactPinSize.height)
        }
    }
}

private struct PhotoTeardropPin: View {
    let imageSource: HomeView.HighlightImageSource

    @State private var photoURL: URL?
    @State private var didFinishLoadingRemotePhoto = false

    var body: some View {
        ZStack(alignment: .top) {
            TeardropPinShape()
                .fill(Color.accentSecondary)
                .overlay {
                    TeardropPinShape()
                        .stroke(Color.accentSecondary, lineWidth: 3)
                        .brightness(-0.20)
                }
                .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 4)

            pinPhoto
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.backgroundPrimary, lineWidth: 3)
                }
                .padding(.top, 7)
        }
        .task(id: imageSource) {
            await loadPhotoURL()
        }
    }

    @ViewBuilder
    private var pinPhoto: some View {
        switch imageSource {
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFill()
        case .remote:
            if let photoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .empty:
                        loadingPhoto
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
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

    private var loadingPhoto: some View {
        Circle()
            .fill(Color.backgroundPrimary.opacity(0.45))
            .overlay {
                ProgressView()
                    .controlSize(.small)
            }
    }

    private var fallbackPhoto: some View {
        Circle()
            .fill(Color.backgroundPrimary.opacity(0.35))
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary.opacity(0.55))
            }
    }

    @MainActor
    private func loadPhotoURL() async {
        photoURL = nil
        didFinishLoadingRemotePhoto = false

        guard case .remote(let path) = imageSource else {
            didFinishLoadingRemotePhoto = true
            return
        }

        photoURL = try? await HighlightService.shared.signedURL(for: path)
        didFinishLoadingRemotePhoto = true
    }
}

private struct CompactTeardropPin: View {
    var body: some View {
        ZStack {
            TeardropPinShape()
                .fill(Color.accentPrimary)
                .overlay {
                    TeardropPinShape()
                        .stroke(Color.backgroundPrimary, lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)

            Image(systemName: "fork.knife")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .offset(y: -4)
        }
    }
}

private struct TeardropPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        let leftShoulder = CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.46)
        let rightShoulder = CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.46)

        path.move(to: tip)
        path.addCurve(
            to: leftShoulder,
            control1: CGPoint(x: rect.midX - rect.width * 0.17, y: rect.maxY - rect.height * 0.18),
            control2: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.74)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.16),
            control2: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY)
        )
        path.addCurve(
            to: rightShoulder,
            control1: CGPoint(x: rect.maxX - rect.width * 0.24, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.16)
        )
        path.addCurve(
            to: tip,
            control1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.74),
            control2: CGPoint(x: rect.midX + rect.width * 0.17, y: rect.maxY - rect.height * 0.18)
        )
        path.closeSubpath()
        return path
    }
}

#Preview("Map With Located Dishes") {
    NavigationStack {
        MapView(
            highlights: .constant(HomeView.previewHighlights),
            occasions: HomeView.previewOccasions,
            previewImageAssets: HomeView.previewImageAssets
        )
    }
}

#Preview("Map Empty") {
    NavigationStack {
        MapView(highlights: .constant([]))
    }
}
