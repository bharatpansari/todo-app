import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/task_model.dart';
import '../../repositories/task_repository.dart';

import '../widgets/task_tile.dart';

class CalendarView extends StatefulWidget {
  final List<Task> tasks;
  final Function(Task) onTaskUpdated;
  final Function(Task) onTaskDeleted;

  const CalendarView({
    super.key,
    required this.tasks,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  final TaskRepository _taskRepository = TaskRepository();
  
  // Tasks mapped by Date (normalized to midnight)
  Map<DateTime, List<Task>> _tasksByDate = {};
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _groupTasks();
  }

  @override
  void didUpdateWidget(CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      _groupTasks();
    }
  }

  void _groupTasks() {
    final Map<DateTime, List<Task>> grouped = {};
    for (final task in widget.tasks) {
      final date = DateTime(
        task.scheduledTime.year, 
        task.scheduledTime.month, 
        task.scheduledTime.day
      );
      if (grouped[date] == null) grouped[date] = [];
      grouped[date]!.add(task);
    }

    setState(() {
      _tasksByDate = grouped;
    });
  }

  List<Task> _getTasksForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _tasksByDate[date] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTasks = _getTasksForDay(_selectedDay ?? _focusedDay);

    return Column(
      children: [
        TableCalendar<Task>(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: _calendarFormat,
          
          eventLoader: _getTasksForDay,
          
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            }
          },
          
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() {
                _calendarFormat = format;
              });
            }
          },
          
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          
          headerStyle: const HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
          ),
        ),
        
        const Divider(),
        
        Expanded(
          child: selectedTasks.isEmpty
              ? Center(
                  child: Text(
                    'No tasks for this day',
                    style: TextStyle(color: theme.hintColor),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // Fab spacing
                  itemCount: selectedTasks.length,
                  itemBuilder: (context, index) {
                    final task = selectedTasks[index];
                    return TaskTile(
                      task: task,
                      onToggleComplete: (value) async {
                         task.isCompleted = value;
                         await _taskRepository.updateTask(task);
                         widget.onTaskUpdated(task);
                      },
                      onDelete: () async {
                        await _taskRepository.deleteTask(task);
                        widget.onTaskDeleted(task);
                      },
                      onRefresh: () => widget.onTaskUpdated(task),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
