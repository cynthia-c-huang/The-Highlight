# Backlog

## Now

## Next

* [ ] Review current folder structure and move files into `Views`, `ViewModels`, `Models`, `Services`, `Managers`, and `Utils` as needed

## Later

* [ ] Add nested `AGENTS.md` for `The Highlight/Services/`
* [ ] Add nested `AGENTS.md` for `The Highlight/Views/`
* [ ] Create a repeatable Codex skill for debugging Supabase auth issues
* [ ] Create a repeatable Codex skill for adding new app fields across model, UI, and Supabase layers
* [ ] Add "look for this near me" restaurant discovery from catalog dish detail
* [ ] Consider Supabase full-text or semantic catalog search once the dish catalog grows beyond local filtering
* [ ] Consider remote catalog photos after the text-first discovery flow is stable
* [ ] Consider a dedicated meal-management screen for renaming, editing, or deleting occasions with dishes

## Bugs

* [ ] Document known bugs here as they are discovered

## Decisions

* 2026-07-06: Use root `AGENTS.md` for general Codex guidance and `BACKLOG.md` for cross-session task continuity.
* 2026-07-06: Do not use `BACKLOG.md` as a changelog; only update it for meaningful tasks, TODOs, bugs, and decisions.
* 2026-07-24: Store appearance as `AppAppearance` and apply it through SwiftUI's root `preferredColorScheme`; individual screens can still define page-specific dark palettes.
* 2026-08-04: Implement Dish Discovery as a text-first published catalog using local search/filter/shuffle and nullable `highlights.dish_reference_id` links.

## Done

* [x] Initialized basic Codex repository guidance
* [x] Confirm Supabase login persists across app relaunch
* [x] Add loading, error, and signed-out states around the login/homepage flow
* [x] Check and make sure the login functionality works
* [x] Implement minimal Save Highlight flow (private bucket with signed URLs): photo upload to highlight-photos, insert into public.highlights, Home loads real highlights and shows EmptyHighlightsView when none.
* [x] In the AuthView (login page), use the Cantarell text font as the body text for "taste everything again," "username," "email," "forgot?", and the typed in text field from the user when filling in the username and email. Do not use default SwiftUI fonts.
* [x] In the AuthView (login page), for the word "everything" do not use the .italic(), but use the defined Cantarell Italic typeface from Typography.swift
* [x] In the home page, all body text should properly use Cantarell, not the default text font. These include the navbar text, featured display text, and dish card names (i.e. "MILLE FEUILLE")
* [x] In the home page, the icons and text in the navbar should use the color "Dark Purple," labeled as textPrimary in Color+Palette.
* [x] Create another color within Color+Palette.swift for the dusty mauve color from the assets' color set, which is called "Dusty Mauve".
* [x] Refresh Home after saving a highlight and show saved highlight photos in the featured display.
* [x] Add edit highlight flow from Home dish cards using the shared dish form.
* [x] Add required dish ratings and optional memory notes to create/edit flows.
* [x] Change Home bottom grid from all dishes to the top 4 highlights by rating and recency.
* [x] Implement the Dishes nav screen with search, quick filters, and reusable dish cards.
* [x] Add optional restaurant/map locations to dish create/edit flow and Map tab.
* [x] Add optional meal/occasion grouping while keeping one Highlight per dish.
* [x] Delete replaced or removed highlight photos from storage and add a photo removal control to the dish form.
* [x] Align custom navigation for dish, map, and first-highlight flows; remove unused Search and Content screens.
* [x] MapView pins should display photos of highlights
* [x] Implement preferences settings (dark mode)
* [x] When clicking on a dish, show dish details first with an edit button
* [x] Implement remove dish feature; if all dishes are removed, return to empty highlights (save your first)
* [x] Cache signed photo URLs by path and expiration to reduce repeated Supabase Storage signing calls.
* [x] Implement Dish Discovery catalog browsing, detail pages, Add Highlight prefill, and existing Highlight linking/unlinking.
---

### Supabase Setup Notes

- Table: `public.highlights`
  - Columns include: `id` (uuid), `user_id` (uuid), `dish_name` (text), `location_type` (text), `date_eaten` (date/timestamp), `tags` (text[]), `photo_path` (text), `rating` (numeric(3,1)), `memory_note` (text), `restaurant_name` (text), `formatted_address` (text), `latitude` (double precision), `longitude` (double precision), optional `occasion_id` (uuid), `created_at` (timestamp).
- Table: `public.occasions`
  - Columns include: `id` (uuid), `user_id` (uuid), optional `title`, optional `date`, optional `restaurant_name`, optional `formatted_address`, optional `latitude`, optional `longitude`, `created_at` (timestamp).
  - Manual setup SQL lives in `SUPABASE_OCCASIONS_MIGRATION.sql`.
- Bucket: `highlight-photos` (private)
  - Path format: `{user_id}/{uuid}.{ext}`
- Storage RLS policies for insert/select/update/delete use:
  - `storage.foldername(name)[1] = auth.uid()::text`  
  or the prefix alternative for authorization

---

### TODOs

* Improve error messaging and retry/backoff on upload failures
* Consider MapKit clustering once there are enough located dishes
* Add current-location centering later if the app needs location permission
* Consider direct edit navigation from map annotation callouts
