import '../repositories/task_repository.dart';
import '../models/task_model.dart';

/// Service for calculating task statistics
class StatsService {
  final TaskRepository _taskRepository = TaskRepository();

  /// Get all tasks and calculate statistics
  Future<TaskStats> getStats() async {
    final tasks = await _taskRepository.getAllTasks();
    return TaskStats.fromTasks(tasks);
  }
}

/// Data class holding computed task statistics
class TaskStats {
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final int weeklyCompleted;
  final int monthlyCompleted;
  final int currentStreak;
  final int longestStreak;

  TaskStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.weeklyCompleted,
    required this.monthlyCompleted,
    required this.currentStreak,
    required this.longestStreak,
  });

  double get completionRate => 
      totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;

  /// Calculate all stats from a list of tasks
  factory TaskStats.fromTasks(List<Task> tasks) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    int completed = 0;
    int pending = 0;
    int weeklyCompleted = 0;
    int monthlyCompleted = 0;
    
    // Track completion dates for streak calculation
    Set<String> completionDates = {};
    
    for (final task in tasks) {
      if (task.isCompleted) {
        completed++;
        
        // Use scheduledTime as "completion date" proxy
        // (In a more robust system, we'd have a separate completedAt field)
        final completedDate = task.scheduledTime;
        final dateKey = '${completedDate.year}-${completedDate.month}-${completedDate.day}';
        completionDates.add(dateKey);
        
        // Check if completed this week
        if (completedDate.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
          weeklyCompleted++;
        }
        
        // Check if completed this month
        if (completedDate.isAfter(startOfMonth.subtract(const Duration(days: 1)))) {
          monthlyCompleted++;
        }
      } else {
        pending++;
      }
    }
    
    // Calculate streaks
    final streaks = _calculateStreaks(completionDates, now);
    
    return TaskStats(
      totalTasks: tasks.length,
      completedTasks: completed,
      pendingTasks: pending,
      weeklyCompleted: weeklyCompleted,
      monthlyCompleted: monthlyCompleted,
      currentStreak: streaks['current']!,
      longestStreak: streaks['longest']!,
    );
  }

  /// Calculate current and longest streaks from completion dates
  static Map<String, int> _calculateStreaks(Set<String> completionDates, DateTime now) {
    if (completionDates.isEmpty) {
      return {'current': 0, 'longest': 0};
    }

    // Sort dates
    List<DateTime> dates = completionDates.map((dateStr) {
      final parts = dateStr.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }).toList();
    dates.sort();

    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 1;

    // Calculate longest streak
    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff == 1) {
        tempStreak++;
      } else if (diff > 1) {
        longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;
        tempStreak = 1;
      }
      // diff == 0 means same day, skip
    }
    longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;

    // Calculate current streak (counting backwards from today)
    final todayKey = '${now.year}-${now.month}-${now.day}';
    final yesterdayKey = () {
      final yesterday = now.subtract(const Duration(days: 1));
      return '${yesterday.year}-${yesterday.month}-${yesterday.day}';
    }();

    if (completionDates.contains(todayKey) || completionDates.contains(yesterdayKey)) {
      // Start counting from today or yesterday
      DateTime checkDate = completionDates.contains(todayKey) ? now : now.subtract(const Duration(days: 1));
      
      while (true) {
        final key = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
        if (completionDates.contains(key)) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    return {'current': currentStreak, 'longest': longestStreak};
  }
}
