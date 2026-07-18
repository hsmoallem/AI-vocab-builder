# AI Vocab Builder

Turn any PDF into a personal language lesson. Add words while you read, AI translates instantly.

## Features

- 📖 **PDF Reader** — native rendering + text extraction, tap any word to translate
- 🤖 **AI Translation** — DeepSeek-powered multi-meaning translations with examples (via secure proxy)
- 📦 **Bulk Import** — paste a list of words (one per line), translate all at once, auto-save
- 🃏 **Flashcards** — tap to flip, swipe to navigate, progress tracking
- 🔊 **Text-to-Speech Everywhere** — native Android pronunciation for words, translations, and examples on flashcards, word list, and add-word dialog
- 📅 **Daily Phrases** — 5 AI phrases/day, theme-based generation, configurable phrase language, save to My Words
- ☁️ **Cloud Backup** — Google sign-in → Firestore backup/restore
- 🎨 **App Branding** — custom launcher icon, native Android splash screen
- 🌍 **Multi-language UI** — English, Deutsch, العربية

## Project Info

| Key | Value |
|-----|-------|
| **Project Name** | AI Vocab Builder |
| **App ID** | `com.vocabreader.ai_vocab_builder` |
| **Firebase Project** | `project-794490258159` (AI Vocab Builder) |
| **GitHub Repo** | [github.com/hsmoallem/AI-vocab-builder](https://github.com/hsmoallem/AI-vocab-builder) |
| **DeepSeek API** | Via secure proxy server (key never in APK) |
| **Proxy URL** | `http://13.140.134.57:9000/translate` |
| **AI Model** | `deepseek-v4-flash` |
| **Firebase Config** | `android/app/google-services.json` (gitignored, never committed) |
| **App Icon** | Blue circuit-board "A" on blue gradient |
| **Splash Screen** | Native Android only — VocabView logo on dark background |

## Authentication

- **Google Sign-In** — one tap, zero setup for users
- **Anonymous** — skip login, warning about no cloud backup (orange banner shown)
- **Firebase ID Token** — signed-in users authenticate with `Authorization: Bearer <token>` (cryptographically verified on proxy). Legacy `X-App-Token` fallback for anonymous sessions.
- **Proxy Firebase** — `FIREBASE_PROJECT_ID=project-794490258159` enables JWT verification on the server

## Stack

Flutter 3.44.1 · Dart ≥3.5.0 · SQLite (sqflite) · DeepSeek API (via proxy) · Android native · Firebase Auth · Firestore · Provider · Native TTS (MethodChannel)

## Security

- DeepSeek API key lives **only** on the proxy server — never in the repo, never in the APK
- Proxy builds prompts server-side with Firebase ID-token auth + `X-App-Token` fallback + per-IP/per-UID rate limiting
- Firestore rules: per-user data isolation (`request.auth.uid == userId`)
- Decompiling the APK yields only the proxy URL — zero secrets

## Quick Links

- Full architecture: [`TECHNICAL.md`](TECHNICAL.md)
- Setup guide: [`SETUP.md`](SETUP.md)
- Product requirements: [`PRD.md`](PRD.md)
