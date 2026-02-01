import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../models/task_model.dart';
import '../../models/category_model.dart';
import '../../models/label_model.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/label_repository.dart';
import '../../main.dart';

/// A compact bottom sheet for quickly adding tasks
class QuickAddSheet extends StatefulWidget {
  final VoidCallback onTaskAdded;
  
  const QuickAddSheet({super.key, required this.onTaskAdded});

  static Future<void> show(BuildContext context, {required VoidCallback onTaskAdded}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickAddSheet(onTaskAdded: onTaskAdded),
    );
  }

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();
  
  String? _selectedProjectId;
  List<String> _selectedLabelIds = [];
  int _selectedPriority = TaskPriority.medium;
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _scheduledTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));
  
  List<Category> _projects = [];
  List<Label> _labels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final projects = await categoryRepository.getAllCategories();
    final labels = await labelRepository.getAllLabels();
    setState(() {
      _projects = projects;
      _labels = labels;
      _selectedProjectId = projects.isNotEmpty ? projects.first.id : null;
      _isLoading = false;
    });
  }

  Future<void> _addTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    final scheduledTime = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    );

    final task = Task(
      id: const Uuid().v4(),
      title: title,
      scheduledTime: scheduledTime,
      speakText: title,
      categoryId: _selectedProjectId ?? defaultCategoryId,
      priority: _selectedPriority,
      labelIds: _selectedLabelIds,
    );

    await taskRepository.addTask(task);
    widget.onTaskAdded();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked != null) {
      setState(() => _scheduledTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title input
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'What needs to be done?',
                    hintStyle: TextStyle(color: theme.hintColor.withValues(alpha: 0.5)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: Icon(LucideIcons.plus, color: theme.colorScheme.primary),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTask(),
                ),
              ),

              const SizedBox(height: 16),

              // Quick select row
              if (!_isLoading) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Date chip
                      _buildSelectChip(
                        icon: LucideIcons.calendar,
                        label: _formatDate(_scheduledDate),
                        onTap: _pickDate,
                      ),
                      const SizedBox(width: 8),
                      
                      // Time chip
                      _buildSelectChip(
                        icon: LucideIcons.clock,
                        label: _scheduledTime.format(context),
                        onTap: _pickTime,
                      ),
                      const SizedBox(width: 8),

                      // Priority chip
                      _buildPriorityChip(),
                      const SizedBox(width: 8),

                      // Project chip
                      _buildProjectChip(),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Labels row
                if (_labels.isNotEmpty) ...[
                  Text('Labels', style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.hintColor,
                  )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _labels.map((label) {
                      final isSelected = _selectedLabelIds.contains(label.id);
                      return FilterChip(
                        label: Text(label.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedLabelIds.add(label.id);
                            } else {
                              _selectedLabelIds.remove(label.id);
                            }
                          });
                        },
                        avatar: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: label.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        selectedColor: label.color.withValues(alpha: 0.2),
                        checkmarkColor: label.color,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              // Add button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _addTask,
                  icon: const Icon(LucideIcons.plus, size: 20),
                  label: const Text('Add Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip() {
    final theme = Theme.of(context);
    final color = TaskPriority.getColor(_selectedPriority);
    
    return PopupMenuButton<int>(
      initialValue: _selectedPriority,
      onSelected: (priority) => setState(() => _selectedPriority = priority),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TaskPriority.getIcon(_selectedPriority), size: 16, color: color),
            const SizedBox(width: 6),
            Text(TaskPriority.getLabel(_selectedPriority), 
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
      itemBuilder: (context) => TaskPriority.values.map((p) => PopupMenuItem(
        value: p,
        child: Row(
          children: [
            Icon(TaskPriority.getIcon(p), size: 18, color: TaskPriority.getColor(p)),
            const SizedBox(width: 8),
            Text(TaskPriority.getLabel(p)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildProjectChip() {
    final theme = Theme.of(context);
    final selectedProject = _projects.firstWhere(
      (p) => p.id == _selectedProjectId,
      orElse: () => _projects.first,
    );
    
    return PopupMenuButton<String>(
      initialValue: _selectedProjectId,
      onSelected: (id) => setState(() => _selectedProjectId = id),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selectedProject.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: selectedProject.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(selectedProject.name, 
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selectedProject.color)),
          ],
        ),
      ),
      itemBuilder: (context) => _projects.map((p) => PopupMenuItem(
        value: p.id,
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: p.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(p.name),
          ],
        ),
      )).toList(),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'Today';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (date.day == tomorrow.day && date.month == tomorrow.month && date.year == tomorrow.year) {
      return 'Tomorrow';
    }
    return '${date.day}/${date.month}';
  }
}
