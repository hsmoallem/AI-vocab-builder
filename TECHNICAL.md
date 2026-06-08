# AI Vocab Builder — Technical Documentation

> Last updated: June 8, 2026

---

## 1. Project Tokens & IDs

| Token / ID | Value | Location |
|------------|-------|----------|
| **DeepSeek API Key** | `sk-f42...48ba` | `lib/config/secrets.dart` (gitignored) |
| **Firebase Project ID** | `project-794490258159` | Firebase Console |
| **Firebase Config** | `google-services.json` | `android/app/` (gitignored) |
| **Android App ID** | `com.vocabreader.ai_vocab_builder` | `build.gradle.kts`, `AndroidManifest.xml` |
| **GitHub Repo** | `hsmoallem/AI-vocab-builder` | `github.com/hsmoallem/AI-vocab-builder` |
| **SSH Deploy Key** | `~/.ssh/id_ed25519_vocab` (Ed25519) | Hermes server only |

---

## 2. Environment

| Tool | Version |
|------|---------|
| Flutter SDK | 3.44.1 (stable channel) |
| Dart SDK | ≥3.5.0 |
| Android SDK | compileSdk 36, minSdk 21 |
| Kotlin | 2.3.20 |
| Gradle | AGP 9.0.1 |
| Java | JDK 17 |
| Firebase | firebase_core ^3.0.0, firebase_auth ^5.0.0, cloud_firestore ^5.0.0 |
| Google Sign-In | google_sign_in ^6.2.0 |
| IDE | Android Studio + Flutter plugin |

---

## 3. Packages (pubspec.yaml)

### Runtime dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `sqflite` | ^2.4.0 | Local SQLite database |
| `path` | ^1.9.0 | File path utilities |
| `provider` | ^6.1.0 | State management |
| `http` | ^1.2.0 | HTTP client (DeepSeek API) |
| `shared_preferences` | ^2.3.0 | Key-value settings storage |
| `syncfusion_flutter_pdf` | any | PDF text extraction |
| `flutter_pdfview` | any | Native PDF rendering (Apache 2.0, 2M+ downloads) |
| `firebase_core` | ^3.0.0 | Firebase initialization |
| `firebase_auth` | ^5.0.0 | Firebase Authentication |
| `cloud_firestore` | ^5.0.0 | Firestore cloud database |
| `google_sign_in` | ^6.2.0 | Google Sign-In |

### Dev dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | SDK | Unit + widget testing |
| `flutter_lints` | any | Code linting |

---

## 4. File Picker — Native (No Package)

**We do NOT use the `file_picker` package.** Instead we use Android's native `ACTION_OPEN_DOCUMENT` intent via a Flutter `MethodChannel`.

### Tap-to-Add

In **Text view**, select any word → Add Word dialog opens pre-filled → auto-translation triggers.

### Why
- `file_picker` caused persistent Gradle/AGP version conflicts
- The generated `GeneratedPluginRegistrant.java` kept referencing stale v8 classes
- Native approach = zero external dependencies, zero Gradle issues

### How it works

**Channel:** `com.vocabreader/picker`

```
┌──────────────────────┐      MethodChannel       ┌────────────────────┐
│  pdf_reader_screen   │ ──── pickPdf ──────────→ │   MainActivity.kt  │
│        (Dart)        │ ←─── {path, name} ────── │     (Kotlin)       │
└──────────────────────┘                          └────────┬───────────┘
                                                           │
                                                   ACTION_OPEN_DOCUMENT
                                                           │
                                                   ┌───────▼───────────┐
                                                   │ Android File      │
                                                   │ Picker (PDF only) │
                                                   └───────────────────┘
```

**Dart side** (`lib/screens/pdf_reader_screen.dart`):
- Calls `_channel.invokeMapMethod('pickPdf')`
- Receives `{path: String, name: String}`
- Reads file bytes, extracts text via syncfusion

**Kotlin side** (`android/.../MainActivity.kt`):
- Handles `pickPdf` method call
- Launches `Intent.ACTION_OPEN_DOCUMENT` filtered to `application/pdf`
- Copies picked file to app cache
- Returns absolute path + filename to Dart

### iOS (future)
- Same Dart code — `_channel.invokeMapMethod('pickPdf')`
- Add Swift handler in `AppDelegate.swift` using `UIDocumentPickerViewController`
- No Dart changes needed

---

## 5. Architecture

```
lib/
├── config/
│   ├── app_config.dart        # App constants (imports from secrets.dart)
│   ├── app_strings.dart       # Localization strings (English + German)
│   ├── secrets.dart           # DeepSeek API key — GITIGNORED, never committed
│   └── theme.dart             # Material 3 light + dark themes
├── models/
│   └── word.dart              # Word data model (id, word, translation, examples, etc.)
├── providers/
│   ├── auth_provider.dart     # ChangeNotifier — Firebase auth state (Google/Anon)
│   ├── locale_provider.dart   # ChangeNotifier — UI language (English/Deutsch)
│   └── word_provider.dart     # ChangeNotifier — CRUD, sort, search, translate
├── screens/
│   ├── home_screen.dart       # Tab nav (Reader / Daily / My Words) + settings gear + account menu
│   ├── login_screen.dart      # Google + Anonymous (no email)
│   ├── pdf_reader_screen.dart # PDF upload → native rendering + text extraction
│   ├── daily_phrases_screen.dart # AI 5 phrases/day, save to words, theme, regenerate
│   ├── flashcard_screen.dart  # Tap-to-flip flashcards with progress bar
│   ├── settings_screen.dart   # App language + translate language picker
│   └── word_list_screen.dart  # Searchable word list with sort + delete
├── services/
│   ├── database_service.dart  # sqflite CRUD (SQLite)
│   ├── firebase_service.dart  # Firebase init, auth methods, Firestore backup/restore
│   └── translation_service.dart # DeepSeek API — multi-meaning translation + daily phrases
└── widgets/
    ├── add_word_dialog.dart   # Add word dialog with AI translate + meaning cards
    └── word_card.dart         # Word display card with review + delete buttons
```

### Data Flow

```
LoginScreen → [Google Sign-In / Email Password / Anonymous]
       ↓
  AuthGate checks Firebase auth state
       ↓
  HomeScreen (3 tabs: Reader · Daily · My Words)
       ↓
Reader → Native PDF view / Text extraction → Tap word → AddWordDialog
                                                     ↓
                                               DeepSeek API → meanings[]
                                                     ↓
                                               WordProvider → SQLite
Daily → DeepSeek API → 5 phrases → shared_preferences (today only)
My Words → SQLite → sort/search/delete
Account menu → Backup words to Firestore / Restore from Firestore
```

### Auth Flow

```
App start
  │
  ├─ Firebase init fails → local-only mode (fallback)
  │
  ├─ Firebase init OK → AuthProvider listens to authStateChanges()
  │     │
  │     ├─ No user → LoginScreen
  │     │     ├─ Google → one-tap sign-in → HomeScreen
  │     │     └─ Anonymous → warning dialog → HomeScreen (orange banner)
  │     │
  │     └─ User exists → HomeScreen
  │           ├─ Google user: cloud backup enabled
  │           └─ Anonymous user: orange warning banner, no cloud backup
```

### State Management

- **Provider** (ChangeNotifier pattern)
- `AuthProvider` holds: user, isSignedIn, isAnonymous, isLoading, error
- `WordProvider` holds: words, sortMode, state (idle/loading/loaded/error), error
- Full lifecycle: loading → loaded → error display

---

## 6. Firebase (Phase 4)

### Authentication Providers

| Provider | Status | Config |
|----------|--------|--------|
| Google | ✅ Enabled | OAuth 2.0, public name: "AI Vocab Builder", SHA-1 added |
| Anonymous | ✅ Enabled | Warning shown before sign-in |

### Firestore Structure

```
users/
  └── {uid}/
      └── words/
          └── {wordId}/
              ├── word: string
              ├── translation: string
              ├── example_source: string
              ├── example_target: string
              ├── source_lang: string
              ├── target_lang: string
              ├── is_reviewed: boolean
              ├── created_at: timestamp
              └── updated_at: timestamp
```

### Backup/Restore
- **Backup:** Uploads all local words to `users/{uid}/words/` on user tap
- **Restore:** Downloads all words, merges with local DB (dedup by word text)
- **Anonymous users:** Backup/restore disabled with explanation

**Without these rules, any authenticated user can read/write any other user's data.** They are enforced at Firebase's server level — no APK modification can bypass them.

---

## 7. Daily Phrases

### How it works
1. **On first open each day**: Calls DeepSeek API → generates 5 practical everyday phrases
2. **Stored in shared_preferences**: `daily_phrases_date` (YYYY-MM-DD) + `daily_phrases_data` (JSON)
3. **Same day**: Loads cached phrases from shared_preferences — no API call
4. **Next day**: Date mismatch → fresh API call → 5 new phrases
5. **Mark memorized**: Tap circle → green check → saves to shared_preferences for today only
6. **Language**: Default German (configurable via `daily_phrases_lang` in shared_preferences)

### Storage
```
SharedPreferences:
  daily_phrases_date  = "2026-06-07"
  daily_phrases_data  = '[{"phrase":"Guten Morgen","memorized":true}, ...]'
  daily_phrases_lang  = "de"
```

### Why no database
- Phrases reset daily — no value in persisting old ones
- shared_preferences is perfect for "today only" data
- Zero migration burden, zero schema changes

---

## 8. Database

### Schema (`words` table)

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | — |
| word | TEXT | NOT NULL | — |
| translation | TEXT | NOT NULL | — |
| example_source | TEXT | ✓ | — |
| example_target | TEXT | ✓ | — |
| source_lang | TEXT | NOT NULL | — |
| target_lang | TEXT | NOT NULL | — |
| is_reviewed | INTEGER | NOT NULL | 0 |
| created_at | TEXT | NOT NULL | — |
| updated_at | TEXT | NOT NULL | — |

### Migration Strategy

- `version: 1` in `openDatabase()`
- `onUpgrade` not yet implemented → uninstall app to reset DB during development

---

## 9. AI Translation (DeepSeek)

- **Model:** `deepseek-chat`
- **Endpoint:** `https://api.deepseek.com/v1/chat/completions`
- **API Key:** `sk-f42...48ba` in `lib/config/secrets.dart` (gitignored)
- **Temperature:** 0.3 (translation), 0.7 (daily phrases — more variety)
- **Max tokens:** 800 (translation), 300 (daily phrases)

### Translation prompt

- System: "You are a professional translator. Always respond with valid JSON only."
- User: "Translate `word` from `sourceLang` to `targetLang`. If multiple meanings exist, return ALL as array items. Each meaning must have its own example sentence."
- Response: `{ "meanings": [{ "meaning": "...", "example_source": "...", "example_target": "..." }] }`
- German auto-article: `article` field returned by DeepSeek, auto-prepended to word

### Daily phrases prompt

- System: "You are a language teacher. Respond with valid JSON only."
- User: "Generate 5 useful everyday phrases in `langName`. Pick from different daily situations."
- **Theme mode:** If user enters a theme (e.g. "at the doctor"), adds: "Focus on the theme: {theme}."
- Response: `{ "phrases": ["phrase 1", "phrase 2", "phrase 3", "phrase 4", "phrase 5"] }`

### New Daily Phrases features (June 2026)
- **Save to My Words (📌):** Each phrase has a pin icon → tap to save as a word in SQLite → appears in My Words tab for flashcard review
- **Regenerate (🔄):** Top-right button → fresh AI call → 5 new phrases (ignores today's cache)
- **Theme input:** Text field above phrases → type a topic → AI generates context-specific phrases

### Fallback

- If `meanings` array not present → falls back to old `translation` + `example_sentence_*` format
- If JSON parse fails → raw text returned as single meaning

---

## 10. Settings (Phase 5 — ✅ Complete)

- **App UI Language:** English / Deutsch / العربية toggle — wraps all app strings via `AppStrings.of(context)`
- **Translate To:** Target language dropdown for AI translation (default German)
- **Access:** ⚙️ gear icon in HomeScreen AppBar
- **Storage:** Language preference saved to shared_preferences

---

## 11. Testing

### Unit Tests (`test/word_test.dart`) — 11 tests
- Constructor defaults (isReviewed=false, auto timestamps)
- toMap correctness (all fields, null id exclusion)
- fromMap parsing (all fields, null handling, malformed dates)
- copyWith (full replacement, partial replacement, unchanged fields)
- Roundtrip (toMap → fromMap identity)

### Widget Tests (`test/word_card_test.dart`) — 11 tests
- Displays word, translation, language badges
- Displays example source + target
- Review toggle visibility + callback
- Delete button visibility + callback
- Null callbacks hide buttons
- Empty examples render without error

### Run tests
```bash
flutter test
```

---

## 12. Key Decisions

| Decision | Why |
|----------|-----|
| **sqflite** not Isar | Isar 3.1.0 unmaintained, incompatible with modern AGP |
| **Native file picker** not file_picker | file_picker had persistent Gradle/AGP/registrant issues |
| **MethodChannel** for platform code | Dart side never changes when adding iOS |
| **`any` constraint** on syncfusion | Auto-resolves to latest compatible version |
| **compileSdk 36** | Required by flutter_plugin_android_lifecycle |
| **shared_preferences for daily phrases** | Resets daily — no database overhead needed |
|| **Firebase Auth (2 methods)** | Google for zero-friction, Anonymous for quick access |
| **Firestore per-user structure** | `users/{uid}/words/` — standard Firebase security model |
| **secrets.dart gitignored** | `git pull` can never overwrite the real API key |
| **Anonymous restrictions** | No cloud backup — data loss risk clearly warned |
| **Daily phrases save from DB** | Bug fix: `isSaved` now queries SQLite, not stale SharedPreferences index (June 8, 2026) |
| **Export feature removed** | JSON export wrote to sandboxed directory — inaccessible to user. Removed entirely (June 8, 2026) |
| **Stable checkpoint** | Commit `3eb6435` — export removed, daily save working. `git checkout 3eb6435` to revert here. |

---

## 13. Build Commands

```bash
# Development (code-only changes — most common)
flutter run

# Development (package added/removed — pubspec.yaml changed)
flutter clean && flutter pub get && flutter run

# Build APK for sharing
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk

# Run tests
flutter test

# Nuclear clean (only if builds are broken — clears all caches)
flutter clean && rm -f pubspec.lock && rm -rf ~/.pub-cache/hosted/pub.dev/* && flutter pub get && flutter run
```

---

## 14. Security Audit (June 8, 2026)

Full audit of all 22 `.dart` source files.

### ✅ All Clear
| Area | Result |
|------|--------|
| **SQL Injection** | All 6 queries use `?` placeholders with `whereArgs` — immune |
| **HTTPS** | All network calls use `https://` |
| **Crash paths** | All `!` operators, null checks, and try/catch blocks reviewed — safe |
| **Controller disposal** | All 12 `TextEditingController`s properly disposed in `dispose()` |
| **Memory leaks** | No stream subscriptions without cancel, no dangling listeners |
| **Flutter best practices** | Material 3, Provider pattern, animations, tooltips — clean |

### 🔧 Fixes Applied
| # | Issue | Fix |
|---|-------|-----|
| 1 | **API key lost on `git pull`** — real key in `app_config.dart` gets overwritten by GitHub's placeholder | Moved real key to gitignored `lib/config/secrets.dart` |
| 2 | **`_toggleMemorized` compilation error** — called `_saveToPrefs(prefs)` but method takes no args | Removed dead code; method uses cached `_prefs` |
| 3 | **`SharedPreferences.getInstance()` on every tap** — triggered disk I/O unnecessarily | Cached as `_prefs` field — one read, reused |

### ⚠️ Noted (Low Priority)
| # | Finding | Risk |
|---|---------|------|
| 1 | `_extractTextInBackground` uses synchronous `readAsBytesSync()` — could briefly freeze UI on very large PDFs (>50 MB) | Low — most PDFs are small text documents |
| 2 | DeepSeek prompt includes raw user input | Low — single-user app, no shared content |

### Verdict
**Clean codebase.** No crash paths, no memory leaks, no injection vulnerabilities, no hardcoded credentials on GitHub. All 22 files follow consistent naming conventions.

---

## 15. Known Issues

| Issue | Status | Note |
|-------|--------|------|
| KGP warnings | ⚠️ Cosmetic | Does not block build |
| DB schema version 1 only | 🟡 Dev only | Uninstall app to reset during development |
| iOS file picker not implemented | ⏳ Future | MethodChannel ready, just add Swift handler |
| `flutter pub outdated` shows newer packages | ℹ️ Normal | `any` constraint auto-resolves latest |

---

## 16. GitHub SSH Key (Hermes Server)

The Hermes server pushes code to this repo via SSH:

| Detail | Value |
|--------|-------|
| Key type | **Ed25519** (modern, 256-bit security) |
| Key location | `~/.ssh/id_ed25519_vocab` (this server only) |
| GitHub title | `Hermes Server` |
| Added at | https://github.com/settings/keys |
| What it does | ✅ `git push` / `git pull` to `hsmoallem/AI-vocab-builder` ONLY |
| What it CAN'T do | ❌ Log into your account — ❌ See other repos — ❌ Delete repos — ❌ Change any settings |
| How to revoke | Delete from https://github.com/settings/keys → instant |

### Why SSH instead of tokens

| SSH Key | GitHub Token |
|---------|-------------|
| Scoped to ONE repo automatically | Must manually select repos (fine-grained) or ALL repos (classic) |
| Can't be used from any other machine | Token can be leaked and used anywhere |
| No expiration | Tokens expire and need rotation |
| Revocable with one click | Same, but easier to forget active tokens |

### How git push works from this server
```bash
GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519_vocab -o IdentitiesOnly=yes" git push origin main
```

The key never leaves this server. Your Mac uses its own authentication (whatever you set up locally). Both can push to the same repo independently.
