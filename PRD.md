# AI Vocab Builder — Product Requirements Document

> **Version:** 1.0.0  
> **Date:** June 7, 2026  
> **Status:** Phase 1-4 Complete, Phase 5-6 Planned  

---

## Project Identity

| Key | Value |
|-----|-------|
| **Product Name** | AI Vocab Builder |
| **App ID** | `com.vocabreader.ai_vocab_builder` |
| **Firebase Project** | `project-794490258159` (AI Vocab Builder) |
| **GitHub Repo** | `github.com/hsmoallem/AI-vocab-builder` |
| **DeepSeek API Key** | `sk-f425...48ba` in `lib/config/app_config.dart` |
| **Platform** | Android (iOS planned) |
| **Tech Stack** | Flutter 3.44.1, Dart ≥3.5.0, SQLite, Firebase, DeepSeek AI |

---

## 1. Product Vision

**AI Vocab Builder** turns any PDF into a personal language lesson. Users read German documents, tap words they don't know, and get instant AI-powered translations with multiple meanings, example sentences, and native pronunciation. Flashcards and daily phrases reinforce learning. Cloud backup keeps data safe across devices.

**Target Audience:** German learners who read German content (news, books, manuals, work documents).

**Core Value Proposition:** Learn vocabulary in context — from the documents you're already reading — instead of generic flashcard decks.

---

## 2. Features by Phase

### Phase 1 — Core Vocabulary (✅ Complete)
- SQlite database (sqflite)
- Add words manually
- DeepSeek AI translation (multiple meanings + examples)
- German article auto-detection (der/die/das)
- Word list with search, sort, delete
- Material 3 theme (light + dark)

### Phase 2 — PDF Reading (✅ Complete)
- Native Android file picker (Intent.ACTION_OPEN_DOCUMENT)
- PDF rendering via flutter_pdfview (Apache 2.0, hardware accelerated)
- Text extraction via syncfusion_flutter_pdf
- PDF ↔ Text toggle in reader toolbar
- Tap-to-add: select word in text → pre-filled Add Word dialog with auto-translation

### Phase 3 — Learning Tools (✅ Complete)
- Flashcards with flip animation and swipe navigation
- Daily Phrases: 5 AI-generated phrases per day
- Mark phrases as memorized, progress counter, trophy on completion
- **Save phrases to My Words (📌)** — pin any phrase to word database for flashcard review
- **Regenerate phrases (🔄)** — get 5 fresh AI phrases on demand (ignores daily cache)
- **Theme-based generation** — type a topic (e.g. "at the restaurant") → AI generates context phrases
- Native Text-to-Speech (Android TextToSpeech via MethodChannel)
- Tooltips on all icons
- Review toggle on word cards

### Phase 4 — Authentication & Cloud (✅ Complete)
- Google Sign-In (one tap)
- Anonymous sign-in (with data loss warning)
- Firestore cloud backup/restore for authenticated users
- Anonymous user restrictions (no cloud backup, orange warning banner)
- Graceful fallback when Firebase unavailable (app never bricks)

### Phase 5 — Settings & Preferences (⬜ Planned)
- Language pair picker (source → target)
- DeepSeek API key override (Settings screen)
- Theme toggle (light/dark/system)
- Daily phrases language picker
- Clear database
- Export/import words as JSON

### Phase 6 — Monetization (⬜ Planned)
- AdMob banner ads
- Interstitial ads (on word add)
- "Remove Ads" in-app purchase
- Free tier: full features + ads
- Paid tier: no ads

---

## 3. Technical Architecture

### Data Flow
```
User reads PDF → taps unknown word → DeepSeek translates → saved to SQLite
                                                    ↓
                                          Flashcard review + TTS
                                                    ↓
                                          Firestore cloud backup (optional)
```

### Local Storage
- **SQLite** (sqflite): words, translations, examples, review status
- **SharedPreferences**: daily phrases (today only), settings, language preferences

### Cloud Storage
- **Firestore**: `users/{uid}/words/` — one document per word
- **Backup**: one-tap upload all local words
- **Restore**: one-tap download + merge (dedup by word text)

### Authentication
- Firebase Auth with three providers
- Auth gate in main.dart routes to LoginScreen or HomeScreen
- Anonymous users get orange warning banner and no cloud access

### AI Integration
- **Provider:** DeepSeek (`deepseek-chat` model)
- **Translation:** System prompt → returns structured JSON with meanings array
- **Daily Phrases:** System prompt → returns 5 everyday phrases in target language
- **Temperature:** 0.3 for translation (precision), 0.7 for phrases (variety)

---

## 4. User Flows

### First-Time User
```
Open app → Login Screen
  ├─ "Sign in with Google" → one tap → Home Screen
  ├─ "Sign in with Email" → register → Home Screen
  └─ "Continue without account" → warning → Home Screen (anonymous)
```

### Main Loop
```
Home Screen (3 tabs)
  ├─ Reader tab → pick PDF → read → tap word → translate → save
  ├─ Daily tab → view 5 phrases → tap to memorize → trophy
  └─ My Words tab → search/sort/delete → tap for flashcard review
```

### Returning User (signed in)
```
Open app → AuthGate checks Firebase → Home Screen
  ├─ Account menu → Backup now / Restore / Sign out
  └─ Orange banner if anonymous
```

---

## 5. Design Principles

| Principle | Implementation |
|-----------|---------------|
| **Offline-first** | All features work without internet (except AI translation + cloud sync) |
| **Zero friction** | Google Sign-In = one tap; Anonymous = one warning click |
| **Native feel** | Native file picker, native TTS, native PDF renderer — no web-like behavior |
| **Data safety** | Anonymous users warned; cloud backup available to signed-in users |
| **Simple stack** | Provider (not BLoC/Riverpod), sqflite (not Isar), MethodChannel (not packages) |

---

## 6. Known Limitations

- iOS file picker not yet implemented (MethodChannel ready, needs Swift handler)
- DB migration not handled (uninstall to reset during development)
- DeepSeek API key embedded in app config (backend proxy needed for Play Store)
- No offline AI translation (requires internet for DeepSeek calls)
- Single-user local database (Firebase sync is manual backup, not real-time)

---

## 7. Future Roadmap

| Priority | Feature | Complexity |
|----------|---------|------------|
| P0 | Settings screen (Phase 5) | Low |
| P1 | AdMob integration (Phase 6) | Medium |
| P2 | iOS support | Medium |
| P3 | Backend proxy for DeepSeek key | Medium |
| P4 | Real-time Firestore sync | High |
| P5 | Spaced repetition algorithm | High |
| P6 | OCR (scan physical documents) | Very High |
