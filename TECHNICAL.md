# Vocab Builder — Technical Documentation

> Last updated: June 7, 2026

---

## 1. Environment

| Tool | Version |
|------|---------|
| Flutter SDK | 3.44.1 (stable channel) |
| Dart SDK | ≥3.5.0 |
| Android SDK | compileSdk 36, minSdk 21 |
| Kotlin | 2.3.20 |
| Gradle | AGP 9.0.1 |
| Java | JDK 17 |
| IDE | Android Studio + Flutter plugin |

---

## 2. Packages (pubspec.yaml)

### Runtime dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `sqflite` | ^2.4.0 | Local SQLite database |
| `path` | ^1.9.0 | File path utilities |
| `provider` | ^6.1.0 | State management |
| `http` | ^1.2.0 | HTTP client (DeepSeek API) |
| `shared_preferences` | ^2.3.0 | Key-value settings storage |
| `path_provider` | ^2.1.0 | Platform-agnostic paths |
| `syncfusion_flutter_pdf` | any | PDF text extraction |
| `flutter_pdfview` | any | Native PDF rendering (Apache 2.0, 2M+ downloads) |

### Dev dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | SDK | Unit + widget testing |
| `flutter_lints` | any | Code linting |

---

## 3. File Picker — Native (No Package)

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

## 4. Architecture

```
lib/
├── config/
│   ├── app_config.dart        # DeepSeek API key, app constants
│   └── theme.dart             # Material 3 light + dark themes
├── models/
│   └── word.dart              # Word data model (id, word, translation, examples, etc.)
├── providers/
│   └── word_provider.dart     # ChangeNotifier — CRUD, sort, search, translate
├── screens/
│   ├── home_screen.dart       # Tab navigation (Reader / Daily / My Words) + FAB
│   ├── pdf_reader_screen.dart # PDF upload → native rendering + text extraction
│   ├── daily_phrases_screen.dart # AI-generated 5 phrases/day, mark memorized
│   ├── flashcard_screen.dart  # Tap-to-flip flashcards with progress bar
│   └── word_list_screen.dart  # Searchable word list with sort + delete
├── services/
│   ├── database_service.dart  # sqflite CRUD (SQLite)
│   └── translation_service.dart # DeepSeek API — multi-meaning translation + daily phrases
└── widgets/
    ├── add_word_dialog.dart   # Add word dialog with AI translate + meaning cards
    └── word_card.dart         # Word display card with review + delete buttons
```

### Data Flow

```
User taps + → AddWordDialog → DeepSeek API → TranslationResult (meanings[])
                                       ↓
                                 User reviews meanings + examples
                                       ↓
                                 WordProvider.addWord() → DatabaseService.insertWord()
                                       ↓
                                 WordCard displayed in WordListScreen

Daily tab opens → DailyPhrasesScreen → DeepSeek API → 5 phrases
                                       ↓
                                 Stored in shared_preferences (today only)
                                       ↓
                                 Tap circle to mark memorized → resets tomorrow
```

### State Management

- **Provider** (ChangeNotifier pattern)
- `WordProvider` holds:
  - `words` — List<Word>
  - `sortMode` — newestFirst / alphabetical
  - `state` — idle / loading / loaded / error
  - `error` — String? for error messages
- Full lifecycle: loading indicator → loaded list → error display

---

## 5. Daily Phrases

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

## 6. Database

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

## 7. AI Translation (DeepSeek)

- **Model:** `deepseek-chat`
- **Endpoint:** `https://api.deepseek.com/v1/chat/completions`
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
- Response: `{ "phrases": ["phrase 1", "phrase 2", "phrase 3", "phrase 4", "phrase 5"] }`

### Fallback

- If `meanings` array not present → falls back to old `translation` + `example_sentence_*` format
- If JSON parse fails → raw text returned as single meaning

---

## 8. Testing

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

## 9. Key Decisions

| Decision | Why |
|----------|-----|
| **sqflite** not Isar | Isar 3.1.0 unmaintained, incompatible with modern AGP |
| **Native file picker** not file_picker | file_picker had persistent Gradle/AGP/registrant issues |
| **MethodChannel** for platform code | Dart side never changes when adding iOS |
| **`any` constraint** on syncfusion | Auto-resolves to latest compatible version |
| **compileSdk 36** | Required by flutter_plugin_android_lifecycle |
| **shared_preferences for daily phrases** | Resets daily — no database overhead needed |
| **No translation for daily phrases** | User's request — just phrases in target language |
| **No Firebase yet** | Phase 4 — adds auth + cloud sync |
| **No AdMob yet** | Phase 6 — monetization |

---

## 10. Build Commands

```bash
# Development
flutter run

# Build APK for sharing
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk

# Run tests
flutter test

# Nuclear clean (if build issues)
flutter clean && rm -f pubspec.lock && flutter pub get && flutter run
```

---

## 11. Known Issues

| Issue | Status | Note |
|-------|--------|------|
| KGP warnings | ⚠️ Cosmetic | Does not block build |
| DB schema version 1 only | 🟡 Dev only | Uninstall app to reset during development |
| iOS file picker not implemented | ⏳ Future | MethodChannel ready, just add Swift handler |
| `flutter pub outdated` shows newer packages | ℹ️ Normal | `any` constraint auto-resolves latest |

---

## 12. GitHub SSH Key (Hermes Server)

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
