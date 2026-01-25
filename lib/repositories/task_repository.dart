import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_model.dart';
import '../services/native_bridge.dart';

class TaskRepository {
  static const String boxName = 'tasksBox';
  final NativeBridge _nativeBridge = NativeBridge();

  Future<Box<Task>> get _box async => await Hive.openBox<Task>(boxName);

  /// Refresh the home screen widget with current tasks
  Future<void> _refreshWidget() async {
    final tasks = await getAllTasks();
    await _nativeBridge.updateHomeWidget(tasks);
  }

  Future<void> addTask(Task task) async {
    final box = await _box;
    await box.add(task);
    await task.save();
    
    await _nativeBridge.scheduleTask(task);
    await _refreshWidget(); // Update widget
  }

  Future<void> updateTask(Task task) async {
    final box = await _box;
    
    // Find the existing task in the box associated with this ID
    try {
      final existingTask = box.values.firstWhere((t) => t.id == task.id);
      
      // Update fields
      existingTask.title = task.title;
      existingTask.description = task.description;
      existingTask.scheduledTime = task.scheduledTime;
      existingTask.speakText = task.speakText;
      existingTask.isCompleted = task.isCompleted;
      existingTask.isRepeatEnabled = task.isRepeatEnabled;
      existingTask.categoryId = task.categoryId;
      existingTask.repeatType = task.repeatType;
      existingTask.customWeekdays = task.customWeekdays;
      existingTask.priority = task.priority;
      // Do not overwrite parentTaskId or isRecurringSeries unless intended, but usually safe to copy for edits
      existingTask.parentTaskId = task.parentTaskId;
      existingTask.isRecurringSeries = task.isRecurringSeries;
      
      await existingTask.save();
      
      // Reschedule
      if (!existingTask.isCompleted && existingTask.scheduledTime.isAfter(DateTime.now())) {
        await _nativeBridge.scheduleTask(existingTask);
      } else {
        await _nativeBridge.cancelTask(existingTask);
      }
      
      await _refreshWidget(); // Update widget
    } catch (e) {
      print("Error updating task: Task with id ${task.id} not found in box. Error: $e");
    }
  }

  Future<void> deleteTask(Task task) async {
    await _nativeBridge.cancelTask(task);
    await task.delete();
    await _refreshWidget(); // Update widget
  }

  Future<List<Task>> getAllTasks() async {
    final box = await _box;
    return box.values.toList();
  }

  /// Get a task by its ID
  Future<Task?> getTaskById(String taskId) async {
    final box = await _box;
    try {
      return box.values.firstWhere((t) => t.id == taskId);
    } catch (e) {
      return null;
    }
  }

  /// Handle when an alarm fires - for recurring tasks, calculate and schedule next occurrence
  Future<void> handleAlarmFired(String taskId) async {
    final task = await getTaskById(taskId);
    if (task == null) {
      print("Task not found for alarm: $taskId");
      return;
    }

    print("Alarm fired for task: ${task.title} (recurring: ${task.isRecurring})");

    if (task.isRecurring) {
      // Calculate next occurrence
      final nextTime = task.getNextOccurrence();
      if (nextTime != null) {
        // Update task with next scheduled time
        task.scheduledTime = nextTime;
        await task.save();
        
        // Schedule next alarm
        await _nativeBridge.scheduleTask(task);
        print("Rescheduled recurring task: ${task.title} for $nextTime");
      }
    }
  }

  /// Create a detached occurrence from a recurring task
  Future<Task> createDetachedOccurrence(Task parentTask, {
    String? newTitle,
    DateTime? newScheduledTime,
    String? newSpeakText,
  }) async {
    final detached = parentTask.createDetachedOccurrence();
    if (newTitle != null) detached.title = newTitle;
    if (newScheduledTime != null) detached.scheduledTime = newScheduledTime;
    if (newSpeakText != null) detached.speakText = newSpeakText;
    
    await addTask(detached);
    
    // If the parent's current scheduled time was detached, advance parent to next occurrence
    if (parentTask.scheduledTime.isAtSameMomentAs(detached.scheduledTime)) {
      final nextTime = parentTask.getNextOccurrence();
      if (nextTime != null) {
        parentTask.scheduledTime = nextTime;
        await updateTask(parentTask);
      }
    }
    
    return detached;
  }

  /// Handle when a task is snoozed via notification
  Future<void> handleTaskSnoozed(String taskId, int snoozeMinutes) async {
    final task = await getTaskById(taskId);
    if (task == null) {
      print("Task not found for snooze: $taskId");
      return;
    }

    print("Task snoozed: ${task.title} for $snoozeMinutes minutes");
    // The native side handles the alarm rescheduling, 
    // we just keep the task state as-is (not completed)
  }

  /// Handle when a task is marked done via notification
  Future<void> handleTaskMarkedDone(String taskId) async {
    final task = await getTaskById(taskId);
    if (task == null) {
      print("Task not found for mark done: $taskId");
      return;
    }

    print("Task marked done via notification: ${task.title}");
    
    // Mark as completed
    task.isCompleted = true;
    await task.save();
    
    // Cancel any scheduled alarms for this task
    await _nativeBridge.cancelTask(task);
    
    // If recurring, schedule the next occurrence
    if (task.isRecurring) {
      final nextTime = task.getNextOccurrence();
      if (nextTime != null) {
        task.scheduledTime = nextTime;
        task.isCompleted = false;
        await task.save();
        await _nativeBridge.scheduleTask(task);
        print("Rescheduled recurring task: ${task.title} for $nextTime");
      }
    }
  }
}

