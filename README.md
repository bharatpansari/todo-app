# Talkative Todo - Native Android Reminder App

A Flutter-based simplified Todo/Reminder app that uses native Android capabilities for reliable background scheduling and Text-to-Speech (TTS) announcements.

## Features
- **Reliable Alarms**: Uses `AlarmManager` (Android) to trigger exact alarms even if the app is killed.
- **Background Speaking**: Uses Android `TextToSpeech` API to speak the task title/description when the alarm fires, without needing to open the app.
- **Snooze & Mark Done**: When an alarm fires, the notification shows "Snooze 5m", "Snooze 10m", and "Done" action buttons.
- **Home Screen Widget**: Android widget showing next 3 upcoming tasks, tap to open app.
- **Stats Dashboard**: Track completed vs pending tasks, weekly/monthly counts, and completion streaks.
- **Export & Import**: Export tasks to JSON/CSV and import with merge or replace options.
- **Persistent Storage**: Uses `Hive` for fast, offline-first local storage.
- **Categorization**: Organize tasks by categories with color coding.
- **Recurring Tasks**: Support for Daily, Weekly, Monthly, and Custom recurrence.
- **Task Priorities**: Assign Low, Medium, or High priority to tasks.
- **Task Notes**: Add detailed multi-line descriptions to your tasks.
- **TTS Settings**: Configure speech language, rate, pitch, and volume.
- **Dark Mode**: Support for Light, Dark, and System themes.

## Architecture
- **Flutter UI**: Handles all user interaction (Add/Edit tasks, List view, Settings).
- **Native Bridge (`MethodChannel`)**: Communicates with Android-native code (Kotlin) for scheduling and permissions.
- **Android Services**:
    - `AlarmReceiver`: Wakes up the device.
    - `AudioService`: Handles TTS and audio focus/volume management.
    - `RescheduleReceiver`: Reschedules alarms after device reboot.

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

## Usage
1. Grant "Notification" and "Exact Alarm" permissions on first launch.
2. Create a new task by tapping the "+" FAB.
3. Set a Title, Priority, Category, and Date/Time.
4. Toggle "Repeat" if you want the task to recur.
   - Choose Daily, Weekly, Monthly, or Custom days.
5. (Optional) Enter specific text to speak.
6. Save. The app will schedule the native alarm.
7. **Theme Settings**: Tap the "Settings" (gear) icon in the app bar to switch between Light, Dark, or System theme.
8. **TTS Settings**: In Settings, tap "TTS Settings" to configure voice language (English, Hindi, etc.), speech rate, pitch, and volume. Use "Test Voice" to preview.
9. **Stats Dashboard**: Tap the bar chart icon (📊) in the app bar to view your statistics.

## Testing
- **Unit/Widget Tests**: `flutter test`
- **Manual Verification**:
    - Create a task for 1 minute in the future.
    - Kill the app.
    - Wait for the voice reminder.
    - Reboot device and ensure alarms still fire.
    - Switch themes in Settings and verify UI updates immediately.

### Snooze Feature Testing
1. **Basic Snooze**: Create a task, let it fire, tap "Snooze 5m" → speaking stops → alarm fires again in 5 min.
2. **Mark Done**: Create a task, let it fire, tap "Done" → task is marked complete in app.
3. **Multiple Alarms**: Create two tasks close together, verify snooze actions don't conflict.
4. **Snooze + Recurring**: Snooze a recurring task, verify next recurrence still works.
5. **App Restart**: Snooze an alarm, force-close app, verify snoozed alarm still fires.

### Stats Dashboard Testing
1. Create several tasks with different completion states.
2. Open Stats Dashboard → verify completed/pending counts are correct.
3. Complete a task → go back and reopen Stats → verify counts update immediately.
4. Check weekly/monthly counts based on task scheduled times.
5. Complete tasks on consecutive days to build streak → verify streak count.

### Export & Import Testing
1. Create several tasks with different settings.
2. Open Settings → Export Tasks → JSON → share/save file.
3. Verify JSON file contains all task fields.
4. Export as CSV → open in spreadsheet → verify columns.
5. Fresh install or clear data → Import Tasks → Merge → select JSON → verify tasks restored.
6. Import with Replace All → verify all existing tasks replaced.
7. Import duplicate file with Merge → verify duplicates skipped.
