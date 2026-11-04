# TrackIt 🚀

**TrackIt** is a premium, cross-platform personal management application built with Flutter. It combines **finance tracking**, **splitting expenses with friends** and **fitness tracking** in one offline-first app.

![Premium UI](https://img.shields.io/badge/UI-Glassmorphism-blueviolet)
![Flutter](https://img.shields.io/badge/Framework-Flutter-02569B?logo=flutter)
![State Management](https://img.shields.io/badge/State-Riverpod-6366F1)
![Database](https://img.shields.io/badge/Database-SQLite-003B57?logo=sqlite)

## ✨ Features

TrackIt works fully offline. Signing in adds sync across devices and splitting with friends.

### 💰 Finance
- **Transactions**: income and expenses with categories, subcategories, payment method and notes.
- **Events**: group transactions (a trip, a party) to see what they cost. Works offline.
- **Budgets**: a monthly budget and per-category budgets, with a notification at 80% and at 100% of each.
- **Stats**: spending charts and a monthly report: money in, spent, saved, the change from last month and the top categories.

### 🤝 Splitting (needs an account)
- **Shared events**: add friends to an event and split expenses equally, by amount or by percentage.
- **Guests**: split with people who don't have TrackIt, by name. Link them to their account if they join later.
- **Balances and settle up**: who owes whom, plus the fewest payments needed to settle everyone up.

### 🏋️ Fitness
- **Workout logging**: Push, Pull and Legs sessions with sets, reps and weights.
- **Routines**: reusable templates, started with one tap.
- **Rest timer**: countdown between sets with haptic feedback.
- **Progress**: volume charts over time.

### 🔒 Your data
- **Local first**: everything is stored on the device (SQLite) and kept across app updates.
- **Sync**: when signed in, changes upload in the background. Settings shows when you last synced and how many changes are waiting.
- **Backup**: export everything to a file and restore it later, on any device.
- **Safe sign-out**: you're warned before signing out with changes that haven't uploaded.

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Material 3), Android, iOS, desktop and web
- **State Management**: [Riverpod](https://pub.dev/packages/flutter_riverpod)
- **Local Database**: [sqflite](https://pub.dev/packages/sqflite), with `sqflite_common_ffi` on desktop and web
- **Networking**: [Dio](https://pub.dev/packages/dio), tokens in [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router)
- **Notifications**: [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- **Backend**: [TrackIt-Backend](https://github.com/Walker31/TrackIt-Backend) (Django REST Framework). Its README documents the API and the sync protocol.

## 📂 Project Structure

```text
lib/
├── models/           # Finance, fitness and group models
├── providers/        # Riverpod state
├── services/         # Database, sync, API, backup, budget alerts, reports
├── pages/            # Screens
├── widgets/          # UI components
│   ├── dashboard/    # Overview
│   ├── wallet/       # Transactions, budgets, events and splitting
│   ├── workouts/     # Fitness tracking
│   └── analytics/    # Charts and the monthly report
├── theme/            # Colours, text styles and theme
├── utils/            # Formatting and helpers (e.g. simplifying debts)
├── router.dart       # Routes
└── layout.dart       # App shell and bottom navigation
docs/
└── backend-sync-spec.md  # How the app's sync and the backend were designed
```

## 🚀 Getting Started

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run**:
   - Mobile: `flutter run`
   - Web: `flutter run -d chrome`
   - Desktop: `flutter run -d windows`

3. **Test**:
   ```bash
   flutter test
   ```

The app starts in local mode. To sync, sign in from Settings; the server address can be changed there.

## 📦 Releases

GitHub Actions (`.github/workflows/build-apk.yml`) builds release APKs split per ABI and publishes the arm64 and 32-bit ARM ones.

Release builds are signed with a fixed upload key, so each new APK installs over the old one and keeps the user's data. The workflow reads it from these repository secrets:

| Secret | Contents |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | The `.jks` keystore, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

For local release builds, put the same values in `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`). Without it the build falls back to the debug key, and that APK won't install over a signed one. **Keep the keystore and passwords backed up**: losing them means users must uninstall (and lose local data) to update. `key.properties` and the keystore are gitignored and must never be committed.

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---
Built with ❤️ by Walker.
