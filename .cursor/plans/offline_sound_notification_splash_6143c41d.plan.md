---
name: Offline sound notification splash
overview: Add offline detection and banner, gate coin rewards and Firestore sync when offline; add win/lose sound effects with settings toggle; add daily "Let's play" notification; adjust splash logo spacing and animation.
todos: []
---

# Offline, sound, notification, and splash improvements

## 1. Offline support

**Requirements**

- App must detect network (permissions + connectivity check).
- When opening the app **offline**: same account and gameplay work; data saved locally; **no impact** on opening or playing.
- Show an **"Offline"** indicator at the **top** (in the HomeHub header bar, next to HELLO / username).
- When **offline**: coin purchases and coin rewards (e.g. win coins) are **not** applied or synced; stats (wins/losses/draws) can still be updated locally and synced when back online. When **online**, coins and stats sync as now.
- Messages and behavior when offline must be correct (no broken flows).

**Implementation outline**

- **Dependencies and permissions**
- Add [connectivity_plus](https://pub.dev/packages/connectivity_plus) to [pubspec.yaml](pubspec.yaml).
- In [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml): add `ACCESS_NETWORK_STATE` (and if targeting Android 13+, `POST_NOTIFICATIONS` for the daily notification below). Ensure the manifest has a `<uses-permission>` block.

- **Connectivity in the app**
- Create a small **connectivity helper** (e.g. in [lib/core/](lib/core/) or [lib/services/](lib/services/)) that exposes current online status (e.g. `Stream<bool>` or `ValueNotifier<bool>` + `Connectivity().onConnectivityChanged`). On startup, check once and then listen for changes.
- Optionally cache "last known online" so the UI can show Offline as soon as the app opens when there is no network.

- **Splash screen**
- In [lib/main.dart](lib/main.dart), `SplashScreen._goNext()`: when **offline**, skip or wrap `AuthService().syncCurrentUser()` and `UserRepo().initAfterAuth()` in try/catch so failures do not block navigation. Still navigate to `/home` or `/login` using **cached** user (e.g. from SharedPreferences / Firebase Auth persistence). Goal: app **always** opens and continues; no hang on "no network".

- **HomeHub header**
- In [lib/main.dart](lib/main.dart), `HomeHub` (around lines 470–515): when the connectivity helper says **offline**, show an **"Offline"** label or small banner in the header row (e.g. next to the greeting or above it), so the user sees it at the top. When online, hide it.

- **Coins and Firestore when offline**
- **LocalStore** ([lib/main.dart](lib/main.dart) around 124–130, 155–160, 162–177): before calling `_syncToFirestore`, check connectivity (or a simple `isOnline` flag provided by the helper). When **offline**, skip Firestore sync but still update SharedPreferences (local data). When **online**, sync as now.
- **Game result (win/loss)**: In `_handleResult` (and equivalent in BettingGamePage, LevelGamePage), when awarding **coins for a win**: only call `LocalStore.addCoins(...)` (and topup history) when **online**. When **offline**, update local stats (wins/losses/draws) but **do not** add coins; optionally show a short message like "Coins will update when you're back online" in the end dialog or subtitle so messages are correct.

Result: Offline = app opens and plays; data saved locally; "Offline" at top; no coin rewards or purchase recording while offline; when back online, sync and coins behave normally.

---

## 2. Sound effects (win / lose) and settings

**Requirements**

- **Win**: one sound when the user wins.
- **Lose**: a different sound when the user loses.
- **Settings**: toggle to turn sound **on** or **off**.

**Implementation outline**

- **Dependencies and assets**
- Add [audioplayers](https://pub.dev/packages/audioplayers) (or [just_audio](https://pub.dev/packages/just_audio)) to [pubspec.yaml](pubspec.yaml).
- Under [pubspec.yaml](pubspec.yaml) `flutter.assets`, add a folder for sounds, e.g. `assets/sounds/`, and add two files: `win.mp3`, `lose.mp3` (you will need to add these files; the plan does not create binary assets).

- **Storage**
- In [lib/core/keys.dart](lib/core/keys.dart), add a key for the sound setting, e.g. `soundEnabled` (default true). In Settings, read/write this via SharedPreferences.

- **Sound service**
- Create a small **sound helper** (e.g. [lib/services/sound_service.dart](lib/services/sound_service.dart)) that: (1) reads the `soundEnabled` flag, (2) exposes `playWin()` and `playLose()` (play the corresponding asset once). If sound is off, no-op. Use a single instance so it can be called from game pages and settings.

- **Game result**
- In [lib/main.dart](lib/main.dart), in `_handleResult` (and in BettingGamePage and LevelGamePage equivalents): when showing the end dialog, if **win** call `SoundService.playWin()`, if **loss** call `SoundService.playLose()`. Draw does not need a sound (or you can add one later).

- **Settings page**
- In [lib/main.dart](lib/main.dart), `SettingsPage`: add a new row/tile **"Sound"** (or "Sound effects") with a switch: **on** = sound enabled, **off** = sound disabled. Persist the value using the new Keys key and refresh the sound helper so the next game uses the new value.

Result: Win/lose play different sounds; user can turn sounds off/on in Settings.

---

## 3. Daily notification ("Let's play")

**Requirements**

- A notification every **24 hours** (e.g. "Let's play") that fires even when the app is **not open**.
- So: schedule a **repeating** local notification (daily).

**Implementation outline**

- **Dependencies and permissions**
- Add [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) to [pubspec.yaml](pubspec.yaml).
- Android: in [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml), add `POST_NOTIFICATIONS` for Android 13+ and any receiver/configuration required by the plugin (see plugin docs). iOS: request notification permission and configure as per plugin.

- **Notification service**
- Create a **notification helper** (e.g. [lib/services/notification_service.dart](lib/services/notification_service.dart)) that: (1) initializes the plugin, (2) requests permission, (3) schedules a **daily** repeating notification (e.g. at a fixed time, title "New York XO", body "Let's play!") using the plugin’s scheduling API (e.g. `zonedSchedule` or daily repeat). Cancel/reschedule when the user opens the app if you want to avoid duplicate channels; keep it simple: one daily trigger.

- **Startup**
- In [lib/main.dart](lib/main.dart), after `WidgetsFlutterBinding.ensureInitialized()` (e.g. in `main()`), call the notification service to init and schedule the daily notification so it runs even when the app is closed.

Result: User receives a daily "Let's play" notification even when the app is not open.

---

## 4. Splash / opening image: spacing and animation

**Requirements**

- The **X** and **O** on the opening (splash) screen should **not** all overlap; leave **some space** between them like in the reference image.
- **New design** with a **nice animation** and **effect**.

**Current state**

- Logo is drawn in [lib/widgets/app_ui.dart](lib/widgets/app_ui.dart): class `XOLogo`, painter `_XOLogoPainter`. The **O** is drawn at `center.dx - 0.13*width`, `center.dy - 0.06*height` with radius `0.26*width`. The **X** is at `center.dx + 0.17*width`, `center.dy + 0.07*height` with arm length `0.22*width`. They are still close and can overlap visually.
- Splash animation in [lib/main.dart](lib/main.dart) `SplashScreen`: a small **scale pulse** (1.0 + 0.06 * pulse) over 1300 ms.

**Implementation outline**

- **Spacing (no overlap)**
- In [lib/widgets/app_ui.dart](lib/widgets/app_ui.dart), `_XOLogoPainter`: increase separation between O and X. For example: move **O** further left/up (e.g. decrease `center.dx` and `center.dy` for O) and **X** further right/down (e.g. increase X center offsets), or slightly reduce the radius/arm length so the two symbols do not overlap. Tweak until there is clear **space** between O and X like in the reference image.

- **Animation and effect**
- In [lib/main.dart](lib/main.dart), `SplashScreen`: keep or extend the existing scale pulse. Add one or more of: (1) **fade-in** (opacity 0 → 1) for the logo, (2) a subtle **glow** animation (e.g. animate the glow circle radius or opacity in the painter if exposed, or wrap the logo in a container with animated blur/shadow), (3) a short **slide** or **bounce** when the logo appears. Prefer using `AnimationController` + `Tween` so the splash feels "unique" and polished without overdoing it.
- Optionally in `_XOLogoPainter`: if you pass an animation value from the splash, you can animate stroke width or glow opacity for a "nice effect". Otherwise, keep the painter stateless and do opacity/scale/position in the widget.

Result: Splash shows O and X with clear spacing (no overlap), with a smoother, more noticeable animation and effect.

---

## Summary

| Area | Action |
|------|--------|
| **Offline** | Add connectivity_plus; Android ACCESS_NETWORK_STATE; connectivity helper; Splash works offline; HomeHub shows "Offline" at top; LocalStore and game skip coin reward and Firestore sync when offline. |
| **Sound** | Add audioplayers + assets win.mp3/lose.mp3; Keys.soundEnabled; sound service; play win/lose in _handleResult; Settings sound on/off switch. |
| **Notification** | Add flutter_local_notifications; Android POST_NOTIFICATIONS; notification service schedules daily "Let's play"; init in main(). |
| **Splash** | In app_ui.dart, increase O/X spacing in _XOLogoPainter; in main.dart SplashScreen, add fade-in and/or glow/slide animation. |

Implement in this order to avoid blocking: (1) connectivity + offline UI and logic, (2) sound + settings, (3) notification, (4) splash spacing and animation. Add the two sound asset files (win.mp3, lose.mp3) manually or via a placeholder; the code will reference them under `assets/sounds/`.