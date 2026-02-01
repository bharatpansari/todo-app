import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'category_model.dart';

part 'task_model.g.dart';

/// Repeat type constants
class RepeatType {
  static const String none = 'none';
  static const String daily = 'daily';
  static const String weekly = 'weekly';
  static const String monthly = 'monthly';
  static const String custom = 'custom';
  
  static const List<String> values = [none, daily, weekly, monthly, custom];
  
  static String getLabel(String type) {
    switch (type) {
      case daily: return 'Daily';
      case weekly: return 'Weekly';
      case monthly: return 'Monthly';
      case custom: return 'Custom Days';
      default: return 'No Repeat';
    }
  }
}

/// Task priority constants
class TaskPriority {
  static const int low = 0;
  static const int medium = 1;
  static const int high = 2;
  
  static const List<int> values = [low, medium, high];
  
  static String getLabel(int priority) {
    switch (priority) {
      case high: return 'High';
      case medium: return 'Medium';
      case low: return 'Low';
      default: return 'Medium';
    }
  }
  
  static Color getColor(int priority) {
    switch (priority) {
      case high: return const Color(0xFFE53935); // Red
      case medium: return const Color(0xFFFB8C00); // Orange
      case low: return const Color(0xFF43A047); // Green
      default: return const Color(0xFFFB8C00);
    }
  }
  
  static IconData getIcon(int priority) {
    switch (priority) {
      case high: return Icons.keyboard_double_arrow_up;
      case medium: return Icons.remove;
      case low: return Icons.keyboard_double_arrow_down;
      default: return Icons.remove;
    }
  }
}

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  DateTime scheduledTime;

  @HiveField(4)
  String speakText;

  @HiveField(5)
  bool isCompleted;

  @HiveField(6)
  bool isRepeatEnabled;

  @HiveField(7)
  String categoryId;

  /// Repeat type: 'none', 'daily', 'weekly', 'monthly', 'custom'
  @HiveField(8)
  String repeatType;

  /// For custom repeat: list of weekday indices (1=Monday, 7=Sunday)
  @HiveField(9)
  List<int> customWeekdays;

  /// If this task was detached from a recurring series, this links to parent
  @HiveField(10)
  String? parentTaskId;

  /// True if this is the master recurring task (not a detached occurrence)
  @HiveField(11)
  bool isRecurringSeries;

  /// Task priority: 0=Low, 1=Medium, 2=High
  @HiveField(12)
  int priority;

  /// List of minutes before the scheduled time to trigger a pre-reminder (e.g., [15, 30, 60])
  @HiveField(13)
  List<int> preReminders;

  /// Last update timestamp for sync conflict resolution (last-write-wins)
  @HiveField(14)
  DateTime updatedAt;

  /// List of label IDs attached to this task
  @HiveField(15)
  List<String> labelIds;

  Task({
    String? id,
    required this.title,
    this.description = '',
    required this.scheduledTime,
    required this.speakText,
    this.isCompleted = false,
    this.isRepeatEnabled = false,
    this.categoryId = defaultCategoryId,
    this.repeatType = RepeatType.none,
    this.customWeekdays = const [],
    this.parentTaskId,
    this.isRecurringSeries = false,
    this.priority = TaskPriority.medium,
    this.preReminders = const [],
    this.labelIds = const [],
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Check if this task is recurring
  bool get isRecurring => repeatType != RepeatType.none && isRepeatEnabled;

  /// Calculate the next occurrence based on repeat pattern
  DateTime? getNextOccurrence() {
    if (!isRecurring) return null;
    
    final now = DateTime.now();
    DateTime next = scheduledTime;
    
    // Keep advancing until next occurrence is strictly in the future
    while (!next.isAfter(now)) {
      switch (repeatType) {
        case RepeatType.daily:
          next = next.add(const Duration(days: 1));
          break;
          
        case RepeatType.weekly:
          next = next.add(const Duration(days: 7));
          break;
          
        case RepeatType.monthly:
          // Handle month rollover carefully
          int nextMonth = next.month + 1;
          int nextYear = next.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
          // Handle days that don't exist (e.g., Jan 31 -> Feb 28)
          int daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
          int day = next.day > daysInNextMonth ? daysInNextMonth : next.day;
          next = DateTime(nextYear, nextMonth, day, next.hour, next.minute);
          break;
          
        case RepeatType.custom:
          if (customWeekdays.isEmpty) return null;
          // Find next matching weekday
          next = _getNextCustomWeekday(next);
          break;
          
        default:
          return null;
      }
    }
    
    return next;
  }

  /// Helper for custom weekday calculation
  DateTime _getNextCustomWeekday(DateTime from) {
    DateTime candidate = from.add(const Duration(days: 1));
    
    // Search up to 7 days ahead
    for (int i = 0; i < 7; i++) {
      // DateTime.weekday: 1=Monday, 7=Sunday
      if (customWeekdays.contains(candidate.weekday)) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
    }
    
    // Fallback (shouldn't happen if weekdays is non-empty)
    return from.add(const Duration(days: 7));
  }

  /// Create a copy with updated scheduled time for next occurrence
  Task copyForNextOccurrence() {
    final nextTime = getNextOccurrence();
    if (nextTime == null) return this;
    
    return Task(
      id: id, // Keep same ID for the series
      title: title,
      description: description,
      scheduledTime: nextTime,
      speakText: speakText,
      isCompleted: false,
      isRepeatEnabled: isRepeatEnabled,
      categoryId: categoryId,
      repeatType: repeatType,
      customWeekdays: List.from(customWeekdays),
      parentTaskId: parentTaskId,
      isRecurringSeries: isRecurringSeries,
      priority: priority,
      preReminders: List.from(preReminders),
      // updatedAt defaults to DateTime.now() for new occurrence
    );
  }

  /// Create a detached single occurrence (for "edit this occurrence only")
  Task createDetachedOccurrence() {
    return Task(
      id: const Uuid().v4(), // New ID for detached instance
      title: title,
      description: description,
      scheduledTime: scheduledTime,
      speakText: speakText,
      isCompleted: isCompleted,
      isRepeatEnabled: false, // Not recurring
      categoryId: categoryId,
      repeatType: RepeatType.none,
      customWeekdays: const [],
      parentTaskId: id, // Link to parent
      isRecurringSeries: false,
      priority: priority,
      preReminders: const [],
      // updatedAt defaults to DateTime.now() for detached occurrence
    );
  }

  /// Convert task to JSON for export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'scheduledTime': scheduledTime.toIso8601String(),
      'speakText': speakText,
      'isCompleted': isCompleted,
      'isRepeatEnabled': isRepeatEnabled,
      'categoryId': categoryId,
      'repeatType': repeatType,
      'customWeekdays': customWeekdays,
      'parentTaskId': parentTaskId,
      'isRecurringSeries': isRecurringSeries,
      'priority': priority,
      'preReminders': preReminders,
      'labelIds': labelIds,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create task from JSON for import
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.parse(json['scheduledTime'] as String)
          : DateTime.now(),
      speakText: json['speakText'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      isRepeatEnabled: json['isRepeatEnabled'] as bool? ?? false,
      categoryId: json['categoryId'] as String? ?? defaultCategoryId,
      repeatType: json['repeatType'] as String? ?? RepeatType.none,
      customWeekdays: (json['customWeekdays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      parentTaskId: json['parentTaskId'] as String?,
      isRecurringSeries: json['isRecurringSeries'] as bool? ?? false,
      priority: json['priority'] as int? ?? TaskPriority.medium,
      preReminders: (json['preReminders'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      labelIds: (json['labelIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

