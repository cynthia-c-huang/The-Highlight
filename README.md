# The Highlight

The Highlight is an iOS SwiftUI app for saving dishes with photos, ratings, notes, restaurant details, and meal context. It combines a personal food journal with a Supabase-backed discovery catalog for finding dishes to try and linking them to saved highlights.

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
