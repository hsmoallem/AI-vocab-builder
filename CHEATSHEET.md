# AI Vocab Builder — Command Cheat Sheet

## 📱 Build & Run the App (Mac)

```bash
# ── Start emulator ──
flutter emulators --launch Pixel_8

# ── Pull latest & run on emulator ──
cd ~/StudioProjects/ai_vocab_builder
git pull origin main && flutter run --release

# ── Pull latest, clean rebuild & run (after package changes) ──
cd ~/StudioProjects/ai_vocab_builder
git pull origin main && flutter clean && flutter pub get && flutter run --release

# ── Build APK (for phone install) ──
cd ~/StudioProjects/ai_vocab_builder
git pull origin main && flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk

# ── Install APK to phone via USB ──
cd ~/StudioProjects/ai_vocab_builder
flutter install
# OR manually:
adb install build/app/outputs/flutter-apk/app-release.apk

# ── Update app icon ──
cd ~/StudioProjects/ai_vocab_builder
dart run flutter_launcher_icons

# ── Update splash screen ──
cd ~/StudioProjects/ai_vocab_builder
dart run flutter_native_splash:create
```

## 🖥️ Server (Contabo 13.140.134.57)

```bash
# ── SSH to server ──
ssh houssam@13.140.134.57

# ── Check proxy health ──
curl http://13.140.134.57:9000/health

# ── Restart proxy ──
ssh houssam@13.140.134.57 'sudo systemctl restart deepseek-proxy'

# ── View proxy logs ──
ssh houssam@13.140.134.57 'sudo journalctl -u deepseek-proxy --no-pager -n 50'

# ── Claude Desktop (via VNC tunnel) ──
ssh -L 5901:127.0.0.1:5901 houssam@13.140.134.57
# Then connect VNC to 127.0.0.1:5901 (password: VNC_hermes@2026!!)
```

## 🔐 Credentials (quick reference)

| Service | URL | User / Note |
|---------|-----|-------------|
| Website | https://houssammoallem.com | — |
| Stats (protected) | https://stats.houssammoallem.com/websites | Passcode: `stats2026` |
| Uptime Kuma | http://13.140.134.57:3001 | `moallem88` / `Kuma@2026!!` |
| GitHub | github.com/hsmoallem/AI-vocab-builder | — |
| Firestore | project-794490258159 | Project ID: `ai-vocab-builder` |
| Proxy | http://13.140.134.57:9000/translate | X-App-Token or Firebase auth |
| VNC | 127.0.0.1:5901 (tunnel) | `VNC_hermes@2026!!` |

## 📂 Project Structure (Mac)

```
~/StudioProjects/ai_vocab_builder/    ← Flutter app
├── lib/
│   ├── screens/                      ← UI screens
│   ├── widgets/                      ← Reusable widgets
│   ├── services/                     ← DeepSeek, TTS, database, auth
│   ├── providers/                    ← State management
│   ├── config/                       ← Theme, strings, config
│   └── models/                       ← Word data model
├── android/                          ← Native Android
├── ios/                              ← iOS (future)
└── README.md | SETUP.md | TECHNICAL.md
```

## 🔄 Git Workflow

```bash
# ── Check current status ──
cd ~/StudioProjects/ai_vocab_builder && git status

# ── Pull latest code ──
cd ~/StudioProjects/ai_vocab_builder && git pull origin main

# ── View recent commits ──
cd ~/StudioProjects/ai_vocab_builder && git log --oneline -10
```

## 📝 When to use which command

| Situation | Command |
|-----------|---------|
| I want to test the latest changes | `git pull origin main && flutter run --release` |
| Hermes added/changed a package | `git pull && flutter clean && flutter pub get && flutter run --release` |
| I want APK for my phone | `flutter build apk --release` |
| Translations not working | Check proxy: `ssh houssam@13.140.134.57 'curl http://localhost:9000/health'` |
| Proxy needs restart | `ssh houssam@13.140.134.57 'sudo systemctl restart deepseek-proxy'` |
| Build is broken | `flutter clean && rm pubspec.lock && flutter pub get && flutter run --release` |
| Changed app icon | `dart run flutter_launcher_icons` then rebuild |
| Need VNC to Claude | `ssh -L 5901:127.0.0.1:5901 houssam@13.140.134.57` then VNC to 127.0.0.1:5901 |
| Check proxy logs | `ssh houssam@13.140.134.57 'sudo journalctl -u deepseek-proxy -n 50'` |
