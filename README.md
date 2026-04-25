# TrackIt 🚀

**TrackIt** is a premium, cross-platform personal management application built with Flutter. It seamlessly combines **Finance Tracking** and **Fitness Management** into a single, high-performance experience with a stunning modern UI.

![Premium UI](https://img.shields.io/badge/UI-Glassmorphism-blueviolet)
![Flutter](https://img.shields.io/badge/Framework-Flutter-02569B?logo=flutter)
![State Management](https://img.shields.io/badge/State-Provider-6366F1)
![Database](https://img.shields.io/badge/Database-SQLite-003B57?logo=sqlite)

## ✨ Features

### 💰 Finance Management
- **Expense Tracking**: Log expenses across multiple categories (Food, Transport, Shopping, etc.).
- **Budgeting**: Set monthly spending targets. The app automatically calculates your **Remaining Daily Limit** to keep you on track.
- **Visual Analytics**: Beautiful bar charts showing your weekly spending trends.
- **Budget Alerts**: Instant notifications when you exceed your daily limit.

### 🏋️ Fitness Tracking
- **Workout Logging**: Track Push, Pull, and Leg sessions with detailed set tracking.
- **Workout Routines**: Create custom templates for your favorite sessions and start them with one tap.
- **Smart Rest Timer**: Automatic countdown between sets with haptic feedback when the time is up.
- **Volume Progression**: Line charts visualizing your total lifted volume over time.

### 💎 Premium Experience
- **Glassmorphism UI**: A modern, dark-themed interface with subtle blurs and vibrant gradients.
- **Cross-Platform**: Fully optimized for **Mobile**, **Desktop**, and **Web** with a constrained mobile-width layout for desktop browsers.
- **Haptic Feedback**: Tactile confirmation for set completions, timer finishes, and data entry.
- **Daily Reminders**: Automatic scheduled notifications to remind you to check-in.

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Local Database**: [SQLite (sqflite)](https://pub.dev/packages/sqflite) with Web support via `sqflite_common_ffi_web`.
- **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router)
- **Notifications**: [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- **Design System**: Custom Glassmorphism components and a curated HSL color palette.

## 📂 Project Structure

The project follows a domain-driven, modular architecture for maximum scalability:

```text
lib/
├── models/           # Domain models (Fitness & Finance)
├── providers/        # Global state management logic
├── services/         # Database, Notifications, and business logic
├── pages/            # High-level screen layouts
├── widgets/          # Modularized UI components
│   ├── dashboard/    # Widgets specific to the Overview
│   ├── wallet/       # Widgets for financial tracking
│   ├── workouts/     # Fitness tracking components
│   └── analytics/    # Visualization charts
├── theme/            # App design system and tokens
└── layout.dart       # Main app shell and navigation
```

## 🚀 Getting Started

1. **Clone the repository**:
   ```bash
   git clone [repository-url]
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the application**:
   - For Mobile: `flutter run`
   - For Web: `flutter run -d chrome`
   - For Desktop: `flutter run -d windows`

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---
Built with ❤️ by Walker.
