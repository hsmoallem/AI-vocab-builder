# AI Vocab Builder

Turn any PDF into a personal language lesson. Add words while you read, AI translates instantly.

## Features

- 📖 **PDF Reader** — native rendering + text extraction, tap any word to translate
- 🤖 **AI Translation** — DeepSeek-powered multi-meaning translations with examples (via secure proxy)
- 🃏 **Flashcards** — tap to flip, swipe to navigate, progress tracking
- 📅 **Daily Phrases** — 5 AI phrases/day, theme-based generation, configurable phrase language, save to My Words
- 🔊 **Text-to-Speech** — native Android pronunciation
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
| **Firebase Config** | `android/app/google-services.json` (gitignored, never committed) |
| **App Icon** | Blue circuit-board "A" on blue gradient |
| **Splash Screen** | Native Android only — VocabView logo on dark background |
| **Stable Tag** | `stable-2026-06-08` |

## Authentication

- **Google Sign-In** — one tap, zero setup for users
- **Anonymous** — skip login, warning about no cloud backup (orange banner shown)

## Stack

Flutter 3.44.1 · Dart ≥3.5.0 · SQLite (sqflite) · DeepSeek API (via proxy) · Android native · Firebase Auth · Firestore · Provider

## Security

- DeepSeek API key lives **only** on the proxy server — never in the repo, never in the APK
- Proxy builds prompts server-side with `X-App-Token` auth + per-IP rate limiting
- Firestore rules: per-user data isolation (`request.auth.uid == userId`)
- Decompiling the APK yields only the proxy URL — zero secrets

## Quick Links

- Full architecture: [`TECHNICAL.md`](TECHNICAL.md)
- Setup guide: [`SETUP.md`](SETUP.md)
- Product requirements: [`PRD.md`](PRD.md)
- Release notes: [`release-notes/v1.0.0.md`](release-notes/v1.0.0.md)
