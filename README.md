# Your Day

A minimal priority-weighted daily task tracker built with Flutter.  
Uses the Islamic (Hijri) calendar, weighted progress, and daily archiving.

---

## 📲 Install on Android

**Tap the button below on your phone to download and install the app:**

[![Download APK](https://img.shields.io/badge/Download-APK-green?style=for-the-badge&logo=android)](https://github.com/YOUR_USERNAME/YOUR_REPO/releases/latest/download/YourDay.apk)

> **First time installing?** On your Android phone:  
> Settings → Apps → Special app access → Install unknown apps → your browser → **Allow**

---

## Features

- **Weighted priorities** — Low (1pt), Medium (2pt), High (5pt), No way I can miss (10pt)
- **Weighted progress bar** — splits 100% across tasks by priority weight
- **Hijri calendar** — tracks days using the Islamic date
- **Repeat cycles** — same tasks repeat for a configurable number of days
- **Daily archiving** — each day's progress is saved to history automatically
- **Dark / Light theme**
- **Offline** — everything stored locally on device

---

## Build Status

![Build APK](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/build.yml/badge.svg)

---

## Development

### Requirements

- Flutter SDK ≥ 3.0
- Android Studio (for emulator / Android SDK)
- Java 17

### Run locally

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
flutter pub get
flutter run
```

### Build APK manually

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## How the CI/CD works

Every push to `main` triggers a GitHub Actions workflow that:

1. Sets up Flutter + Java on an Ubuntu runner
2. Runs `flutter build apk --release`
3. Uploads the APK to the **[Releases](https://github.com/YOUR_USERNAME/YOUR_REPO/releases/latest)** page as `YourDay.apk`

The download button above always points to the latest build.

---

## Tech stack

| Layer | Library |
|---|---|
| Framework | Flutter 3 |
| Storage | `shared_preferences` |
| Islamic calendar | `hijri` |
