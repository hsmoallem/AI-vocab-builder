# AI Vocab Builder

Turn any PDF into a personal language lesson. Add words while you read, AI translates instantly.

## Features

- 📖 **PDF Reader** — native rendering + text extraction, tap any word to translate
- 🤖 **AI Translation** — DeepSeek-powered multi-meaning translations with examples
- 🃏 **Flashcards** — tap to flip, swipe to navigate, progress tracking
- 📅 **Daily Phrases** — 5 AI phrases/day, theme-based generation, save to My Words
- 🔊 **Text-to-Speech** — native Android pronunciation
- ☁️ **Cloud Backup** — Google sign-in → Firestore backup/restore

## Project Info

| Key | Value |
|-----|-------|
| **Project Name** | AI Vocab Builder |
| **App ID** | `com.vocabreader.ai_vocab_builder` |
| **Firebase Project** | `project-794490258159` (AI Vocab Builder) |
| **GitHub Repo** | [github.com/hsmoallem/AI-vocab-builder](https://github.com/hsmoallem/AI-vocab-builder) |
| **DeepSeek API Key** | In `lib/config/secrets.dart` (gitignored, never committed) |
| **Firebase Config** | `android/app/google-services.json` (gitignored, never committed) |
| **App Icon** | Blue circuit-board "A" on blue gradient |

## Authentication

- **Google Sign-In** — one tap, zero setup for users
- **Anonymous** — skip login, warning about no cloud backup (orange banner shown)

## Stack

Flutter 3.44.1 · Dart ≥3.5.0 · SQLite (sqflite) · DeepSeek API · Android native · Firebase Auth · Firestore

## Quick Links

- Full architecture: [`TECHNICAL.md`](TECHNICAL.md)
- Setup guide: [`SETUP.md`](SETUP.md)
- Product requirements: [`PRD.md`](PRD.md)
- Release notes: [`release-notes/v1.0.0.md`](release-notes/v1.0.0.md)
