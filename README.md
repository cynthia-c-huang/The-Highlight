# The Highlight

The Highlight is an iOS SwiftUI app for saving memorable dishes with photos, ratings, notes, restaurant details, and meal context. It combines a personal food journal with a Supabase-backed discovery catalog for finding dishes to try and linking them to saved highlights.

## Features

- Email-based authentication with sign in, account creation, password reset, persisted sessions, and a custom URL callback scheme.
- Personal dish highlights with photo upload, dish name, home/restaurant context, optional date, 1-10 rating, flavor tags, and memory notes.
- Supabase-backed storage for highlights, meal occasions, published dish references, and private highlight photos served through signed URLs.
- Home view with loading, empty, error, featured photo carousel, and top highlights ranked by rating and recency.
- Dishes library with search, location filters, rating filters, date filters, sorting, and optional meal-based grouping.
- Dish detail flow with full-screen photo viewing, editing, deletion, meal context, and related dishes from the same occasion.
- MapKit-based location experience with restaurant search, manual map pinning, reverse geocoding, nearby restaurant suggestions, and custom photo pins.
- Discovery catalog with cuisine, flavor, dietary, and tried/untried filters; shuffle ordering; dish detail pages; related dishes; and options to add or link a Highlight.
- Preferences for username/profile metadata, email verification requests, local profile photo, default map starting point, and system/light/dark appearance.
- SwiftUI previews backed by local asset catalog sample data so UI work can be inspected without contacting Supabase.

## Screenshots

Add 3-4 screenshots to `docs/screenshots/` and update the image paths below.

| Home | Add Highlight |
| --- | --- |
| ![Home screen placeholder](docs/screenshots/home.png) | ![Add Highlight form placeholder](docs/screenshots/add-highlight.png) |

| Discovery | Map |
| --- | --- |
| ![Discovery catalog placeholder](docs/screenshots/discovery.png) | ![Map view placeholder](docs/screenshots/map.png) |

## Built With

- Swift and SwiftUI
- Supabase Swift for Auth, PostgREST, and Storage
- MapKit and CoreLocation
- PhotosUI
- UIKit interoperability through `UIViewRepresentable` and `UIHostingController`
- Swift concurrency with `async`/`await`, `Task`, `@MainActor`, and actors
- Combine-backed observable state via `ObservableObject` and `@Published`
- Swift Package Manager
- Swift Testing, XCTest, and XCUIAutomation
- Asset catalogs and bundled custom fonts

## Architecture / Technical Highlights

- Lightweight MVVM structure: SwiftUI views own rendering and navigation, view models own presentation state and async UI workflows, and services isolate Supabase/backend operations.
- Auth routing is centralized in `RootView` and `AuthManager`, so the app switches between loading, authenticated, and signed-out experiences from a single source of truth.
- Domain models use `Codable` with explicit Supabase snake_case mappings, plus custom date decoding for Supabase timestamp/date variants.
- Photo handling uses a private Supabase Storage bucket, per-user object paths, temporary signed URLs, and an actor-backed URL cache to reduce repeated signing requests.
- Meal grouping is modeled with an `occasions` table and optional `highlights.occasion_id`, keeping one Highlight per dish while allowing multiple dishes to share a meal.
- Map features bridge `MKMapView` into SwiftUI to support custom annotation views, photo-backed pins, visible-region filtering, tap/long-press location selection, and reverse geocoding.
- Discovery is text-first: published catalog rows are fetched from Supabase, then searched, filtered, shuffled, and linked locally through `DishDiscoveryViewModel`.
- Preview data and preview images are kept separate from production Supabase flows.

## Getting Started

### Prerequisites

- Xcode with an iOS SDK compatible with the project settings. The current deployment target is iOS 26.5.
- A Supabase project configured with the tables and storage bucket expected by the app.

### Run the App

1. Clone the repository:

    ```sh
    git clone <repository-url>
    cd "The Highlight"
    ```

2. Open the Xcode project:

    ```sh
    open "The Highlight.xcodeproj"
    ```

3. Let Xcode resolve Swift Package Manager dependencies.

4. Review Supabase configuration before running. The app currently initializes Supabase in `The Highlight/Services/SupabaseManager.swift`, and there is also a legacy helper in `The Highlight/Utils/Supabase.swift`. Use your own Supabase project URL and anon key for local development; never commit service-role keys or private credentials.

5. Configure the backend:

    - `public.highlights` stores saved dish highlights.
    - `public.occasions` stores meal groups.
    - `public.dish_references` stores published catalog dishes.
    - `highlight-photos` is a private Supabase Storage bucket for user photos.
    - `SUPABASE_OCCASIONS_MIGRATION.sql` contains the manual SQL migration for occasion support.

6. Select the `The Highlight` scheme and run on an iOS simulator or device.

Command-line build:

```sh
xcodebuild -project "The Highlight.xcodeproj" -scheme "The Highlight" -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Run tests:

```sh
xcodebuild -project "The Highlight.xcodeproj" -scheme "The Highlight" -destination 'platform=iOS Simulator,name=iPhone 17' test
```

If `iPhone 17` is not available locally, replace the destination with an installed simulator from:

```sh
xcrun simctl list devices available
```

## Public Repository Notes

Before publishing a fork or portfolio copy, review project-specific configuration and local files. Supabase anon keys are client-side keys, but they still identify a backend project and should only be public when Row Level Security and storage policies are correctly configured. Personal Xcode user data and image EXIF metadata should be removed before making the repository public.
