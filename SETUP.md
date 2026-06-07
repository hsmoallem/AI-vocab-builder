# Vocab Builder PDF Reader — Setup & Workflow Guide

> **Team:** Houssam (Mac) + Hermes (code)  
> **Workflow:** You create project → GitHub → I write code → you run  
> **Tech:** Flutter + Dart (Android now, iOS later — same code)  
> **Tool:** Android Studio (one app for everything)  
> **Project:** `~/StudioProjects/ai_vocab_builder`

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

## 2. Phase 0 — One-Time Setup (Mac)

| Step | Task | Status |
|---|---|---|
| 0.1 | Install Flutter SDK | ✅ |
| 0.2 | Install Android Studio | ✅ |
| 0.3 | Accept Android licenses | ✅ |
| 0.4 | Install Flutter plugin in Android Studio | ✅ |
| 0.5 | Create GitHub repository | ✅ |
| 0.6 | Create Flutter project in Android Studio | ✅ |
| 0.7 | Push project to GitHub | ✅ |
| 0.8 | Run app on emulator or phone | ⬜ |
| 0.9 | Get DeepSeek API key | ⬜ |
| 0.10 | Create Firebase project | ⬜ |
| 0.11 | Register Android app in Firebase | ⬜ |
| 0.12 | Enable Google Sign-In | ⬜ |
| 0.13 | Create Firestore database | ⬜ |
| 0.14 | Set up AdMob (optional, can skip) | ⬜ |

---

### 0.7 — Push to GitHub (done ✅)

```bash
cd ~/StudioProjects/ai_vocab_builder
git init
git add .
git commit -m "chore: initial Flutter project"
git branch -M main
git remote add origin https://github.com/hsmoallem/AI-vocab-builder.git
git push -u origin main
```
Username: `hsmoallem` | Password: GitHub Personal Access Token (Contents: Read & Write)

---

### 0.8 — Run the App

```
① Open Android Studio → open project ~/StudioProjects/ai_vocab_builder
② Top toolbar: click the green ▶ Run button
③ If no device: dropdown → Create New Virtual Device → pick a phone → download → select it
④ OR: Connect your Android phone via USB (USB Debugging ON in phone settings)
⑤ App builds (1-2 min) → counter app appears on phone
⑥ Tap + a few times → counter goes up

TELL ME: Did you see the counter app?
```

---

### 0.9 — Get DeepSeek API Key

```
① Go to: https://platform.deepseek.com/
② Sign up with Google
③ Left sidebar: API Keys → Create new key
④ Copy the key (starts with sk-)
⑤ Left sidebar: Billing → Add $5 ($5 = ~50,000 translations)
```

⚠️ Never share your API key anywhere. It goes in a secure config file inside the app.

---

### 0.10–0.13 — Firebase Setup (Browser)

```
① https://console.firebase.google.com/ → Create project → name: vocab-reader
② Add Android app → package: com.vocabreader.ai_vocab_builder
③ Download google-services.json → save it
④ Authentication → Google → Enable
⑤ Firestore Database → Create → Production mode → eur3 (Europe)
```

---

### 0.14 — AdMob (Optional, Can Skip)

```
① https://admob.google.com/ → Sign up
② Create app → Android → Vocab Builder
③ Create 2 ad units: Banner + Interstitial
④ Save the Ad Unit IDs (needed at Phase 6)
```

---

## 3. Development Phases

| Phase | What | Status |
|---|---|---|
| **Phase 1** | sqflite DB, Add Word + DeepSeek, Word List, sort, delete | ✅ Complete |
| **Phase 2** | PDF picker (native), native rendering (flutter_pdfview), text extraction, tap-word | ✅ Complete |
| **Phase 3** | Flashcards + review flow | 🔨 Built |
| **Phase 4** | Google sign-in + Firestore cloud sync | ⬜ |
| **Phase 5** | Settings, language picker | ⬜ |
| **Phase 6** | AdMob ads + Remove Ads IAP | ⬜ |

### Current Technical Stack

| Tool | Actual |
|------|--------|
| Database | **sqflite** (SQLite, not Isar) |
| File picker | **Native Android** (MethodChannel — no package) |
| PDF text | **syncfusion_flutter_pdf** |
| State | **Provider** |
| AI | **DeepSeek** (multi-meaning, each with own example) |
| Tests | **22 tests** (11 model + 11 widget) |

> Full details: `TECHNICAL.md`

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

Then test and tell me what works / what's broken.

---

## 5. Firebase Setup (Browser — Steps 0.10–0.13)

1. https://console.firebase.google.com/ → **Create project** → `vocab-reader`
2. Add **Android app** → package: `com.vocabreader.ai_vocab_builder`
3. Download `google-services.json` → save it
4. **Authentication** → Google → Enable
5. **Firestore Database** → Create → Production mode → `eur3` (Europe)

---

## 6. AdMob Setup (Browser — Step 0.14)

1. https://admob.google.com/ → Sign up
2. Create app → Android → `Vocab Builder`
3. Create 2 ad units: Banner + Interstitial
4. Save the Ad Unit IDs — needed at Phase 6

---

## 7. DeepSeek API Key (Step 0.9)

1. Go to https://platform.deepseek.com/
2. Sign up, create an API key (starts with `sk-`)
3. Add funds (~$5 = ~50,000 translations)

⚠️ Never share your API key with anyone or in chat. The key will go in a secure config file inside the app.
