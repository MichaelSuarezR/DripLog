# DripLog (Fitty)

DripLog is a full-stack iOS social fashion app that helps users build a digital closet, auto-tag outfits with AI, and generate daily outfit inspiration grounded in live weather and personal style preferences.

Built with SwiftUI + Supabase + AI edge functions, this project showcases end-to-end product engineering: authentication, onboarding, media pipelines, feed systems, social graph logic, privacy controls, and AI-assisted experiences.

---

## Why This Project Is Strong

- **Real product scope**: auth, onboarding, camera/upload, closet management, social feed, follows, likes, bookmarks, profile management, and AI suggestions.
- **Production-minded backend**: Supabase Postgres + Row Level Security (RLS), storage buckets, signed URLs, and edge functions.
- **AI integration with guardrails**: constrained taxonomy tagging + structured JSON responses + daily suggestion caching.
- **UX depth**: guided onboarding, tooltip-based tutorial system, animated transitions, and custom design system styling.
- **Data privacy architecture**: visibility levels (`private`, `friends`, `public`) enforced in DB policies.

---

## Core Features

### 1) Authentication & Account

- Email/password sign-up + login
- Google OAuth sign-in (`fitty://` URL scheme)
- Session restore on app launch
- Account editing (name/email)
- Profile photo upload with signed URL retrieval

Key files:
- `DripLog/Frontend/AuthView.swift`
- `DripLog/Frontend/AuthViewModel.swift`
- `DripLog/Backend/AuthService.swift`

### 2) Guided Onboarding

Multi-step onboarding coordinated in a single flow:
- Intro slides
- Style preference capture (gender + style)
- Profile + 5 outfit photo upload requirement
- Optional per-outfit tagging editor

Onboarding completion is tied to successful media uploads, not optional tag confirmation.

Key files:
- `DripLog/Frontend/Onboarding/OnboardingCoordinator.swift`
- `DripLog/Frontend/Onboarding/OnboardingView.swift`
- `DripLog/Frontend/Onboarding/OnboardingPreferencesView.swift`
- `DripLog/Frontend/Onboarding/OnboardingPhotoGridView.swift`

### 3) Closet Upload + Tagging System

- Camera-based outfit capture
- Upload pipeline with image resizing/compression
- Structured metadata model: categories, weather, occasion, colors, custom tags, visibility
- Shared tag editor module with accordion sections and chips
- Edit tags after upload

Key files:
- `DripLog/Frontend/Outfit/OutfitUploadTaggingView.swift`
- `DripLog/Frontend/Outfit/OutfitEditView.swift`
- `DripLog/Frontend/Tagging/TagEditorView.swift`
- `DripLog/Backend/OutfitService.swift`

### 4) AI Auto-Tagging

Outfit images are sent to an edge function that calls Gemini and returns constrained tags in a strict schema:
- `categories`
- `weather`
- `occasion`
- `colors`

This keeps tags consistent and filterable across the app.

Key files:
- `DripLog/Backend/OutfitService.swift` (`SupabaseAutoTagService`)
- `supabase/functions/auto-tag-outfit/index.ts`

### 5) AI Outfit Suggestions (Weather + Closet + Inspiration)

Suggestion generation combines:
- User closet outfits
- Inspiration catalog entries
- Live weather context from Open-Meteo
- Gemini ranking/explanation logic

Daily results are cached per-user per-local-date in Postgres to avoid redundant AI calls and improve responsiveness.

Key files:
- `DripLog/Backend/OutfitService.swift` (`SupabaseSuggestionService`)
- `DripLog/Frontend/Suggestions/SuggestionsView.swift`
- `supabase/functions/outfit-suggestions/index.ts`
- `supabase/migrations/20260528000000_daily_outfit_suggestions.sql`

### 6) Social Feed + Interactions

- Multi-scope feed (`Recent`, `Friends Only`, `Saved`)
- Follow relationships
- Like/unlike
- Bookmark/unbookmark
- Feed pagination + refresh

Key files:
- `DripLog/Frontend/Tabs/HomeTab.swift`
- `DripLog/Backend/FeedService.swift`

### 7) Friends System

- Search users
- Follow/unfollow
- View incoming requests/follow-backs
- Friend profile detail screens

Key files:
- `DripLog/Frontend/FriendsView.swift`
- `DripLog/Backend/FriendService.swift`

### 8) Privacy & Visibility

Outfits support visibility levels:
- `private`
- `friends`
- `public`

Feed queries + DB policies are aligned so visibility is enforced at the data layer.

Key files:
- `DripLog/Frontend/Closet/OutfitVisibility.swift`
- `supabase/migrations/20260526000000_feed_visibility_bookmarks.sql`
- `supabase/migrations/20260526010000_follow_relationships.sql`

### 9) First-Time Tutorial Overlay System

A stateful tutorial guides users through critical interactions:
- AI tags
- Dropdown tagging
- Closet grid
- Generate outfit CTA
- Feed usage

Key files:
- `DripLog/Frontend/Tutorial/TutorialManager.swift`
- `DripLog/Frontend/Tutorial/TutorialOverlay.swift`
- `DripLog/Frontend/Tutorial/TutorialAnchorKey.swift`

---

## Technical Stack

### iOS App

- **Language**: Swift 5
- **UI**: SwiftUI (plus UIKit interop for camera/image handling)
- **State**: `@State`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`, `@AppStorage`
- **Concurrency**: Swift Concurrency (`async/await`, task groups)
- **Media**: `PhotosUI`, `UIImage` resizing/compression pipeline

### Backend

- **Supabase Auth** (email/password + Google OAuth)
- **Supabase Postgres** (profiles, outfits, friendships, likes, bookmarks, daily suggestions)
- **Supabase Storage** (`profile-photos`, `outfit-photos`)
- **Supabase Edge Functions** (Deno/TypeScript)

### AI + External APIs

- **Google Gemini** (`gemini-2.5-flash`) for:
  - auto-tag extraction
  - outfit pairing/rationale generation
- **Open-Meteo** for live weather context

### Key Dependency

- `supabase-swift` (via Swift Package Manager, currently pinned in `Package.resolved`)

---

## Project Structure

```text
DripLog/
  Frontend/
    Auth/
    Onboarding/
    Outfit/
    Tagging/
    Tabs/
    Tutorial/
    Suggestions/
    Closet/
    Camera/
  Backend/
    AuthService.swift
    OutfitService.swift
    FeedService.swift
    FriendService.swift
    SupabaseClientProvider.swift
supabase/
  migrations/
  functions/
    auto-tag-outfit/
    outfit-suggestions/
```

---

## Run Locally (iOS App)

### Prerequisites

- macOS + Xcode (project currently targets iOS 26.2 in build settings)
- Apple Developer account/team ID for device signing
- Optional: Supabase account + project for your own backend

### 1) Clone

```bash
git clone https://github.com/<your-org-or-user>/DripLog.git
cd DripLog
```

### 2) Local Xcode Config

Create local config from template:

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Then set:
- `DEVELOPMENT_TEAM`
- `APP_BUNDLE_ID`

### 3) Configure Supabase Keys (recommended for your own backend)

The app reads:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

via build settings / Info.plist keys.

In Xcode target build settings, set:
- `INFOPLIST_KEY_SUPABASE_URL`
- `INFOPLIST_KEY_SUPABASE_ANON_KEY`

### 4) Google OAuth Redirect (if using Google sign-in)

Set redirect URI in Supabase Auth to include:

```text
fitty://
```

Also ensure URL scheme `fitty` exists in `Info.plist` (already present in this repo).

### 5) Run

- Open `DripLog.xcodeproj`
- Select scheme `DripLog`
- Build & run on simulator or device

---

## Run Backend (Supabase + Edge Functions)

You can run against an existing hosted Supabase project or your own local/cloud setup.

### Prerequisites

- [Supabase CLI](https://supabase.com/docs/guides/cli)
- Docker (for local Supabase runtime)

### 1) Start Supabase & apply schema

```bash
supabase start
supabase db reset
```

This applies migrations in `supabase/migrations/`.

### 2) Set required function secrets

```bash
supabase secrets set GEMINI_API_KEY=your_gemini_key
```

(`SUPABASE_URL` and `SUPABASE_ANON_KEY` are provided by Supabase runtime.)

### 3) Deploy functions

```bash
supabase functions deploy auto-tag-outfit
supabase functions deploy outfit-suggestions
```

### 4) Wire app to this project

Update app `SUPABASE_URL` / `SUPABASE_ANON_KEY` to the target project values.

---

## Data & Security Notes

- RLS is enabled on key tables and storage object access.
- Visibility policies enforce post access by relationship/public state.
- Storage access is folder-scoped by auth user ID for owned media uploads.
- Signed URLs are used for image access.

See:
- `supabase/migrations/20260513000000_profiles_rls.sql`
- `supabase/migrations/20260514001000_outfit_access.sql`
- `supabase/migrations/20260526000000_feed_visibility_bookmarks.sql`

---

## Engineering Highlights Recruiters Care About

- **End-to-end ownership** from UI to database policy design.
- **AI in production context** with constrained outputs and fallback logic.
- **Performance-aware media pipeline** (resize + compression before upload).
- **Separation of concerns** (service layer protocols + composable SwiftUI modules).
- **Resilient UX** (loading/error handling, retries, cached daily AI suggestions).
- **Practical social architecture** (follows, likes, bookmarks, scoped feed).

---

## Future Improvements

- Add unit + UI test coverage for service and onboarding flows.
- Add CI for lint/build/migration checks.
- Add analytics and experiment hooks for onboarding conversion.
- Add push notification delivery pipeline and in-app notifications persistence.
- Add screenshots/GIFs to this README for quick recruiter scanability.

