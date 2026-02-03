import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/task_model.dart';
import '../../models/category_model.dart';
import '../add_edit_task_screen.dart';

class TaskTile extends StatefulWidget {
  final Task task;
  final Category? category;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;
  final void Function(bool isCompleted)? onToggleComplete;

  const TaskTile({
    super.key,
    required this.task,
    this.category,
    required this.onDelete,
    required this.onRefresh,
    this.onToggleComplete,
  });

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _onTapDown(TapDownDetails details) {
    _animController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animController.reverse();
  }

  void _onTapCancel() {
    _animController.reverse();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'Today, ${DateFormat.jm().format(date)}';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (date.day == tomorrow.day && date.month == tomorrow.month && date.year == tomorrow.year) {
      return 'Tomorrow, ${DateFormat.jm().format(date)}';
    }
    return DateFormat('MMM d, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isPast = task.scheduledTime.isBefore(DateTime.now()) && !task.isCompleted;
    final category = widget.category;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade300.withValues(alpha: 0.3),
              Colors.red.shade400.withValues(alpha: 0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.red, size: 28),
      ),
      onDismissed: (_) => widget.onDelete(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: task.isCompleted
                  ? (isDark ? const Color(0xFF252538) : const Color(0xFFF5F5F8))
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: isPast
                  ? Border.all(color: Colors.orange.withValues(alpha: 0.4), width: 1.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.black).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: 0,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main Tap Area
                InkWell(
                  onTap: _toggleExpanded,
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(16),
                    bottom: Radius.circular(_isExpanded ? 0 : 16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Larger Checkbox Tap Target
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: Transform.scale(
                            scale: 1.1,
                            child: Checkbox(
                              value: task.isCompleted,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              activeColor: theme.colorScheme.primary,
                              onChanged: widget.onToggleComplete != null
                                  ? (value) => widget.onToggleComplete!(value ?? false)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Main Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title & Priority Row
                              Row(
                                children: [
                                  _buildPriorityBadge(context, task.priority),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                        color: task.isCompleted
                                            ? theme.disabledColor
                                            : (isPast ? Colors.orange.shade700 : theme.textTheme.bodyLarge?.color),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  if (category != null) ...[
                                    const SizedBox(width: 8),
                                    _buildCategoryBadge(context, category),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Description Snippet
                              if (!_isExpanded && task.description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    task.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),

                              // Date & Metadata Row
                              Row(
                                children: [
                                  Icon(
                                    LucideIcons.clock,
                                    size: 14,
                                    color: isPast ? Colors.orange : theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDate(task.scheduledTime),
                                    style: TextStyle(
                                      color: isPast ? Colors.orange : theme.colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (task.isRecurring) ...[
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.repeat, size: 11, color: theme.colorScheme.tertiary),
                                          const SizedBox(width: 4),
                                          Text(
                                            RepeatType.getLabel(task.repeatType),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: theme.colorScheme.tertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              // Speak Text Preview
                              if (task.speakText.isNotEmpty && !_isExpanded)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(LucideIcons.volume2, size: 13, color: theme.disabledColor),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '"${task.speakText}"',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.disabledColor,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Expand Indicator
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 200),
                          turns: _isExpanded ? 0.5 : 0,
                          child: Icon(
                            LucideIcons.chevronDown,
                            size: 20,
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Expanded Content with Animation
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(76, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: theme.dividerColor.withValues(alpha: 0.3), height: 1),
                        const SizedBox(height: 16),
                        
                        if (task.description.isNotEmpty) ...[
                          Text(
                            "Notes",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            task.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.textTheme.bodyMedium?.color,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (task.speakText.isNotEmpty) ...[
                          Text(
                            "Spoken Reminder",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.volume2, size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '"${task.speakText}"',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Action Button
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddEditTaskScreen(task: task),
                                ),
                              );
                              widget.onRefresh();
                            },
                            icon: const Icon(LucideIcons.edit2, size: 16),
                            label: const Text("Edit"),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(BuildContext context, int priority) {
    final color = TaskPriority.getColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            TaskPriority.getIcon(priority),
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            TaskPriority.getLabel(priority)[0],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(BuildContext context, Category category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: category.color,
            ),
          ),
        ],
      ),
    );
  }
}
