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

  const TaskTile({
    super.key,
    required this.task,
    this.category,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
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
    final task = widget.task;
    final isPast = task.scheduledTime.isBefore(DateTime.now());
    final category = widget.category;

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
      onDismissed: (_) => widget.onDelete(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _toggleExpanded,
              borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(20),
                  bottom: Radius.circular(_isExpanded ? 0 : 20)
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon / Status
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isPast ? Theme.of(context).disabledColor.withOpacity(0.1) : Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPast ? LucideIcons.checkCircle : LucideIcons.clock,
                        color: isPast ? Theme.of(context).disabledColor : Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Main Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title & Priority
                          Row(
                            children: [
                              _buildPriorityBadge(context, task.priority),
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    decoration: isPast ? TextDecoration.lineThrough : null,
                                    color: isPast ? Theme.of(context).disabledColor : Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                              if (category != null) _buildCategoryBadge(context, category),
                            ],
                          ),
                          const SizedBox(height: 4),
                          
                          // Description Snippet (Collapsed only)
                          if (!_isExpanded && task.description.isNotEmpty)
                             Padding(
                               padding: const EdgeInsets.only(bottom: 6),
                               child: Text(
                                 task.description,
                                 maxLines: 1,
                                 overflow: TextOverflow.ellipsis,
                                 style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7), fontSize: 13),
                               ),
                             ),

                          // Date & Metadata
                          Row(
                            children: [
                              Text(
                                _formatDate(task.scheduledTime),
                                style: TextStyle(
                                  color: isPast ? Theme.of(context).disabledColor : Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (task.isRecurring)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Row(
                                    children: [
                                      Icon(LucideIcons.repeat, size: 12, color: Theme.of(context).disabledColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        RepeatType.getLabel(task.repeatType),
                                        style: TextStyle(fontSize: 11, color: Theme.of(context).disabledColor),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          
                          if (task.speakText.isNotEmpty && !_isExpanded)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.volume2, size: 14, color: Theme.of(context).disabledColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '"${task.speakText}"',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Expand arrow (optional, to hint behavior)
                    Icon(
                         _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, 
                         size: 16, 
                         color: Theme.of(context).disabledColor
                    ),
                  ],
                ),
              ),
            ),
            
            // Expanded Content
            if (_isExpanded)
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.only(left: 84, right: 20, bottom: 20),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      if (task.description.isNotEmpty) ...[
                          Text(
                            "Notes:", 
                            style: TextStyle(
                                fontSize: 12, 
                                fontWeight: FontWeight.bold, 
                                color: Theme.of(context).textTheme.bodySmall?.color
                            )
                          ),
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            style: TextStyle(
                                fontSize: 14, 
                                color: Theme.of(context).textTheme.bodyMedium?.color
                            )
                          ),
                          const SizedBox(height: 12),
                      ],
                      
                      if (task.speakText.isNotEmpty) ...[
                          Text(
                            "Spoken Reminder:", 
                            style: TextStyle(
                                fontSize: 12, 
                                fontWeight: FontWeight.bold, 
                                color: Theme.of(context).textTheme.bodySmall?.color
                            )
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(LucideIcons.volume2, size: 16, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '"${task.speakText}"',
                                  style: TextStyle(
                                      fontSize: 14, 
                                      fontStyle: FontStyle.italic,
                                      color: Theme.of(context).textTheme.bodyMedium?.color
                                  )
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                      ],
                      
                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                            OutlinedButton.icon(
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
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(context).primaryColor,
                                    side: BorderSide(color: Theme.of(context).primaryColor),
                                ),
                            ),
                        ],
                      )
                   ],
                 ),
               ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(BuildContext context, int priority) {
    // Similar to original code
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: TaskPriority.getColor(priority).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            TaskPriority.getIcon(priority),
            size: 12,
            color: TaskPriority.getColor(priority),
          ),
          const SizedBox(width: 3),
          Text(
            TaskPriority.getLabel(priority)[0], // First letter only
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: TaskPriority.getColor(priority),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(BuildContext context, Category category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: category.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
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
              fontWeight: FontWeight.w500,
              color: category.color,
            ),
          ),
        ],
      ),
    );
  }
}
