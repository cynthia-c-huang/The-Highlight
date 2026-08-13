# Repository Guidelines

## Project Overview

This repository contains **The Highlight**, an iOS SwiftUI app backed by Supabase.

The app should prioritize:

* A clean, native iOS SwiftUI experience.
* Clear separation between UI, presentation state, domain models, and backend services.
* Safe handling of authentication, user data, and Supabase configuration.
* Small, testable changes that can be verified locally in Xcode or with `xcodebuild`.

When making changes, first inspect the existing structure and follow current patterns rather than introducing a new architecture unless explicitly requested.

## Agent Operating Rules

When working in this repository:

1. Make the smallest reasonable change that solves the task.
2. Read relevant files before editing.
3. Preserve existing naming, folder structure, and architectural patterns.
4. Do not perform broad refactors unless explicitly requested.
5. Do not delete files, rename targets, change bundle identifiers, or alter signing settings unless explicitly requested.
6. Do not commit secrets, tokens, API keys, personal credentials, or local-only configuration.
7. After code changes, run an appropriate build or test command when possible.
8. If a command fails because of simulator, signing, sandbox, or local machine constraints, explain the failure and provide the exact command the user should run in Xcode or Terminal.
9. At the end of each task, summarize:

   * What changed.
   * Which files changed.
   * What verification was run.
   * Any follow-up risks or TODOs.

## Project Structure & Module Organization

The Xcode project is:

```sh
The Highlight.xcodeproj
```

App source lives in:

```sh
The Highlight/
```

Important locations:

* `The Highlight/The_HighlightApp.swift`: app entry point.
* `The Highlight/ContentView.swift`: root or initial SwiftUI composition.
* `The Highlight/Views/`: SwiftUI screens, reusable components, and view composition.
* `The Highlight/ViewModels/`: observable state, presentation logic, and UI-facing async flows.
* `The Highlight/Models/`: domain models, DTOs, request/response types, and data structures.
* `The Highlight/Managers/`: app-level coordinators or long-lived managers.
* `The Highlight/Services/`: backend, Supabase, networking, authentication, persistence, and integration layers.
* `The Highlight/Utils/`: shared helpers, extensions, constants, formatting, and theme utilities.
* `The Highlight/Assets.xcassets`: colors, images, app icons, and asset catalog resources.
* `The HighlightTests/`: unit tests.
* `The HighlightUITests/`: UI tests.

When adding new code:

* Put SwiftUI screens and components in `Views/`.
* Put presentation state and UI logic in `ViewModels/`.
* Put app/domain data types in `Models/`.
* Put Supabase, auth, networking, and persistence code in `Services/`.
* Put reusable extensions and small helpers in `Utils/`.
* Avoid putting business logic directly inside SwiftUI views.

## Architecture Conventions

Use SwiftUI with a lightweight MVVM-style structure.

Preferred patterns:

* Views render state and forward user actions.
* View models own presentation state, validation, async loading, and user-triggered operations.
* Services perform Supabase, authentication, persistence, and external integration work.
* Models should stay simple, Codable where appropriate, and avoid UI dependencies.
* Keep async work explicit and handle loading, success, empty, and error states.
* Prefer dependency injection for services where practical, especially in view models that should be testable.

Avoid:

* Large SwiftUI views with embedded networking or database logic.
* Direct Supabase calls from views.
* Global mutable state unless there is already an established manager pattern.
* Introducing new dependencies without explaining why they are needed.
* Replacing working code with a different architecture unless requested.

## Supabase & Auth Guidelines

Supabase-related implementation should live in `Services/` or an existing Supabase/auth-specific location.

Do not hard-code Supabase secrets or credentials. Configuration should reference existing plist, environment, or local configuration patterns already used by the project.

When touching Supabase or auth code:

* Inspect the existing auth flow before editing.
* Preserve any previously debugged sign-in/sign-out/session handling behavior.
* Be careful with redirect URLs, callback handling, session persistence, and app lifecycle behavior.
* Do not change database table names, policies, schemas, or migrations unless explicitly asked.
* If a schema change is needed, propose it clearly before editing app code that depends on it.
* Never log access tokens, refresh tokens, or user-sensitive data.

If Supabase MCP or another live schema tool is available, prefer checking the actual schema before assuming table or column names.

## Build, Test, and Development Commands

Open the project locally with Xcode:

```sh
open "The Highlight.xcodeproj"
```

List available schemes:

```sh
xcodebuild -list -project "The Highlight.xcodeproj"
```

List available simulator destinations:

```sh
xcrun simctl list devices available
```

Build from the command line:

```sh
xcodebuild -project "The Highlight.xcodeproj" -scheme "The Highlight" build
```

Build for a specific iOS simulator when available:

```sh
xcodebuild -project "The Highlight.xcodeproj" -scheme "The Highlight" -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Run tests from the command line:

```sh
xcodebuild -project "The Highlight.xcodeproj" -scheme "The Highlight" test
```

Run tests for a specific iOS simulator when available:

```sh
xcodebuild -project "The Highlight.xcodeproj" -scheme "The Highlight" -destination 'platform=iOS Simulator,name=iPhone 17' test
```

If simulator discovery fails in a sandboxed shell, run the same build or test action from Xcode.

## Verification Expectations

After changing Swift code, run a build unless the change is documentation-only.

After changing models, services, managers, auth, or view models, run relevant unit tests if available.

After changing user flows, navigation, launch behavior, onboarding, or authentication UI, run UI tests if available or explain how to manually verify the flow in Xcode.

Minimum verification by change type:

* Documentation only: no build required.
* SwiftUI-only visual change: build the app.
* View model change: build and run related unit tests if present.
* Service/auth/Supabase change: build and run related unit tests if present.
* Project settings, entitlements, plist, or signing change: build in Xcode or explain manual verification steps.
* Test-only change: run the affected test target.

Do not claim verification succeeded unless the command actually completed successfully.

## Coding Style & Naming Conventions

Use standard Swift conventions:

* Four-space indentation.
* `UpperCamelCase` for types.
* `lowerCamelCase` for properties, methods, variables, and enum cases.
* Descriptive file names that match the primary type where practical.
* Keep files focused and avoid mixing unrelated types in one file.

SwiftUI conventions:

* Keep views small and composable.
* Extract repeated UI into reusable components.
* Keep layout code readable.
* Prefer computed subviews or private helper views when a body becomes too large.
* Avoid putting networking, database, or auth logic directly in views.

View model conventions:

* Use clear state names such as `isLoading`, `errorMessage`, `isAuthenticated`, or domain-specific equivalents.
* Prefer `@MainActor` for view models that update UI state.
* Handle async errors explicitly.
* Avoid swallowing errors silently.

Model conventions:

* Prefer `struct` for value types.
* Use `Codable` for Supabase/network DTOs where appropriate.
* Keep UI formatting out of core models unless the project already follows that pattern.

## Testing Guidelines

This project uses XCTest with separate unit and UI test targets.

Add unit tests in:

```sh
The HighlightTests/
```

Add UI tests in:

```sh
The HighlightUITests/
```

Add or update tests when changing:

* Models.
* View models.
* Services.
* Auth/session handling.
* Supabase request/response mapping.
* Validation logic.
* Important user flows.

Name tests with clear behavior, for example:

```swift
testSignInUpdatesAuthState()
testSignOutClearsSession()
testLaunchShowsRootView()
testJournalEntryValidationRejectsEmptyTitle()
```

Tests should avoid depending on production secrets or live user data. Prefer mocks, fakes, fixtures, or test-only configuration where possible.

## Security & Configuration Tips

Do not commit:

* Supabase service role keys.
* Access tokens.
* Refresh tokens.
* Personal credentials.
* Private API keys.
* Local-only config files.
* Generated files that contain secrets.

Review changes carefully before editing:

* `The-Highlight-Info.plist`
* entitlements files
* project signing settings
* Supabase configuration
* auth redirect/callback settings
* app target settings
* package dependencies

If a task requires credentials, ask the user to configure them locally rather than inserting them into source.

## Git & Change Management

Use git as the safety net.

Before risky changes, inspect the working tree:

```sh
git status --short
```

Prefer small, focused diffs.

Do not commit changes unless explicitly asked.

Do not overwrite or discard uncommitted user changes unless explicitly asked.

When summarizing work, mention any files that were modified and any files that may need user review.

Recent history uses short, direct commit subjects such as:

```sh
Project setup
Initial Commit
```

Continue with concise imperative or descriptive subjects, ideally under 72 characters.

Examples:

* `Add sign-in loading state`
* `Fix Supabase session refresh`
* `Extract reusable highlight card view`
* `Add journal entry validation tests`

## Pull Request Guidelines

Pull requests should include:

* Brief summary.
* Testing performed.
* Screenshots or screen recordings for UI changes.
* Links to any related issue, task, or backlog item.
* Notes for configuration changes, especially plist, assets, signing, or Supabase-related changes.

## Backlog & Cross-Session Continuity

Use the root-level `BACKLOG.md` as the source of truth for active tasks, next steps, deferred ideas, and important project decisions.

At the start of a task-oriented session:

* Check `BACKLOG.md` if it exists.
* Identify whether the user's request matches an existing task.
* Prefer updating an existing task instead of creating duplicates.

When completing work:

* Mark a backlog item complete if the completed work directly satisfies that item.
* Add a short note under `Decisions` only for meaningful product, architecture, Supabase, auth, data model, or workflow decisions.
* Do not log every minor code edit.
* Do not update `BACKLOG.md` for routine implementation details unless explicitly asked.

When discovering follow-up work:

* Add a TODO only if it is important, actionable, and not already captured.
* Keep backlog items short and specific.
* Do not use `BACKLOG.md` as a changelog.

Suggested backlog format:

```md
# Backlog

## Now
- [ ] Current active task

## Next
- [ ] Near-term task

## Later
- [ ] Future idea

## Bugs
- [ ] Known bug or broken flow

## Decisions
- YYYY-MM-DD: Decision and rationale

## Done
- [x] Completed task
```

## Documentation Expectations

When introducing or changing an important convention, update the relevant documentation.

Good candidates:

* `AGENTS.md` for agent/project conventions.
* `BACKLOG.md` or `TASKS.md` for active work.
* `README.md` for human setup instructions.
* Nested `AGENTS.md` files for specialized subdirectories.

Use nested `AGENTS.md` files only when a subfolder has meaningfully different rules. For example:

* `The Highlight/Services/AGENTS.md` for Supabase/auth/service rules.
* `The Highlight/Views/AGENTS.md` for SwiftUI UI conventions.
* `The HighlightTests/AGENTS.md` for testing conventions.

Keep nested files short and specific.

## Dependency Guidelines

Do not add Swift Package Manager dependencies unless necessary.

Before adding a dependency:

* Check whether the project already has an equivalent helper or package.
* Explain why the dependency is needed.
* Prefer stable, maintained packages.
* Avoid adding packages for small utilities that can be implemented simply in the app.

After dependency changes:

* Build the project.
* Note any package resolution or Xcode project changes.

## UI & Product Guidelines

For UI changes:

* Preserve the existing visual style unless asked to redesign.
* Use asset catalog colors where available.
* Prefer native SwiftUI components and platform conventions.
* Keep accessibility in mind: readable text, clear tap targets, useful labels, and Dynamic Type where practical.
* Include previews for reusable views when they are useful and easy to maintain.

When creating or updating any view that displays dish or highlight data:

* Provide a SwiftUI Canvas preview populated with representative sample dish data.
* Use local images from `Assets.xcassets` for preview photos rather than Supabase storage or network requests.
* Reuse the existing preview-data and preview-image infrastructure instead of creating one-off mocks for each view.
* Keep preview dependencies isolated from production behavior.
* Preview data must never be inserted into Supabase, used as production fallback content, or shown to authenticated users.
* The normal logged-in experience must continue to use the real authentication state, Supabase data, and remote photo-loading flow.
* Preserve empty states for real users who have no saved dishes.
* When a new dish-data view is added, include at least one populated preview and, where relevant, an empty-state preview.

For product changes:

* Keep flows simple and obvious.
* Handle empty, loading, success, and error states.
* Avoid adding placeholder screens or fake flows without marking them clearly.
* Do not introduce analytics, tracking, or data collection without explicit approval.

## Done Criteria

A task is done when:

* The requested behavior is implemented.
* The code follows existing project conventions.
* The app builds, or any build limitation is clearly explained.
* Relevant tests are added or updated when appropriate.
* The final response summarizes changed files and verification.
