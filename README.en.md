# 开球 · GameOn — Flutter App

[中文](README.md) · **English**

A social app for amateur ball-sports: pickup games, tournaments, and skill ratings.

> Kick off a game.

## Brand

| | |
|---|---|
| Chinese name | 开球 (Kāi qiú) |
| English name | GameOn |
| Bundle ID | `cn.kaiqiu.app` |
| Dart package | `kaiqiu_app` |
| OS directory | `qiuju_app/` (legacy, not renamed) |

Rebrand decision record: [docs/superpowers/specs/2026-04-20-rebrand-kaiqiu-gameon-design.md](docs/superpowers/specs/2026-04-20-rebrand-kaiqiu-gameon-design.md)

## Tech Stack

- **Flutter 3.41+** / **Dart 3.11+**
- **Supabase** — auth, Postgres, realtime, storage (BaaS — no self-hosted backend needed)
- **go_router** — declarative routing
- **flutter_riverpod** — state management
- **supabase_flutter** — official SDK
- **intl** — date/number localization

## Project Structure

```
qiuju_app/                      # OS directory (Dart package is kaiqiu_app)
├── lib/
│   ├── main.dart               # entry point
│   ├── app.dart                # KaiqiuApp + MaterialApp.router
│   ├── routes.dart             # go_router config
│   ├── providers.dart          # global Riverpod providers
│   ├── config/env.dart         # Supabase URL / anon key (compile-time)
│   ├── theme/                  # ThemeData + design tokens
│   ├── widgets/                # shared components (Avatar, Chip, LivePill, ...)
│   ├── models/                 # data models (Pickup, Event, Rating, ...)
│   ├── services/supabase.dart  # Supabase client helper
│   ├── repositories/           # thin Supabase wrappers
│   ├── data/mock.dart          # offline mock data (scaffold phase)
│   └── features/
│       ├── auth/               # sign in / sign up
│       ├── home/               # home feed
│       ├── pickup/             # pickup games (list / map / detail)
│       ├── events/             # tournaments
│       ├── create_event/       # create a game
│       ├── messages/           # in-app messaging
│       ├── profile/            # user profile
│       └── rating/             # skill ratings
├── supabase/
│   ├── migrations/             # schema evolution (0001–0009)
│   └── seed/                   # demo data (01–04)
├── android/ · ios/ · web/      # native shells
├── test/widget_test.dart       # smoke test
├── .github/workflows/build.yml # CI: builds Android APK + iOS IPA
├── docs/superpowers/specs/     # design decision docs
├── IMPLEMENTATION_PLAN.md      # plan for 9 screens
└── pubspec.yaml
```

## Quick Start

### 1. Install Flutter

You need Flutter 3.41+ (`dart sdk: ^3.11.5`).
See https://docs.flutter.dev/get-started/install for platform-specific steps.

Verify:
```bash
flutter --version
flutter doctor
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Supabase backend

**Option A — use the default credentials (works out of the box, points to a shared demo project)**

`lib/config/env.dart` ships with a default URL and anon key. You can run the app immediately.

**Option B — stand up your own project (recommended for production)**

1. Create a new project at https://supabase.com
2. In the **SQL Editor**, run the 9 files in `supabase/migrations/` in order
3. Optionally run the 4 files in `supabase/seed/` to populate demo data
4. Copy `Project URL` and `anon public key` from **Project Settings → API**
5. Inject them via `--dart-define` (see below) or edit the defaults in `lib/config/env.dart`

> Supabase's `anon` key is designed to be shipped with clients — security comes from Row Level Security (RLS) policies on the database. Still, for production releases, prefer `--dart-define` over committing keys into the repo.

### 4. Run locally

```bash
# List available devices / simulators
flutter devices

# Run with default Supabase credentials
flutter run

# Pick a specific device (ID from `flutter devices`)
flutter run -d <device-id>

# Inject your own Supabase credentials
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGc...
```

## Building for Android

```bash
# Release APK (currently signed with the debug key — installable on any Android
# device for testing, but not publishable)
flutter build apk --release

# Release AAB (for Google Play)
flutter build appbundle --release
```

Output locations:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

**Install on a phone**: transfer the APK (USB / cloud / `adb install`), then allow install from unknown sources on the device.

**Publishing to Google Play** requires a release signing key — see [Android docs · Signing](https://developer.android.com/studio/publish/app-signing).

## Building for iOS

Requires **macOS + Xcode** (Linux / Windows cannot build iOS directly).

```bash
cd ios && pod install && cd ..

# Build unsigned — produces Runner.app, cannot install on device as-is
flutter build ios --release --no-codesign

# Build a signed IPA — requires an Apple Developer account ($99/year)
flutter build ipa --release
```

Output locations:
- unsigned: `build/ios/iphoneos/Runner.app`
- signed IPA: `build/ios/ipa/*.ipa`

**Installing on an iPhone without a paid Apple Developer account**:

1. **Sideloadly** (free, cross-platform) — drop the unsigned IPA in, enter a free Apple ID. Sideloadly re-signs and installs. Valid for 7 days, then re-sign.
2. **Xcode manual signing** (requires a Mac) — open `ios/Runner.xcworkspace`, go to Signing & Capabilities, select a free Apple ID under Personal Team, connect the iPhone, and run.

After install, on the iPhone go to **Settings → General → VPN & Device Management → Trust developer** to allow the app to launch.

## GitHub Actions (CI)

The workflow is at `.github/workflows/build.yml`. Triggers:
- Push to `main` / `master`
- Pull requests
- Manual `Run workflow` from the Actions tab

Two jobs run in parallel:

| Job | Runner | Artifact | Notes |
|---|---|---|---|
| `android` | ubuntu-latest | `kaiqiu-android-apk` | debug-signed APK, installable on any Android |
| `ios` | macos-latest | `kaiqiu-ios-unsigned-ipa` | unsigned, needs Sideloadly / Xcode re-sign |

**(Optional) Configure Supabase secrets**: go to **Settings → Secrets and variables → Actions** and add `SUPABASE_URL` and `SUPABASE_ANON_KEY`. If you skip this, the workflow falls back to the defaults in `lib/config/env.dart`.

**Download artifacts**: Actions tab → select a run → Artifacts section at the bottom.

## Development Commands

| Command | Purpose |
|---|---|
| `flutter pub get` | Install dependencies |
| `flutter pub outdated` | Check for dependency updates |
| `flutter analyze` | Static analysis |
| `flutter test` | Run widget / unit tests |
| `dart format lib/ test/` | Format code |
| `flutter run` | Run locally |
| `flutter build apk --release` | Android release build |
| `flutter build ios --release --no-codesign` | iOS unsigned build |

## Roadmap

- [x] Phase 0: Infrastructure (scaffold, Supabase migrations, CI)
- [ ] Phase 1: Build UI — 9 screens with real data (see `IMPLEMENTATION_PLAN.md`)
- [ ] Phase 2: Swap placeholder map for Amap / Tencent Maps SDK
- [ ] Phase 3: SMS-based phone login (Aliyun / Tencent Cloud SMS gateway)
- [ ] Phase 4: Production-ready messaging (Supabase Realtime or EaseMob)
- [ ] Phase 5: TestFlight + closed beta
- [ ] Phase 6: App Store / Google Play launch

## Contributing

See [CONTRIBUTING.en.md](CONTRIBUTING.en.md) for the full guide ([中文](CONTRIBUTING.md)).

Quick reference:
- Branch naming: `feat/` `fix/` `refactor/` `docs/` `chore/` `test/`
- Commit messages: Conventional Commits (`type: short description`)
- Design-first for changes touching 3+ files, new features, data model, or new dependencies

## Design / Decision Docs

- [Rebrand: 开球 · GameOn](docs/superpowers/specs/2026-04-20-rebrand-kaiqiu-gameon-design.md)
- [Implementation plan (9 screens)](IMPLEMENTATION_PLAN.md)
