# AI Vocab Builder

**Turn any PDF into a personal language lesson.** Read, tap a word, and an AI instantly
translates it with real example sentences — then drills it back to you with flashcards,
spaced review, and daily practice.

Built with Flutter for Android and Web. Focused on a fast, offline-first learning loop with a
security-conscious AI backend.

> **Status:** v1.0 shipped · actively iterating
> **Stack:** Flutter · Dart · SQLite · Firebase · a hardened AI proxy

<!-- Add screenshots here: docs/screenshots/*.png -->

---

## ✨ Features

- **📖 PDF reader** — native rendering + text extraction; tap any word to translate it in place.
- **🤖 AI translation** — multi-meaning translations with example sentences, adjustable to
  **CEFR level (A1–C2)**. Powered by an LLM behind a secure proxy.
- **📥 Bulk import** — paste a whole word list; each word is translated and saved automatically.
- **🃏 Flashcards** — flip animation, swipe navigation, progress tracking, and per-card tools:
  - **Practical grammar tips** — real usage guidance (e.g. *am Markt* vs *im Markt*) and common
    mistakes, not dictionary trivia.
  - **Regenerate example** — get a brand-new sentence in a *different* context on demand.
  - **Free-text notes**, **on-demand 2nd-language translation**, and **copy** on every field.
- **📝 Saved words** — search, sort, per-field copy, **regenerate examples**, and **remove duplicates**.
- **📅 Daily phrases** — five fresh AI phrases a day, theme-based generation, save to your list.
- **🎮 AI Quiz & Story** — practice your vocabulary by generating an interactive AI quiz or a short story.
- **🔥 Streak tracking** — keeps your learning streak alive by tracking your daily study sessions, synchronized across devices.
- **🗣️ Text-to-Audio tool** — paste any text and listen to native-sounding pronunciation at adjustable speeds.
- **🔊 Text-to-speech** — native pronunciation for words, translations, and examples.
- **☁️ Cloud backup & Sync** — Google sign-in → Firestore backup/restore, with per-user data isolation.
- **🌐 Web version** — full access from any browser with responsive layouts.
- **🌍 Multilingual UI** — English, Deutsch, العربية (incl. full RTL support).

---

## 🏗️ Architecture & engineering highlights

The parts I'm most proud of — where the interesting engineering decisions live.

### Security-conscious AI backend
The LLM API key **never ships in the app**. The app talks only to a small **proxy server**
that:
- **builds all prompts server-side** — the client sends just `{word, sourceLang, targetLang, mode}`,
  so the proxy can never be abused as an open, general-purpose LLM relay;
- **authenticates requests** with a **verified Firebase ID token** (JWT validated against Google's
  public JWKS), with a lightweight token fallback for anonymous sessions;
- **rate-limits** per user and per IP to protect the quota;
- returns clean, structured JSON to the app.

Decompiling the APK yields no usable secret — only a public endpoint.

### Native integrations without heavy plugins
Text-to-speech and file selection are implemented as thin **Kotlin `MethodChannel`** bridges
instead of pulling in large third-party plugins. This keeps the build stable on the latest
Android Gradle toolchain and avoids plugins that lag behind the Flutter/Kotlin release cycle
— a deliberate tradeoff for maintainability.

### Offline-first local storage
All vocabulary lives in a local **SQLite** database (`sqflite`) — the app is fully usable
offline except for AI calls and cloud sync. The schema is versioned with real **migrations**
(`onUpgrade`, `ALTER TABLE`) so existing users' data survives every update.

### Clean state & product structure
- **Provider** for state management, with a clear model → service → provider → UI flow.
- **Firebase Auth** (Google + anonymous) and **Firestore** backup guarded by per-user
  security rules (`request.auth.uid == userId`).
- Fully internationalized UI, including a right-to-left language.

```
┌──────────┐   {word, lang, mode}   ┌───────────────┐   prompt + key   ┌──────────┐
│   App    │ ─────────────────────▶ │  Proxy server │ ───────────────▶ │   LLM    │
│  (APK)   │ ◀───── structured ──── │ (prompts,auth,│ ◀──── JSON ───── │   API    │
│          │        JSON            │  rate limits) │                  │          │
└──────────┘                        └───────────────┘                  └──────────┘
```

---

## 🧰 Tech stack

| Area | Choice |
|------|--------|
| Framework | Flutter (Dart ≥ 3.5), Material 3 |
| Local DB | SQLite via `sqflite` (versioned migrations) |
| State | Provider |
| Auth & cloud | Firebase Auth (Google / anonymous), Cloud Firestore |
| Native | Kotlin `MethodChannel` (TTS, file picking) |
| PDF | `flutter_pdfview` + `syncfusion_flutter_pdf` |
| AI | LLM via a hardened proxy (key server-side only) |
| Platforms | Android (iOS-ready architecture) |

---

## 📚 Docs

- [`PRD.md`](PRD.md) — product requirements, vision, and phased feature plan
- [`release-notes/`](release-notes) — what shipped and the tricky problems solved along the way

*(Deployment and server-ops docs are kept private — this repo intentionally contains no
infrastructure details, endpoints, or secrets.)*

---

## 👤 Author

**Houssam Moallem** — built end-to-end: product design, Flutter app, native Android bridges,
the AI proxy backend, auth, and cloud sync.
GitHub: [@hsmoallem](https://github.com/hsmoallem)
