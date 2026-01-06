import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../repositories/task_repository.dart';
import 'add_edit_task_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/native_bridge.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TaskRepository _repository = TaskRepository();
  List<Task> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await _repository.getAllTasks();
    tasks.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _deleteTask(Task task) async {
    await _repository.deleteTask(task);
    _loadTasks();
  }
  
  String _formatDate(DateTime date) {
    if (date.day == DateTime.now().day && 
        date.month == DateTime.now().month && 
        date.year == DateTime.now().year) {
      return 'Today, ${DateFormat.jm().format(date)}';
    }
    return DateFormat('MMM d, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Daily Tasks'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: () {
               // Show settings/permissions dialog
               _showPermissionsDialog();
            },
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.clipboardList, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text("No tasks yet!", style: TextStyle(color: Colors.grey[500], fontSize: 18)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  final isPast = task.scheduledTime.isBefore(DateTime.now());
                  return Dismissible(
                    key: Key(task.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(LucideIcons.trash2, color: Colors.red),
                    ),
                    onDismissed: (_) => _deleteTask(task),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(20),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEditTaskScreen(task: task),
                            ),
                          );
                          _loadTasks();
                        },
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isPast ? Colors.grey[100] : Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isPast ? LucideIcons.checkCircle : LucideIcons.clock,
                            color: isPast ? Colors.grey : Theme.of(context).primaryColor,
                          ),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            decoration: isPast ? TextDecoration.lineThrough : null,
                            color: isPast ? Colors.grey : Colors.black87,
                          ),
                        ),
                        subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                const SizedBox(height: 4),
                                Text(
                                    _formatDate(task.scheduledTime),
                                    style: TextStyle(
                                        color: isPast ? Colors.grey : Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w500,
                                    ),
                                ),
                                if (task.speakText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Icon(LucideIcons.volume2, size: 14, color: Colors.grey[400]),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                                '"${task.speakText}"',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                            ]
                        ),
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditTaskScreen(),
            ),
          );
          _loadTasks();
        },
        backgroundColor: Colors.black,
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text("New Task", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showPermissionsDialog() {
      showDialog(
          context: context, 
          builder: (context) => AlertDialog(
              title: const Text("Settings & Permissions"),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      ListTile(
                          title: const Text("Allow Exact Alarms"),
                          subtitle: const Text("Required for precise timing"),
                          trailing: const Icon(LucideIcons.arrowRight),
                          onTap: () {
                              final repo = TaskRepository();
                              // We need to access bridge from here, but repo has it private.
                              // Quick fix: repo method or public bridge.
                              // Let's instantiate bridge directly for settings.
                              NativeBridge().requestExactAlarmPermission();
                          },
                      ),
                      ListTile(
                          title: const Text("Ignore Battery Optimizations"),
                          subtitle: const Text("Prevents delayed alarms"),
                          trailing: const Icon(LucideIcons.arrowRight),
                          onTap: () {
                              NativeBridge().requestBatteryOptimizationIgnore();
                          },
                      ),
                  ],
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
              ],
          )
      );
  }
}
