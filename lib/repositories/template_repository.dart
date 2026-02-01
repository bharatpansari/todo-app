import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import 'task_repository.dart';

class TemplateTaskData {
  String title;
  String description;
  int dayOffset; // 0 = first day, 1 = next day, etc.
  int hour;
  int minute;
  int priority;
  String speakText;
  String repeatType;
  List<int> customWeekdays;
  List<int> preReminders;

  TemplateTaskData({
    required this.title,
    this.description = '',
    this.dayOffset = 0,
    this.hour = 9,
    this.minute = 0,
    this.priority = 1,
    this.speakText = '',
    this.repeatType = 'none',
    this.customWeekdays = const [],
    this.preReminders = const [],
  });
  
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'dayOffset': dayOffset,
    'hour': hour,
    'minute': minute,
    'priority': priority,
    'speakText': speakText,
    'repeatType': repeatType,
    'customWeekdays': customWeekdays,
    'preReminders': preReminders,
  };

  factory TemplateTaskData.fromJson(Map<String, dynamic> json) => TemplateTaskData(
    title: json['title'],
    description: json['description'] ?? '',
    dayOffset: json['dayOffset'] ?? 0,
    hour: json['hour'] ?? 9,
    minute: json['minute'] ?? 0,
    priority: json['priority'] ?? 1,
    speakText: json['speakText'] ?? '',
    repeatType: json['repeatType'] ?? 'none',
    customWeekdays: List<int>.from(json['customWeekdays'] ?? []),
    preReminders: List<int>.from(json['preReminders'] ?? []),
  );
}

class TaskTemplate {
  String id;
  String name;
  List<TemplateTaskData> tasks;
  
  TaskTemplate({
    String? id,
    required this.name,
    required this.tasks,
  }) : id = id ?? const Uuid().v4();
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };
  
  factory TaskTemplate.fromJson(Map<String, dynamic> json) => TaskTemplate(
    id: json['id'],
    name: json['name'],
    tasks: (json['tasks'] as List).map((t) => TemplateTaskData.fromJson(t)).toList(),
  );
}

class TemplateRepository {
  static const String _boxName = 'templates'; // Hive box for templates
  final TaskRepository _taskRepository = TaskRepository();

  Future<Box<String>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<String>(_boxName);
    }
    return Hive.box<String>(_boxName);
  }

  /// Save a list of tasks as a template
  Future<void> saveTemplateFromTasks(String name, List<Task> sourceTasks) async {
    if (sourceTasks.isEmpty) return;
    
    // Sort logic to find baseline
    List<Task> sorted = List.from(sourceTasks);
    sorted.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    
    final baseDate = DateTime(
      sorted.first.scheduledTime.year,
      sorted.first.scheduledTime.month,
      sorted.first.scheduledTime.day,
    );
    
    final templateTasks = sorted.map((task) {
      final taskDate = DateTime(
        task.scheduledTime.year,
        task.scheduledTime.month,
        task.scheduledTime.day,
      );
      final offset = taskDate.difference(baseDate).inDays;
      
      return TemplateTaskData(
        title: task.title,
        description: task.description,
        dayOffset: offset,
        hour: task.scheduledTime.hour,
        minute: task.scheduledTime.minute,
        priority: task.priority,
        speakText: task.speakText,
        repeatType: task.repeatType,
        customWeekdays: task.customWeekdays,
        preReminders: task.preReminders,
      );
    }).toList();
    
    final template = TaskTemplate(name: name, tasks: templateTasks);
    final box = await _getBox();
    await box.put(template.id, jsonEncode(template.toJson()));
  }

  /// Get all saved templates
  Future<List<TaskTemplate>> getTemplates() async {
    final box = await _getBox();
    final List<TaskTemplate> templates = [];
    
    for (var key in box.keys) {
      final jsonStr = box.get(key);
      if (jsonStr != null) {
        try {
          templates.add(TaskTemplate.fromJson(jsonDecode(jsonStr)));
        } catch (e) {
          print("Error parsing template $key: $e");
        }
      }
    }
    return templates;
  }

  /// Delete a template
  Future<void> deleteTemplate(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  /// Apply a template to a specific start date and category
  Future<void> applyTemplate(TaskTemplate template, DateTime startDate, String categoryId) async {
    final baseDate = DateTime(startDate.year, startDate.month, startDate.day);
    
    for (var tData in template.tasks) {
      final taskDate = baseDate.add(Duration(days: tData.dayOffset));
      final scheduledTime = DateTime(
        taskDate.year,
        taskDate.month,
        taskDate.day,
        tData.hour,
        tData.minute,
      );
      
      final newTask = Task(
        title: tData.title,
        description: tData.description,
        scheduledTime: scheduledTime,
        speakText: tData.speakText,
        categoryId: categoryId,
        priority: tData.priority,
        isRepeatEnabled: tData.repeatType != 'none',
        repeatType: tData.repeatType,
        customWeekdays: tData.customWeekdays,
        preReminders: tData.preReminders,
        isCompleted: false,
      );
      
      await _taskRepository.addTask(newTask);
    }
  }
}
