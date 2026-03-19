# Snevva

Snevva is a Flutter-based health companion app focused on daily wellness tracking, personalized insights, and lightweight guidance. The app combines on-device tracking (steps, sleep), self-reported check-ins (mood, hydration), and content modules (diet plans, mental wellness, health tips) with reminders and push notifications.

**Key Features**
- Onboarding and profile setup with health goals
- Steps tracking with background updates
- Sleep tracking with screen-off based sleep windows
- Hydration goals and intake logging
- Mood tracking and mental wellness content
- Diet plan discovery and details
- BMI calculator and updates
- Women’s health tracking
- Vitals logging
- Reminders for water, medicine, meals, and events
- Emergency contacts
- Push notifications via Firebase Messaging
- In-app decision-tree style chat ("Snevva AI")

**Tech Stack**
- Flutter (Dart SDK ^3.7)
- GetX for state management and navigation
- Firebase (Core + Messaging)
- Local persistence with Hive and SharedPreferences
- Background services for steps and sleep tracking
- Notifications via `flutter_local_notifications` and `alarm`

**Project Structure**
- `lib/main.dart` app bootstrap, initialization, routing
- `lib/Controllers` GetX controllers for features
- `lib/views` screens and feature modules
- `lib/services` background tasks, API clients, auth, storage
- `lib/widgets` reusable UI components
- `lib/models` data models
- `lib/consts` constants, colors, images
- `lib/l10n` localization resources
- `assets/` images, icons, sounds, decision tree JSON

**Environment Setup**
Create or update `.env` at the repo root:
```env
PROJECT_ID = snevva-aef81
PATH_TO_SECRET = secrets/key.json
```

`secrets/key.json` is used as a Firebase service account for sending FCM notifications in `lib/notification_service_firebase.dart`. Replace it with your own service account for non-dev usage and avoid committing real production credentials.

**Firebase Setup**
- Android: `android/app/google-services.json` must exist (already present in this repo).
- iOS: add `ios/Runner/GoogleService-Info.plist` for Firebase if you plan to run on iOS.

**Run The App**
1. Install Flutter and platform toolchains (Android Studio or Xcode).
2. Install dependencies:
```bash
flutter pub get
```
3. Run on a device or emulator:
```bash
flutter run
```

**Tests**
Run unit tests:
```bash
flutter test
```

**Notes**
- Background tracking relies on permissions for activity recognition, notifications, and (optionally) location. Ensure device permissions are granted.
- Localization uses Flutter's `gen-l10n` pipeline; resources live in `lib/l10n`.

