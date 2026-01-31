import 'dart:convert';

import 'package:flutter/services.dart';
import '../models/task_model.dart';
import '../repositories/settings_repository.dart';

/// Callback for when an alarm fires
typedef AlarmFiredCallback = void Function(String taskId);

/// Callback for when a task is snoozed via notification
typedef TaskSnoozedCallback = void Function(String taskId, int snoozeMinutes);

/// Callback for when a task is marked done via notification
typedef TaskMarkedDoneCallback = void Function(String taskId);

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.example.talkative_todo/alarm');
  static AlarmFiredCallback? _alarmFiredCallback;
  static TaskSnoozedCallback? _taskSnoozedCallback;
  static TaskMarkedDoneCallback? _taskMarkedDoneCallback;
  static bool _isListenerSetup = false;
  
  final SettingsRepository _settings = SettingsRepository();

  NativeBridge() {
    _setupMethodCallHandler();
  }

  /// Setup the method call handler for receiving callbacks from Kotlin
  void _setupMethodCallHandler() {
    if (_isListenerSetup) return;
    _isListenerSetup = true;
    
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAlarmFired':
          final taskId = call.arguments['taskId'] as String?;
          if (taskId != null && _alarmFiredCallback != null) {
            _alarmFiredCallback!(taskId);
          }
          break;
          
        case 'onTaskSnoozed':
          final taskId = call.arguments['taskId'] as String?;
          final snoozeMinutes = call.arguments['snoozeMinutes'] as int?;
          if (taskId != null && snoozeMinutes != null && _taskSnoozedCallback != null) {
            _taskSnoozedCallback!(taskId, snoozeMinutes);
          }
          break;
          
        // DEPRECATED: Mark-done callback removed - now using "Dismiss" button
        // case 'onTaskMarkedDone':
        //   final taskId = call.arguments['taskId'] as String?;
        //   if (taskId != null && _taskMarkedDoneCallback != null) {
        //     _taskMarkedDoneCallback!(taskId);
        //   }
        //   break;
      }
      return null;
    });
  }

  /// Set callback for when an alarm fires (used for recurring task auto-reschedule)
  static void setAlarmFiredCallback(AlarmFiredCallback callback) {
    _alarmFiredCallback = callback;
  }

  /// Set callback for when a task is snoozed via notification
  static void setTaskSnoozedCallback(TaskSnoozedCallback callback) {
    _taskSnoozedCallback = callback;
  }

  // DEPRECATED: Mark-done callback removed - now using "Dismiss" button
  // static void setTaskMarkedDoneCallback(TaskMarkedDoneCallback callback) {
  //   _taskMarkedDoneCallback = callback;
  // }

  /// Helper to resolve language aliases (e.g., hinglish -> hi-IN)
  String _resolveLanguage(String language) {
    if (language == 'hinglish') {
      return 'hi-IN';
    }
    return language;
  }

  Future<void> scheduleTask(Task task) async {
    try {
      // Get current TTS settings
      final ttsSettings = _settings.getTtsSettings();
      final language = _resolveLanguage(ttsSettings['language']);
      
      // 1. Schedule MAIN alarm (at scheduled time)
      await _channel.invokeMethod('scheduleAlarm', {
        'taskId': task.id,
        'requestCode': 0, // 0 for main alarm
        'triggerAtMillis': task.scheduledTime.millisecondsSinceEpoch,
        'speakText': task.speakText,
        'isRecurring': task.isRecurring,
        'repeatType': task.repeatType,
        'ttsLanguage': language,
        'ttsSpeechRate': ttsSettings['speechRate'],
        'ttsPitch': ttsSettings['pitch'],
        'ttsVolume': ttsSettings['volume'],
      });
      print("Scheduled main task: ${task.title} at ${task.scheduledTime}");

      // 2. Schedule PRE-REMINDERS (if any)
      for (final minutes in task.preReminders) {
        final triggerTime = task.scheduledTime.subtract(Duration(minutes: minutes));
        
        // Skip if pre-reminder time is already past
        if (triggerTime.isBefore(DateTime.now())) continue;

        // Create speak text for pre-reminder, e.g., "Meeting in 15 minutes"
        final preSpeakText = "${task.title}, in $minutes minutes";

        await _channel.invokeMethod('scheduleAlarm', {
          'taskId': task.id,
          'requestCode': minutes, // Use minutes as request code offset
          'triggerAtMillis': triggerTime.millisecondsSinceEpoch,
          'speakText': preSpeakText,
          'isRecurring': false, // Pre-reminders don't auto-reschedule themselves
          'repeatType': 'none',
          'ttsLanguage': language,
          'ttsSpeechRate': ttsSettings['speechRate'],
          'ttsPitch': ttsSettings['pitch'],
          'ttsVolume': ttsSettings['volume'],
        });
        print("Scheduled pre-reminder ($minutes m) at $triggerTime");
      }

    } on PlatformException catch (e) {
      print("Failed to schedule alarm: '${e.message}'.");
    }
  }

  Future<void> cancelTask(Task task) async {
    try {
      // Cancel main alarm
      await _channel.invokeMethod('cancelAlarm', {
        'taskId': task.id,
        'requestCode': 0,
      });

      // Cancel all potential pre-reminders
      // Combine task's current pre-reminders with standard intervals to ensure
      // complete cancellation even if user edited/removed some reminders
      final allPreReminders = {...task.preReminders, 15, 30, 60};
      for (final minutes in allPreReminders) {
        await _channel.invokeMethod('cancelAlarm', {
          'taskId': task.id,
          'requestCode': minutes,
        });
      }

    } on PlatformException catch (e) {
      print("Failed to cancel alarm: '${e.message}'.");
    }
  }

  Future<void> rescheduleAll(List<Task> tasks) async {
    for (var task in tasks) {
      if (!task.isCompleted && task.scheduledTime.isAfter(DateTime.now())) {
        await scheduleTask(task);
      }
    }
  }

  Future<void> requestExactAlarmPermission() async {
    try {
      await _channel.invokeMethod('requestExactAlarmPermission');
    } on PlatformException catch (e) {
       print("Failed to request permission: ${e.message}");
    }
  }

  Future<void> requestBatteryOptimizationIgnore() async {
      try {
          await _channel.invokeMethod('requestBatteryOptimizationIgnore');
      } on PlatformException catch (e) {
          print("Failed battery opt request: ${e.message}");
      }
  }

  /// Test TTS with current settings
  /// Returns: 'available', 'missing_data', 'not_supported', or 'unknown'
  Future<String> testTts(String text) async {
    try {
      final ttsSettings = _settings.getTtsSettings();
      final resolvedLanguage = _resolveLanguage(ttsSettings['language']);
      print("NativeBridge.testTts: Calling with language=$resolvedLanguage (original=${ttsSettings['language']})");
      
      final String? result = await _channel.invokeMethod('testTts', {
        'text': text,
        'ttsLanguage': resolvedLanguage,
        'ttsSpeechRate': ttsSettings['speechRate'],
        'ttsPitch': ttsSettings['pitch'],
        'ttsVolume': ttsSettings['volume'],
      });
      print("NativeBridge.testTts: Received result=$result");
      return result ?? 'unknown';
    } on PlatformException catch (e) {
      print("Failed to test TTS: ${e.message}");
      rethrow;
    }
  }

  /// Check if a language is available on the device
  /// Returns: 'available', 'missing_data', 'not_supported', or 'unknown'
  Future<String> isLanguageAvailable(String language) async {
    try {
      final String? result = await _channel.invokeMethod('isLanguageAvailable', {
        'language': _resolveLanguage(language),
      });
      return result ?? 'unknown';
    } on PlatformException catch (e) {
      print("Failed to check language availability: ${e.message}");
      return 'unknown';
    }
  }

  /// Open Android TTS Settings screen
  Future<void> openTtsSettings() async {
    try {
      await _channel.invokeMethod('openTtsSettings');
    } on PlatformException catch (e) {
      print("Failed to open TTS settings: ${e.message}");
    }
  }

  /// Update the home screen widget with upcoming tasks
  Future<void> updateHomeWidget(List<Task> tasks) async {
    try {
      // Get upcoming tasks (not completed, scheduled in future, sorted by time)
      final upcomingTasks = tasks
          .where((t) => !t.isCompleted && t.scheduledTime.isAfter(DateTime.now()))
          .toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      
      // Take only top 3
      final top3 = upcomingTasks.take(3).toList();
      
      // Convert to JSON format for widget using proper encoding
      final tasksJson = top3.map((t) => {
        'id': t.id,
        'title': t.title,
        'time': t.scheduledTime.toIso8601String(),
      }).toList();
      
      await _channel.invokeMethod('updateWidget', {
        'tasksJson': jsonEncode(tasksJson),
      });
      
      print("Updated home widget with ${top3.length} tasks");
    } on PlatformException catch (e) {
      print("Failed to update widget: ${e.message}");
    }
  }
}

