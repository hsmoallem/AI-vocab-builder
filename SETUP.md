# AI Vocab Builder — Setup & Workflow Guide

> **Project:** AI Vocab Builder  
> **App ID:** `com.vocabreader.ai_vocab_builder`  
> **Firebase:** `project-794490258159` (AI Vocab Builder)  
> **GitHub:** [github.com/hsmoallem/AI-vocab-builder](https://github.com/hsmoallem/AI-vocab-builder)  
> **DeepSeek Key:** `sk-b7f...b6d8` in `lib/config/app_config.dart`  
> **Team:** Houssam (Mac) + Hermes (code)  
> **Workflow:** You create project → GitHub → I write code → you run  
> **Tech:** Flutter + Dart (Android now, iOS later)  
> **IDE:** Android Studio  

---

## 1. How We Work

```
┌──────────────────┐         ┌──────────────────┐         ┌──────────┐
│  You (Mac)       │         │  GitHub           │         │  Server  │
│  Android Studio  │◀───────▶│  (shared repo)    │◀───────▶│  Hermes  │
│  Flutter plugin  │         │                   │         │  (code)  │
│  Emulator/Phone  │         │                   │         │          │
└──────────────────┘         └──────────────────┘         └──────────┘

1. You install Flutter + Android Studio + create project (one-time)
2. You push to GitHub
3. I clone, write all code, push back
4. You pull → click Run ▶ → app on your phone
```

---

## 2. Development Phases

| Phase | What | Status |
|-------|------|--------|
| **Phase 0** | Environment setup (Flutter, Android Studio, GitHub) | ✅ Complete |
| **Phase 1** | sqflite DB, Add Word + DeepSeek, Word List, sort, delete | ✅ Complete |
| **Phase 2** | PDF picker (native), native rendering (flutter_pdfview), text extraction, tap-word | ✅ Complete |
| **Phase 3** | Flashcards + review flow + Daily Phrases + TTS | ✅ Complete |
| **Phase 4** | Firebase Auth (Google + Email + Anonymous) + Firestore cloud backup | ✅ Complete |
| **Phase 5** | Settings, language picker, theme toggle | ⬜ |
| **Phase 6** | AdMob ads + Remove Ads IAP | ⬜ |

---

## 3. Current Feature Set

### Auth (Phase 4 — ✅ Complete)
- **Google Sign-In** — one tap, uses phone's Google account
- **Email/Password** — register, login, forgot password
- **Anonymous** — skip login, warning about no cloud backup

### Core (Phases 1-3 — ✅ Complete)
- **3-tab navigation:** Reader · Daily Phrases · My Words
- **Add word:** Enter any word → AI translates via DeepSeek
- **Multi-meaning translation:** Separate entries with unique examples
- **German article detection:** `der`/`die`/`das` auto-detected
- **Sort & search:** Alphabetical or newest-first, live search
- **Swipe-to-delete:** With confirmation dialog
- **Flashcards:** Tap to flip, swipe to navigate, progress bar
- **PDF Reader:** Native rendering + text extraction, tap-to-add
- **Daily Phrases:** AI generates 5 phrases/day, mark as memorized
- **Text-to-Speech:** Native Android TTS (no external package)
- **Cloud Backup:** Save/restore words to Firestore

### Current Technical Stack

| Tool | Actual |
|------|--------|
| Database | **sqflite** (SQLite) |
| File picker | **Native Android** (MethodChannel) |
| PDF | **flutter_pdfview** (render) + **syncfusion_flutter_pdf** (text) |
| State | **Provider** |
| AI | **DeepSeek** (multi-meaning + daily phrases) |
| Auth | **Firebase** (Google, Email, Anonymous) |
| Cloud DB | **Firestore** (backup/restore) |
| TTS | **Native Android** TextToSpeech (MethodChannel) |
| Tests | **22 tests** (11 model + 11 widget) |

> Full details: [`TECHNICAL.md`](TECHNICAL.md)

---

## 4. Your Only Job Per Phase

```bash
cd ~/StudioProjects/ai_vocab_builder
git pull          # get latest code from GitHub
flutter run       # run on phone
```

**When to add `flutter clean`:**

| Command | When |
|---------|------|
| `git pull && flutter run` | **Most updates** — code changes only, no new packages |
| `git pull && flutter clean && flutter pub get && flutter run` | **New package added** (pubspec.yaml changed) |

> **Simple rule:** If I add/remove a package, I'll tell you to use the long command.  
> If I say "(No flutter clean needed — no packages changed)", just pull and run.

---

## 5. Project Tokens & Config

| Token / File | Where | Notes |
|-------------|-------|-------|
| **DeepSeek API Key** | `lib/config/app_config.dart` | `sk-b7f...b6d8` — $5 = ~50k translations |
| **google-services.json** | `android/app/` | Firebase config — **gitignored**, never committed |
| **Firebase Project** | [console.firebase.google.com](https://console.firebase.google.com) | `project-794490258159` |
| **SSH Key (server)** | `~/.ssh/id_ed25519_vocab` | Hermes server pushes to GitHub |

---

## 6. Firebase Setup (Already Done ✅)

All three auth providers enabled in Firebase Console:
- **Google** — OAuth client for `com.vocabreader.ai_vocab_builder`
- **Email/Password** — email enumeration protection enabled
- **Anonymous** — temporary accounts

Firestore database created in `eur3` (Europe) region.

---

## 7. DeepSeek API (Already Done ✅)

1. Key created at [platform.deepseek.com](https://platform.deepseek.com)
2. Stored in `lib/config/app_config.dart` as `deepseekApiKey`
3. Translation endpoint: `https://api.deepseek.com/v1/chat/completions`
4. Model: `deepseek-chat`

---

## 8. AdMob Setup (Phase 6 — Not Started)

1. https://admob.google.com/ → Sign up
2. Create app → Android → AI Vocab Builder
3. Create ad units: Banner + Interstitial
4. Save Ad Unit IDs for Phase 6
