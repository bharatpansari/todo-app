# Talkative Todo App

A production-grade Android reminder app that speaks your tasks out loud at the exact scheduled time, using Flutter for UI and Native Kotlin for reliable background execution.

## Features
- **Reliable Alarms**: Uses `AlarmManager.setExactAndAllowWhileIdle` to wake up even from Doze mode.
- **Background Speech**: Uses a Foreground Service with WakeLock to ensure TTS completes even if the screen is off or app is closed.
- **Boot Persistence**: Reschedules all alarms after device reboot.
- **Silent Override**: Plays TTS on the `STREAM_ALARM` channel using AudioFocus.

## Prerequisites
- Android SDK 34
- Flutter SDK 3.0+
- A real Android device (Emulators may behave differently with Doze/Alarms).

## Setup & Running
1. **Dependencies**:
   run `flutter pub get` in this directory.

2. **Run the App**:
   run `flutter run` on your connected Android device.

## Important Permissions
On Android 12+ (API 31+), the app requires two special permissions which must be granted by the user:
1. **Exact Alarms**: The app will prompt you to "Allow Exact Alarms" in settings. This is required for precise timing.
2. **Battery Optimization**: Use the Settings icon in the app to "Ignore Battery Optimizations". This prevents the OS from killing the alarm service.

## Project Structure
- `lib/`: Flutter UI and Logic.
  - `models/`: Hive database models.
  - `services/`: `NativeBridge` for communicating with Kotlin.
  - `ui/`: Modern Material 3 Interface.
- `android/app/src/main/kotlin/com/antigravity/todo/`: Native Kotlin Code.
  - `AlarmScheduler.kt`: Manages `AlarmManager`.
  - `SpeakForegroundService.kt`: Handles TTS and WakeLocks.

## Limitations
- **Device Shutdown**: If the phone is completely powered off at the alarm time, the alarm will not fire. It will NOT fire upon reboot unless logic is added to check for "missed" alarms (currently it only reschedules future alarms).
- **Do not Disturb (DND)**: The app uses `STREAM_ALARM`. Most DND settings allow Alarms through, but if "Alarms" are muted in DND, it might be silent.
- **OEM Killers**: Devices like Xiaomi/OnePlus may kill the app services. Whitelisting in "Auto Start" is recommended.
