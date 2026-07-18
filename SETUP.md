# AI Vocab Builder — Setup & Workflow Guide

> **Project:** AI Vocab Builder  
> **App ID:** `com.vocabreader.ai_vocab_builder`  
> **Firebase:** `project-794490258159` (AI Vocab Builder)  
> **GitHub:** [github.com/hsmoallem/AI-vocab-builder](https://github.com/hsmoallem/AI-vocab-builder)  
> **DeepSeek Key:** On proxy server only — never in repo/APK  
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
| **Phase 5** | Settings, language picker (EN/DE/AR), phrase language dropdown, multi-language TTS | ✅ Complete |
| **Phase 6** | Bulk Import + TTS everywhere (flashcards, word list, add dialog) | ✅ Complete |
| **Phase 7** | AdMob ads + Remove Ads IAP | ⬜ Planned |

---

## 3. Current Feature Set

### Auth (Phase 4 — ✅ Complete)
- **Google Sign-In** — one tap, uses phone's Google account
- **Anonymous** — skip login, warning about no cloud backup (orange banner)
- **Cloud Backup:** One-tap backup/restore all words to Firestore

### Core (Phases 1-6 — ✅ Complete)
- **3-tab navigation:** Reader · Daily Phrases · My Words
- **Add word:** Enter any word → AI translates via proxy → DeepSeek
- **Bulk Import:** Paste a list of words (one per line) → batch translate → auto-save
- **Multi-meaning translation:** Separate entries with unique examples
- **German article detection:** `der`/`die`/`das` auto-detected
- **Sort & search:** Alphabetical or newest-first, live search
- **Swipe-to-delete:** With confirmation dialog
- **Flashcards:** Tap to flip, swipe to navigate, progress bar
- **PDF Reader:** Native rendering + text extraction, tap-to-add
- **Daily Phrases:** AI generates 5 phrases/day, mark as memorized, save to My Words, theme-based generation, regenerate button
- **Phrase Language Dropdown:** Pick language for phrase generation — separate from translate-to language
- **Text-to-Speech Everywhere:** Native Android TTS on flashcards (word, translation, examples), word list, and add word dialog

### Branding (June 2026 — ✅ Complete)
- **Launcher icon:** Blue circuit-board "A" on blue gradient
- **Native splash:** Android native splash — VocabView logo on dark background (`#121212`)
- **Login header:** Simple `Icons.menu_book_rounded` icon

### Current Technical Stack

| Tool | Actual |
|------|--------|
| Database | **sqflite** (SQLite) |
| File picker | **Native Android** (MethodChannel) |
| PDF | **flutter_pdfview** (render) + **syncfusion_flutter_pdf** (text) |
| State | **Provider** |
| AI | **DeepSeek** via secure proxy (key never in APK) |
| Auth | **Firebase** (Google + Anonymous) |
| Cloud DB | **Firestore** (backup/restore) |
| TTS | **Native Android** TextToSpeech (MethodChannel) |
| Icons | **flutter_launcher_icons** |
| Splash | **flutter_native_splash** |

> Full details: [`TECHNICAL.md`](TECHNICAL.md)

---

## 4. Your Only Job Per Phase

```bash
cd ~/StudioProjects/ai_vocab_builder
git pull origin main     # get latest code from GitHub
flutter run --release    # build, install, launch on emulator
```

**When to add extra commands:**

| Command | When |
|---------|------|
| `git pull && flutter run --release` | **Most updates** — code changes only |
| `git pull && flutter clean && flutter pub get && flutter run --release` | **New package added/removed** (pubspec.yaml changed) |
| `flutter build apk --release` | **Build APK only** (no install/launch) |
| `flutter emulators --launch Pixel_8` | **Start emulator** before running |
| `dart run flutter_launcher_icons` | **App icon changed** |
| `dart run flutter_native_splash:create` | **Splash screen changed** |

### Running on Emulator

```bash
# 1. Start the emulator (replace Pixel_8 with your emulator name)
flutter emulators --launch Pixel_8

# 2. Run the app (builds + installs + launches automatically)
cd ~/StudioProjects/ai_vocab_builder && flutter run --release
```

### Building APK Only (for phone install)

```bash
cd ~/StudioProjects/ai_vocab_builder && git pull origin main && flutter build apk --release
# APK at: build/app/outputs/flutter-apk/app-release.apk
```

---

## 5. Project Tokens & Config

| Token / File | Where | Notes |
|-------------|-------|-------|
| **DeepSeek API Key** | Proxy server only | `/home/houssam/deepseek-proxy/proxy.py` on Contabo — never in repo |
| **Proxy URL** | `lib/services/translation_service.dart` | `http://13.140.134.57:9000/translate` |
| **google-services.json** | `android/app/` | Firebase config — **gitignored**, never committed |
| **Firebase Project** | [console.firebase.google.com](https://console.firebase.google.com) | `project-794490258159` |
| **SSH Key (server)** | `~/.ssh/id_ed25519_vocab` | Hermes server pushes to GitHub |

---

## 6. Firebase Setup (Already Done ✅)

All auth providers enabled in Firebase Console:
- **Google** — OAuth client for `com.vocabreader.ai_vocab_builder`  
  SHA-1: `CB:A0:03:8B:B5:E9:65:BB:FA:A3:99:D3:B9:C2:F2:21:BE:C0:AF:22`
- **Anonymous** — temporary accounts

Firestore database created in `eur3` (Europe) region.

### Firestore Security Rules — DEPLOYED ✅

Per-user rules are active: each user can only access their own words (`users/{uid}/words/`).

---

## 7. DeepSeek Proxy (Already Done ✅)

The API key lives on a dedicated proxy server — never in the APK.

### How it works
1. App sends `{word, sourceLang, targetLang, mode}` to `http://13.140.134.57:9000/translate`
2. Proxy validates `X-App-Token`, enforces rate limiting (30 req/min)
3. Proxy builds the AI prompt server-side, injects the real DeepSeek key
4. DeepSeek response is parsed and returned to the app

### Security
- Signed-in users authenticate with verified Firebase ID tokens (`Authorization: Bearer <token>`)
- Anonymous users fall back to legacy `X-App-Token` shared secret
- Decompiling the APK yields only the proxy URL — no API key, no prompt injection possible
- Proxy is not an open LLM relay — app can't inject custom prompts
- Per-UID rate limiting (10 req/min) + per-IP backstop (30 req/min)

### Proxy server
- Location: Contabo VPS (`13.140.134.57`)
- Port: 9000 (HTTP)
- Process: gunicorn (127.0.0.1:9001) + socat (0.0.0.0:9000)
- Start: `bash /home/houssam/deepseek-proxy/start.sh`
- Firebase: `FIREBASE_PROJECT_ID=project-794490258159` for JWT verification

---

## 8. AdMob Setup (Phase 6 — Not Started)

1. https://admob.google.com/ → Sign up
2. Create app → Android → AI Vocab Builder
3. Create ad units: Banner + Interstitial
4. Save Ad Unit IDs for Phase 6
