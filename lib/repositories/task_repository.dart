import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_model.dart';
import '../services/native_bridge.dart';

class TaskRepository {
  static const String boxName = 'tasksBox';
  final NativeBridge _nativeBridge = NativeBridge();

  Future<Box<Task>> get _box async => await Hive.openBox<Task>(boxName);

  Future<void> addTask(Task task) async {
    final box = await _box;
    await box.add(task); // Hive assigns key automagically or we can use generic add
    // Use the auto-generated key or our UUID? Task has a UUID field 'id'.
    // Better to store by that ID if we want O(1) by ID, but for list just .values is fine.
    // Let's just save.
    await task.save();
    
    await _nativeBridge.scheduleTask(task);
  }

  Future<void> updateTask(Task task) async {
    await task.save();
    // Reschedule
    if (!task.isCompleted && task.scheduledTime.isAfter(DateTime.now())) {
      await _nativeBridge.scheduleTask(task);
    } else {
        await _nativeBridge.cancelTask(task.id);
    }
  }

  Future<void> deleteTask(Task task) async {
    await _nativeBridge.cancelTask(task.id);
    await task.delete();
  }

  Future<List<Task>> getAllTasks() async {
    final box = await _box;
    return box.values.toList();
  }
}
