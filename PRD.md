# AI Vocab Builder — Product Requirements Document

> **Version:** 1.0.0  
> **Date:** June 8, 2026  
> **Status:** Phases 1-5 Complete, Phase 6 Planned  
> **Stable tag:** `v1.0` / `stable-2026-06-08`

---

## Project Identity

| Key | Value |
|-----|-------|
| **Product Name** | AI Vocab Builder |
| **App ID** | `com.vocabreader.ai_vocab_builder` |
| **Firebase Project** | `project-794490258159` (AI Vocab Builder) |
| **GitHub Repo** | `github.com/hsmoallem/AI-vocab-builder` |
| **DeepSeek API** | Via secure proxy server (key never in APK) |
| **Platform** | Android (iOS planned) |
| **Tech Stack** | Flutter 3.44.1, Dart ≥3.5.0, SQLite, Firebase, DeepSeek AI (proxy) |

---

## 1. Product Vision

**AI Vocab Builder** turns any PDF into a personal language lesson. Users read documents, tap words they don't know, and get instant AI-powered translations with multiple meanings, example sentences, and native pronunciation. Flashcards and daily phrases reinforce learning. Cloud backup keeps data safe across devices.

**Target Audience:** Language learners who read content in their target language (news, books, manuals, work documents).

**Core Value Proposition:** Learn vocabulary in context — from the documents you're already reading — instead of generic flashcard decks.

---

## 2. Features by Phase

### Phase 1 — Core Vocabulary (✅ Complete)
- SQlite database (sqflite)
- Add words manually
- DeepSeek AI translation (multiple meanings + examples)
- German article auto-detection (der/die/das)
- Word list with search, sort, delete
- Material 3 theme (light + dark, fully colorScheme-token based)

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
- Save phrases to My Words — translates from phrase language → target language
- Regenerate phrases — get 5 fresh AI phrases on demand
- Theme-based generation — type a topic (e.g. "at the restaurant")
- Native Text-to-Speech (Android TextToSpeech via MethodChannel)
- Tooltips on all icons
- Review toggle on word cards

### Phase 4 — Authentication & Cloud (✅ Complete)
- Google Sign-In (one tap)
- Anonymous sign-in (with data loss warning)
- Firestore cloud backup/restore for authenticated users
- Anonymous user restrictions (no cloud backup, orange warning banner)
- Graceful fallback when Firebase unavailable (app never bricks)
- Per-user Firestore security rules deployed

### Phase 5 — Settings & Preferences (✅ Complete)
- UI language picker (English / Deutsch / العربية)
- Translate-to language picker for AI translation
- Phrase language dropdown on Daily screen (separate from translate-to)
- Same-language warning when phrase lang == translate lang
- Settings accessible from ⚙️ gear icon in AppBar

### Phase 5.5 — Security & Branding (✅ Complete)
- DeepSeek API key moved to proxy server — never in APK
- Server-side prompt building — proxy is not an open LLM relay
- Token-based & Firebase-ID-token auth + per-IP / per-user rate limiting
- App launcher icon (blue circuit-board "A")
- Native Android splash screen (VocabView logo on dark background)
- Network security config (cleartext HTTP to proxy IP only)

### Phase 6 — Monetization (⬜ Planned)
- **Free tier:** Full features + AdMob banner ads + occasional interstitials
- **Premium:** No ads, 3-day free trial, then subscription
  - Monthly: **$4/month** (auto-renews)
  - 6 months: **$15** ($2.50/mo — save 37%)
  - Yearly: **$25** ($2.08/mo — save 48%)
- Google Play Billing (subscriptions managed by Google)
- No ad frequency changes during trial

---

## 3. Technical Architecture

### Security Architecture
```
┌──────────┐     HTTP POST      ┌─────────────────┐     HTTPS      ┌────────────┐
│  App     │ ─── {word,lang, ──→│  Flask Proxy     │ ─── prompt + ─→│  DeepSeek  │
│  (APK)   │     mode, token}   │  (private VPS)   │    key        │  API       │
│          │ ←── {meanings[]} ──│                  │ ←── JSON ─────│            │
└──────────┘                    └─────────────────┘               └────────────┘
```

- API key never in APK — decompiling yields only proxy URL
- App sends structured data only (word, languages, mode) — cannot inject custom prompts
- Rate limiting protects against abuse
- Per-user Firestore isolation via security rules

### Data Flow
```
User reads PDF → taps unknown word → Proxy → DeepSeek translates → saved to SQLite
                                                    ↓
                                          Flashcard review + TTS
                                                    ↓
                                          Firestore cloud backup (optional)
```

### Local Storage
- **SQLite** (sqflite): words, translations, examples, review status
- **SharedPreferences**: daily phrases (today only), settings, language preferences
  - Keys: `app_language`, `translate_target_lang`, `daily_phrase_language` (all separate)

### Cloud Storage
- **Firestore**: `users/{uid}/words/` — one document per word
- **Backup**: one-tap upload all local words
- **Restore**: one-tap download + merge (dedup by word text)

### Authentication
- Firebase Auth with two providers
- Auth gate in main.dart routes to LoginScreen or HomeScreen
- Anonymous users get orange warning banner and no cloud access

---

## 4. User Flows

### First-Time User
```
Open app → Login Screen
  ├─ "Sign in with Google" → one tap → Home Screen
  └─ "Continue without account" → warning → Home Screen (anonymous)
```

### Main Loop
```
Home Screen (3 tabs)
  ├─ Reader tab → pick PDF → read → tap word → translate → save
  ├─ Daily tab → view 5 phrases → pick language → tap to memorize → save to words
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
| **Security by design** | API key on proxy server, server-side prompt building, per-user DB isolation |
| **Simple stack** | Provider (not BLoC/Riverpod), sqflite (not Isar), MethodChannel (not packages) |
| **Dark theme** | All colors via Material 3 ColorScheme tokens — readable in both modes |

---

## 6. Known Limitations

- iOS file picker not yet implemented (MethodChannel ready, needs Swift handler)
- DB migration not handled (uninstall to reset during development)
- No offline AI translation (requires internet for proxy calls)
- Single-user local database (Firebase sync is manual backup, not real-time)

---

## 7. Future Roadmap

| Priority | Feature | Complexity |
|----------|---------|------------|
| P0 | AdMob integration (Phase 6) | Medium |
| P1 | iOS support | Medium |
| P2 | ~~HTTPS proxy + custom domain~~ (done) | ~~Medium~~ |
| P3 | Real-time Firestore sync | High |
| P4 | Spaced repetition algorithm | High |
| P5 | OCR (scan physical documents) | Very High |
