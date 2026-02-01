# Talkative Todo - Native Android Reminder App

A Flutter-based simplified Todo/Reminder app that uses native Android capabilities for reliable background scheduling and Text-to-Speech (TTS) announcements.

## Features
- **Reliable Alarms**: Uses `AlarmManager` (Android) to trigger exact alarms even if the app is killed.
- **Background Speaking**: Uses Android `TextToSpeech` API to speak the task title/description when the alarm fires, without needing to open the app.
- **Voice-to-Task**: "Ramble Mode" - Record your thoughts, and the app transcribes and prepares a task for you.
- **Project Templates**: Save project lists as templates and reuse them with relative dates (e.g., "Camping Trip").
- **Pro Gating**: Freemium model with limits for casual users and "Pro" unlock for power users.
- **Snooze & Mark Done**: Notification actions for quick control.
- **Home Screen Widget**: View next 3 upcoming tasks.
- **Stats Dashboard**: Track completion streaks and productivity.
- **Export & Import**: JSON/CSV backup and restore.
- **Recurring Tasks**: Daily, Weekly, Monthly, and Custom recurrence support.
- **Task Priorities**: Low, Medium, High.
- **Dark Mode**: System-aware theming.

## Free vs Pro Plan

| Feature | Free Plan | Pro Plan |
| :--- | :--- | :--- |
| **Projects (Categories)** | Max 5 | Unlimited |
| **Labels** | Max 10 | Unlimited |
| **Reminders per Task** | 1 | Unlimited |
| **Views** | List View Only | Board & Calendar Views |
| **Voice-to-Task** | Locked | **Unlocked** |
| **Templates** | Locked | **Unlocked** |
| **Price** | Free | $9.99 (Stub) |

> **Note**: This app uses a "Stub" billing system for demonstration. Clicking "Upgrade" will instantly unlock Pro features without charging any money.

## Setup & Running

### Prerequisites
- Flutter SDK (3.0+)
- Android SDK (min SDK 21)
- Windows/Mac/Linux for development

### Commands
1. **Get Dependencies**
   ```bash
   flutter pub get
   ```

2. **Run on Android Emulator/Device**
   ```bash
   flutter run
   ```

3. **Build APK**
   ```bash
   flutter build apk
   ```

## Key Flows

### 1. Creating a Task
- Tap the **+** FAB.
- **Voice**: Tap the Mic icon on the home screen to dictate.
- **Typed**: Enter title, schedule time.
- **Reminders**: Free users get 1 reminder. Pro users can add 15m, 1h, 1d ahead reminders.

### 2. Using Templates (Pro)
- Filter by a category (e.g., "Trip").
- Tap the **Templates** icon in AppBar.
- Select "Save Current View as Template".
- Later, apply this template to generate a new set of tasks starting from a specific date.

### 3. Subscription
- Go to **Settings > Subscription**.
- Tap "Upgrade" to unlock Board/Calendar views, unlimited reminders, and more.
- The status is saved locally on the device (Hive).

## Architecture
- **State Management**: `setState` + Repository Pattern.
- **Local Storage**: `Hive` (NoSQL).
- **Native Bridge**: `MethodChannel` for `AlarmManager` and `TextToSpeech`.
- **Permissions**: `permission_handler` for Notification, Microphone, Exact Alarm.

## Testing
- **Unit/Widget Tests**: `flutter test`
    - Covers `ProService` logic and `QuickAddSheet` UI.
- **Manual Verification**:
    - **Pro Lock**: Verify Paywall appears when exceeding limits.
    - **Voice**: Verify logic handles permission denial gracefully.
