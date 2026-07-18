# AI Vocab Builder — Technical Documentation

> Last updated: July 18, 2026 — v1.2 (bulk import + TTS everywhere + Firebase auth)

---

## 1. Project Tokens & IDs

| Token / ID | Value | Location |
|------------|-------|----------|
| **DeepSeek API Key** | `sk-f42...48ba` | **Proxy server only** (`/home/houssam/deepseek-proxy/proxy.py` on Contabo) — never in repo/APK |
| **Proxy URL** | `http://13.140.134.57:9000/translate` | `lib/services/translation_service.dart` |
| **Proxy Token** | `vocab-builder-shared-secret-2026` | App + proxy (shared secret, speed bump) |
| **Rate Limit** | 30 req/min per IP | Flask-Limiter on proxy |
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
| `http` | ^1.2.0 | HTTP client (proxy calls) |
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
| `flutter_launcher_icons` | ^0.14.4 | Generate Android launcher icon |
| `flutter_native_splash` | ^2.4.1 | Generate Android native splash screen |

### Assets

| Asset | Purpose |
|-------|---------|
| `assets/icon/app_icon.png` | App launcher icon (blue circuit-board "A") |
| `assets/splash_screen.png` | Native splash screen image (VocabView logo on dark bg) |

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
│   ├── app_config.dart        # App constants (proxy URL, token — no API key)
│   ├── app_strings.dart       # Localization strings (English + Deutsch + Arabic)
│   ├── secrets.dart           # gitignored, NO LONGER IMPORTED by any code
│   └── theme.dart             # Material 3 light + dark themes
├── models/
│   └── word.dart              # Word data model (id, word, translation, examples, etc.)
├── providers/
│   ├── auth_provider.dart     # ChangeNotifier — Firebase auth state (Google/Anon)
│   ├── locale_provider.dart   # ChangeNotifier — UI language + translate-to language
│   └── word_provider.dart     # ChangeNotifier — CRUD, sort, search, translate
├── screens/
│   ├── home_screen.dart       # Tab nav (Reader / Daily / My Words) + settings gear + account menu
│   ├── login_screen.dart      # Google + Anonymous (book icon header)
│   ├── pdf_reader_screen.dart # PDF upload → native rendering + text extraction
│   ├── daily_phrases_screen.dart # AI 5 phrases/day, phrase language dropdown, save, theme, regenerate
│   ├── flashcard_screen.dart  # Tap-to-flip flashcards with progress bar + 🔊 TTS
   ├── bulk_import_screen.dart # Paste word list → batch translate → auto-save
│   ├── settings_screen.dart   # App language + translate-to language picker
│   └── word_list_screen.dart  # Searchable word list with sort + delete
│   ├── services/
│   │   ├── database_service.dart  # sqflite CRUD (SQLite)
│   │   ├── firebase_service.dart  # Firebase init, auth methods, Firestore backup/restore
│   │   ├── tts_service.dart       # Native Android TTS via MethodChannel
│   │   └── translation_service.dart # Proxy client — Firebase ID token, X-App-Token fallback
└── widgets/
    ├── add_word_dialog.dart   # Add word dialog with AI translate + meaning cards
    └── word_card.dart         # Word display card with review + delete buttons
```

### Data Flow

```
LoginScreen → [Google Sign-In / Anonymous]
       ↓
  AuthGate checks Firebase auth state
       ↓
  HomeScreen (3 tabs: Reader · Daily · My Words)
       ↓
Reader → Native PDF view / Text extraction → Tap word → AddWordDialog
                                                     ↓
                                               Proxy → DeepSeek → meanings[]
                                                     ↓
                                               WordProvider → SQLite
Daily → Proxy → DeepSeek → 5 phrases → shared_preferences (today only)
        ↑ phrase language dropdown (persisted separately)
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
- `LocaleProvider` holds: locale (UI language), targetLang (translate-to language)
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

### Firestore Security Rules (DEPLOYED ✅)

```
match /users/{userId}/words/{wordId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

**Without these rules, any authenticated user can read/write any other user's data.** They are enforced at Firebase's server level — no APK modification can bypass them.

---

## 7. AI Translation — Proxy Architecture

The DeepSeek API key lives **only on the proxy server** — never in the repo, never in the APK.

```
┌──────────┐     HTTP POST      ┌─────────────────┐     HTTPS      ┌────────────┐
│  App     │ ─── {word,lang, ──→│  Flask Proxy     │ ─── prompt + ─→│  DeepSeek  │
│  (APK)   │     mode, token}   │  :9000 (Contabo) │    key        │  API       │
│          │ ←── {meanings[]} ──│                  │ ←── JSON ─────│            │
└──────────┘                    └─────────────────┘               └────────────┘
```

### What the app sends (mode: translate)
```json
{
  "word": "Haus",
  "sourceLang": "de",
  "targetLang": "en",
  "mode": "translate"
}
```

### What the app sends (mode: phrases)
```json
{
  "sourceLang": "de",
  "targetLang": "de",
  "mode": "phrases",
  "theme": "at the doctor"
}
```

### What the proxy does
1. Verifies Firebase ID token (`Authorization: Bearer <token>`) — cryptographically validated via Google's JWKS
2. Falls back to legacy `X-App-Token` shared secret for anonymous/signed-out sessions
3. Enforces per-UID rate limit (10 req/min) + per-IP backstop (30 req/min)
4. Builds the prompt server-side with language names and formatting instructions
5. Forwards to DeepSeek with the real API key
6. Parses DeepSeek's raw JSON response
7. Returns structured JSON to the app

### Security properties
- **Decompiling the APK** yields only: proxy URL + shared token
- **No API key** anywhere in the codebase
- **No open LLM relay** — proxy builds prompts, app can't inject custom messages/models/temperature
- **Firebase ID token** is cryptographically verified — UID cannot be forged
- **Rate limited** — 10 req/min per UID + 30 req/min per IP — one user can't abuse the API
- **App token** is a speed bump (extractable from APK) — real security is at server level

### Proxy server
- Location: Contabo VPS (`13.140.134.57`)
- File: `/home/houssam/deepseek-proxy/proxy.py`
- Process: gunicorn (127.0.0.1:9001) + socat (0.0.0.0:9000)
- Start: `FIREBASE_PROJECT_ID=project-794490258159 bash /home/houssam/deepseek-proxy/start.sh`
- Port: 9000 (HTTP)

---

## 8. Daily Phrases

### How it works
1. **On first open each day**: Calls proxy → DeepSeek generates 5 practical everyday phrases
2. **Stored in shared_preferences**: `daily_phrases_date` (YYYY-MM-DD) + `daily_phrases_data` (JSON)
3. **Same day**: Loads cached phrases from shared_preferences — no API call
4. **Next day**: Date mismatch → fresh API call → 5 new phrases
5. **Mark memorized**: Tap circle → green check → persists for today only
6. **Phrase language dropdown**: Choose which language phrases are generated in (default: German)
7. **Same-language warning**: Shows warning when phrase language == translate-to language
8. **Save to My Words (📌)**: Translates phrase from {phraseLang} → {targetLang}, saves to SQLite
9. **Regenerate (🔄)**: Top-right button → fresh AI call → 5 new phrases (ignores today's cache)
10. **Theme input**: Text field above phrases → type a topic → AI generates context-specific phrases

### Storage
```
SharedPreferences:
  daily_phrases_date       = "2026-06-08"
  daily_phrases_data       = '[{"phrase":"Guten Morgen","memorized":true}, ...]'
  daily_phrase_language    = "de"     (separate from translate_target_lang)
  daily_phrases_lang       = "de"     (legacy key, still read as fallback)
```

### Language flow
```
1. User picks phrase language in dropdown (e.g. Français)
2. App sends {sourceLang: "fr", mode: "phrases"} to proxy
3. Proxy builds prompt: "Generate 5 useful everyday phrases in French..."
4. 5 French phrases appear on screen
5. User taps 📌 → app sends {word: "Bonjour", sourceLang: "fr", targetLang: "en"}
6. Translation appears with English meaning + example
7. Word saved to SQLite with sourceLang=fr, targetLang=en
```

### Why no database
- Phrases reset daily — no value in persisting old ones
- shared_preferences is perfect for "today only" data
- Zero migration burden, zero schema changes

---

## 9. Database

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

## 10. Settings (Phase 5 — ✅ Complete)

- **App UI Language:** English / Deutsch / العربية toggle — wraps all app strings via `AppStrings.of(context)`
- **Translate To:** Target language dropdown for AI translation (default depends on UI language)
- **Phrase Language:** Separate dropdown on Daily screen — language phrases are generated in
- **Access:** ⚙️ gear icon in HomeScreen AppBar
- **Storage:** All preferences saved to shared_preferences under separate keys

### Persistence keys (all separate — never conflict)

| Key | Purpose | Default |
|-----|---------|---------|
| `app_language` | UI language (en/de/ar) | `en` |
| `translate_target_lang` | Translation target language | `en` |
| `daily_phrase_language` | Daily phrase generation language | `de` |
| `daily_phrases_lang` | Legacy phrase language key (fallback) | `de` |

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
| **Firebase Auth (2 methods)** | Google for zero-friction, Anonymous for quick access |
| **Firestore per-user structure** | `users/{uid}/words/` — standard Firebase security model |
| **Proxy for DeepSeek key** | Key never in APK — decompiling yields only proxy URL |
| **Server-side prompt building** | Proxy is not an open LLM relay — app can't inject custom prompts |
| **Per-IP rate limiting** | Prevents API abuse — 30 req/min per user |
| **X-App-Token shared secret** | Speed bump — real security at server level |
| **Separate persistence keys** | `daily_phrase_language` ≠ `translate_target_lang` — never overwrite |
| **AppStrings.targetLanguages** | Single source of truth — dropdowns always in sync |
| **Daily phrases save from DB** | Bug fix: `isSaved` queries SQLite, not stale SharedPreferences index |
| **Export feature removed** | JSON export wrote to sandboxed directory — inaccessible to user |
| **All colors via ColorScheme tokens** | Dark theme fully readable — no hardcoded `Colors.*` values |
| **Anonymous restrictions** | No cloud backup — data loss risk clearly warned |
| **Login icon header** | `Icons.menu_book_rounded` — simple, clean, no external image dependency |
| **Native splash only** | `flutter_native_splash` — no Flutter splash widget, minimal boot delay |
| **Stable checkpoint** | Tag `stable-2026-06-08` → `v1.0`. `git checkout stable-2026-06-08` to revert here. |

---

## 13. Build Commands

```bash
# Development (code-only changes — most common)
flutter run

# Development (package added/removed — pubspec.yaml changed)
flutter clean && flutter pub get && flutter run

# Generate app launcher icon (after changing assets/icon/app_icon.png)
dart run flutter_launcher_icons

# Generate native splash screen (after changing assets/splash_screen.png)
dart run flutter_native_splash:create

# Build release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Build debug APK for sharing
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk

# Run tests
flutter test

# Nuclear clean (only if builds are broken — clears all caches)
flutter clean && rm -f pubspec.lock && rm -rf ~/.pub-cache/hosted/pub.dev/* && flutter pub get && flutter run
```

---

## 14. Security

### Architecture
| Layer | Protection |
|-------|-----------|
| **API key** | On proxy server only — never in repo, never in APK |
| **Proxy** | Server-side prompt building — not an open LLM relay |
| **Proxy auth** | Firebase ID token (JWT verified via Google JWKS) — fallback to X-App-Token for anonymous |
| **Rate limit** | 10 req/min per UID + 30 req/min per IP backstop |
| **Firestore** | Per-user rules deployed — `request.auth.uid == userId` |
| **Database** | All queries use `?` placeholders — SQL injection immune |
| **UI** | All controllers disposed, no memory leaks, no dangling listeners |

### What's in the APK (safe to share)
- Proxy URL (`http://13.140.134.57:9000`)
- Shared token (`vocab-builder-shared-secret-2026`)
- No DeepSeek key, no Firebase admin credentials, no user data

### What's NOT in the APK
- DeepSeek API key (on server only)
- Firebase service account credentials
- Any user-specific data

---

## 15. Known Issues

| Issue | Status | Note |
|-------|--------|------|
| KGP warnings | ⚠️ Cosmetic | Does not block build |
| DB schema version 1 only | 🟡 Dev only | Uninstall app to reset during development |
| iOS file picker not implemented | ⏳ Future | MethodChannel ready, just add Swift handler |
| `flutter pub outdated` shows newer packages | ℹ️ Normal | `any` constraint auto-resolves latest |
| Proxy uses HTTP (no HTTPS) | 🟡 Pre-Prod | Add domain + Let's Encrypt before Play Store |
| Hardcoded proxy IP | 🟡 Pre-Prod | Replace with domain before Play Store |

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
