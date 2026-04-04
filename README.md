<div align="center">

<img src="assets/icon/app_icon.png" alt="Your Day app icon" width="96" height="96" />

<br /><br />

<img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white" />
<img src="https://img.shields.io/badge/Flutter-3.0+-02569B?style=flat-square&logo=flutter&logoColor=white" />
<img src="https://img.shields.io/badge/Calendar-Hijri-8B4513?style=flat-square" />
<img src="https://img.shields.io/badge/Storage-Offline--first-555?style=flat-square" />

<br /><br />

# Your Day — Priority Cycle Tracker

**A minimal, weighted daily task tracker built with Flutter.**  
Track your intentions across repeating cycles — anchored to the Islamic Hijri calendar.

<br />

[![Download APK](https://img.shields.io/badge/⬇️%20Download%20APK-Latest%20Release-c0644a?style=for-the-badge)](https://github.com/Fahim715/Your-Day/releases/download/v1.0.0/app-release.apk)

> **First-time install on Android?**  
> Settings → Apps → Special app access → Install unknown apps → your browser → **Allow**

<br />

</div>

---

## Screenshots

| Today's Tasks | Bright Theme | Dark Theme |
|:---:|:---:|:---:|
| ![Dark home screen](images/image01.jpg) | ![Task list](images/image02.jpg) | ![Completed](images/image04.jpg) |

> Light theme also supported — toggleable from the header.

---

## What It Does

**Your Day** lets you define daily tasks, assign weighted priorities, and track progress across a repeat cycle anchored to the Hijri date. Progress is weighted (not just task count), and the horseshoe progress ring visually changes when you hit strong completion.

| Feature | Detail |
|---|---|
| **Weighted priorities** | Low · Medium · High · *No way I can miss* → 1 / 2 / 5 / 10 pts |
| **Horseshoe progress ring** | Pink→red under 80%, turns green at 80%+ |
| **Hijri calendar** | Day counter anchored to the Islamic date |
| **Repeat flow** | `Repeat For?` button opens a confirm dialog; then shows `Day x/N` |
| **Reset controls** | `Reset Your Progress` or `Reset Everything` (with confirmation) |
| **Daily archiving** | Each day's result is automatically saved to History |
| **Dark / Light theme** | System-aware toggle in the app header |
| **Fully offline** | No accounts, no network — everything stays on device |

---

## How to Use

1. **Add a task** — type in the input field, select a priority from the dropdown, tap **+**
2. **Set repeat length** — tap **Repeat For?**, enter days (1 to 365), then tap **Confirm**
3. **Track daily cycle** — the button changes to **Day x/N** and stays editable by tapping again
4. **Check off tasks** — tap task check circles; weighted ring updates instantly
5. **Review history** — open the **History** tab for archived day summaries
6. **Use reset options** — tap **Reset** to clear progress only, or reset everything with confirmation

> The date label uses the Islamic (Hijri) calendar and updates automatically based on your device timezone.

---

## Tech Stack

| Layer | Choice | Why |
|---|---|---|
| **Framework** | Flutter 3 (Dart) | Single codebase, native performance on Android |
| **Local storage** | `shared_preferences` | Lightweight key-value persistence for tasks & history |
| **Islamic calendar** | `hijri` package | Accurate Hijri date conversion without a server |
| **State** | `setState` / built-in Flutter | Kept intentionally simple — no external state manager needed |
| **CI/CD** | GitHub Actions | Auto-builds release APK on every push to `main` |

The app is intentionally dependency-light. No Firebase, no backend, no tracking.

---

## How CI/CD Works

Every push to `main` triggers a GitHub Actions workflow:

1. Provisions Ubuntu runner with **Flutter + Java 17**
2. Runs `flutter build apk --release`
3. Publishes the APK to **GitHub Releases** as `YourDay.apk`

The download badge above always resolves to the latest build.

---

## Run Locally

**Requirements:** Flutter SDK ≥ 3.0 · Android Studio · Java 17

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
flutter pub get
flutter run
```

**Build release APK manually:**

```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

---

<div align="center">

Built for personal use. Runs offline. No data leaves your device.

</div>
