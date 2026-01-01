import 'package:flutter/services.dart';
import '../models/task_model.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.antigravity.todo/alarm');

  Future<void> scheduleTask(Task task) async {
    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'taskId': task.id,
        'triggerAtMillis': task.scheduledTime.millisecondsSinceEpoch,
        'speakText': task.speakText,
      });
      print("Scheduled task: ${task.title} at ${task.scheduledTime}");
    } on PlatformException catch (e) {
      print("Failed to schedule alarm: '${e.message}'.");
    }
  }

  Future<void> cancelTask(String taskId) async {
    try {
      await _channel.invokeMethod('cancelAlarm', {
        'taskId': taskId,
      });
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
}
