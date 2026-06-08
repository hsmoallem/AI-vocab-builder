# AI Vocab Builder — Setup & Workflow Guide

> **Project:** AI Vocab Builder  
> **App ID:** `com.vocabreader.ai_vocab_builder`  
> **Firebase:** `project-794490258159` (AI Vocab Builder)  
> **GitHub:** [github.com/hsmoallem/AI-vocab-builder](https://github.com/hsmoallem/AI-vocab-builder)  
| **DeepSeek Key** | In `lib/config/secrets.dart` (gitignored, never committed) |
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
| **Phase 0** | Environment setup (Flutter, Android Studio, GitHub, Firebase, DeepSeek) | ✅ Complete |
| **Phase 1** | sqflite DB, Add Word + DeepSeek, Word List, sort, delete | ✅ Complete |
| **Phase 2** | PDF picker (native), native rendering (flutter_pdfview), text extraction, tap-word | ✅ Complete |
| **Phase 3** | Flashcards + review flow + Daily Phrases + TTS + Save to My Words + Theme | ✅ Complete |
| **Phase 4** | Firebase Auth (Google + Anonymous) + Firestore cloud backup | ✅ Complete |
| **Phase 5** | Settings, language picker (EN/DE/AR) | ✅ Complete |
| **Phase 6** | AdMob ads + Remove Ads IAP | ⬜ |

---

## 3. Current Feature Set

### Auth (Phase 4 — ✅ Complete)
- **Google Sign-In** — one tap, uses phone's Google account
- **Anonymous** — skip login, warning about no cloud backup (orange banner)
- **Cloud Backup:** One-tap backup/restore all words to Firestore

### Core (Phases 1-3 — ✅ Complete)
- **3-tab navigation:** Reader · Daily Phrases · My Words
- **Add word:** Enter any word → AI translates via DeepSeek
- **Multi-meaning translation:** Separate entries with unique examples
- **German article detection:** `der`/`die`/`das` auto-detected
- **Sort & search:** Alphabetical or newest-first, live search
- **Swipe-to-delete:** With confirmation dialog
- **Flashcards:** Tap to flip, swipe to navigate, progress bar
- **PDF Reader:** Native rendering + text extraction, tap-to-add
- **Daily Phrases:** AI generates 5 phrases/day, mark as memorized, **save to My Words**, **theme-based generation** (e.g. "at the restaurant"), **regenerate new 5** button
- **Text-to-Speech:** Native Android TTS (no external package)

### Current Technical Stack

| Tool | Actual |
|------|--------|
| Database | **sqflite** (SQLite) |
| File picker | **Native Android** (MethodChannel) |
| PDF | **flutter_pdfview** (render) + **syncfusion_flutter_pdf** (text) |
| State | **Provider** |
| AI | **DeepSeek** (multi-meaning + daily phrases + theme prompts) |
| Auth | **Firebase** (Google + Anonymous) |
| Cloud DB | **Firestore** (backup/restore) |
| TTS | **Native Android** TextToSpeech (MethodChannel) |

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
| `git pull && flutter clean && flutter pub get && flutter run` | **New package added** (pubspec.yaml changed) or **Android resources changed** (icons, splash) |

---

## 5. Project Tokens & Config

| Token / File | Where | Notes |
|-------------|-------|-------|
| **DeepSeek API Key** | `lib/config/secrets.dart` (gitignored) | `sk-f42...48ba` — $5 = ~50k translations |
| **google-services.json** | `android/app/` | Firebase config — **gitignored**, never committed |
| **Firebase Project** | [console.firebase.google.com](https://console.firebase.google.com) | `project-794490258159` |
| **SSH Key (server)** | `~/.ssh/id_ed25519_vocab` | Hermes server pushes to GitHub |

---

## 6. Firebase Setup (Already Done ✅)

All auth providers enabled in Firebase Console:
- **Google** — OAuth client for `com.vocabreader.ai_vocab_builder`  
  SHA-1: `CB:A0:03:8B:B5:E9:65:BB:FA:A3:99:D3:B9:C2:F2:21:BE:C0:AF:22`
- **Anonymous** — temporary accounts
- ~~Email/Password~~ — removed (simplified to Google + Anonymous)

Firestore database created in `eur3` (Europe) region.

### ⚠️ Firestore Security Rules — DEPLOY NOW

**Without these rules, any authenticated user can read/write any other user's data.**

1. Go to [Firebase Console → Firestore → Rules](https://console.firebase.google.com/project/project-794490258159/firestore)
2. Replace the default rules with the content of `firestore.rules` (in this repo)
3. Click **Publish**

Rules enforce: `you can only access users/{your-uid}/words/` — locked at Firebase server level.

---

## 7. DeepSeek API (Already Done ✅)

1. Key created at [platform.deepseek.com](https://platform.deepseek.com)
2. Stored in `lib/config/secrets.dart` (gitignored — **never committed to GitHub**)
3. Translation endpoint: `https://api.deepseek.com/v1/chat/completions`
4. Model: `deepseek-chat`
5. Also used for: daily phrases, theme-based phrase generation

> ⚠️ **CRITICAL:** `secrets.dart` is gitignored. When you clone/pull, this file won't exist!
> You must create it manually:
> ```dart
> const String deepseekApiKeyReal = 'YOUR_REAL_KEY_HERE';
> ```
> `git pull` will NEVER overwrite this file again. The placeholder in GitHub doesn't have your real key.

---

## 8. AdMob Setup (Phase 6 — Not Started)

1. https://admob.google.com/ → Sign up
2. Create app → Android → AI Vocab Builder
3. Create ad units: Banner + Interstitial
4. Save Ad Unit IDs for Phase 6
