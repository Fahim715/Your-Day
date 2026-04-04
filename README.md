<div align="center">

<img src="assets/icon/app_icon.png" alt="Your Day" width="88" height="88" />

<br /><br />

# Your Day

**A minimal daily task tracker that rewards consistency over completion.**  
Build habits across repeating cycles with a priority-weighted progress system.

<br />

<img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white" />
<img src="https://img.shields.io/badge/Flutter-3.0+-02569B?style=flat-square&logo=flutter&logoColor=white" />
<img src="https://img.shields.io/badge/Storage-Offline--first-555?style=flat-square" />

<br /><br />

[![Download APK](https://img.shields.io/badge/⬇️%20Download%20APK-Latest%20Release-c0644a?style=for-the-badge)](https://github.com/Fahim715/Your-Day/releases/download/v1.1.0/app-release.apk)

> **First-time install?** On Android: Settings → Apps → Special app access → Install unknown apps → allow your browser

</div>

---

## Screenshots

| Today's Tasks | Dark Theme | Bright Theme |
|:---:|:---:|:---:|
| ![Tasks](images/image01.jpg) | ![Bright](images/image02.jpg) | ![Dark](images/image03.jpg) |

---

## Features

| | |
|---|---|
| **Weighted priorities** | Low · Medium · High · *No way I can miss* → 1 / 2 / 5 / 10 pts |
| **Progress bar** | Visual progress — turns green at 80%+ completion |
| **Repeat cycles** | Set how many days your task list runs before resetting |
| **Daily archiving** | Each day's result is saved automatically to History |
| **Reset controls** | Reset progress only, or reset everything with confirmation |
| **Dark / Light theme** | Toggle from the header |
| **Fully offline** | No accounts, no network — everything stays on device |

---

## How to Use

1. **Add tasks** — type a task name, pick a priority, tap **+**
2. **Set a cycle** — tap **Repeat For?**, enter the number of days, tap **Confirm**
3. **Track daily** — check off tasks; the progress bar updates in real time
4. **Review history** — open the **History** tab to see past days and scores

---

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter 3 (Dart) |
| Storage | `shared_preferences` |
| State management | Built-in `setState` |
| CI/CD | GitHub Actions — builds and publishes APK on every push to `main` |

No Firebase. No backend. No tracking.

---

## Run Locally

```bash
git clone https://github.com/Fahim715/Your-Day.git
cd Your-Day
flutter pub get
flutter run
```

```bash
# Build release APK
flutter build apk --release
```

---

<div align="center">
Runs fully offline. No data ever leaves your device.
</div>
