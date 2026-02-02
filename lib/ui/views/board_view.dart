import 'package:flutter/material.dart';
import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/task_model.dart';
import '../../models/category_model.dart';
import '../../repositories/task_repository.dart';



enum BoardGrouping { status, project }

class BoardView extends StatefulWidget {
  final List<Task> tasks;
  final List<Category> categories;
  final Function(Task) onTaskUpdated;

  const BoardView({
    super.key,
    required this.tasks,
    required this.categories,
    required this.onTaskUpdated,
  });

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  final TaskRepository _taskRepository = TaskRepository();
  BoardGrouping _grouping = BoardGrouping.status;

  // We rely on parent to pass updated data, but we might do optimistic updates locally if needed.
  // Actually, standard DragAndDropLists modifies the list in place usually?
  // We'll use widget.tasks directly or make a local copy?
  // Local sorting might be needed.

  Future<void> _onTaskMove(int oldItemIndex, int oldListIndex, int newItemIndex, int newListIndex) async {
    // Identify the task
    final task = _getTaskAt(oldListIndex, oldItemIndex);
    
    // Update propert based on new list
    if (_grouping == BoardGrouping.status) {
      // 0=Pending, 1=Done
      final newIsCompleted = newListIndex == 1;
      if (task.isCompleted != newIsCompleted) {
        task.isCompleted = newIsCompleted;
        await _taskRepository.updateTask(task);
        widget.onTaskUpdated(task);
      }
    } else {
      // Project
      if (newListIndex < widget.categories.length) {
        final newCatId = widget.categories[newListIndex].id;
        if (task.categoryId != newCatId) {
          task.categoryId = newCatId;
          await _taskRepository.updateTask(task);
          widget.onTaskUpdated(task);
        }
      }
    }
  }

  Task _getTaskAt(int listIndex, int itemIndex) {
    if (_grouping == BoardGrouping.status) {
      final pending = widget.tasks.where((t) => !t.isCompleted).toList();
      final done = widget.tasks.where((t) => t.isCompleted).toList();
      return listIndex == 0 ? pending[itemIndex] : done[itemIndex];
    } else {
      final categoryId = widget.categories[listIndex].id;
      final tasksInCat = widget.tasks.where((t) => t.categoryId == categoryId).toList();
      return tasksInCat[itemIndex];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Grouping Toggle
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SegmentedButton<BoardGrouping>(
            segments: const [
              ButtonSegment(
                value: BoardGrouping.status,
                label: Text('Status'),
                icon: Icon(LucideIcons.checkCircle),
              ),
              ButtonSegment(
                value: BoardGrouping.project,
                label: Text('Project'),
                icon: Icon(LucideIcons.folder),
              ),
            ],
            selected: {_grouping},
            onSelectionChanged: (Set<BoardGrouping> newSelection) {
              setState(() {
                _grouping = newSelection.first;
              });
            },
          ),
        ),

        // Kanban Board
        Expanded(
          child: DragAndDropLists(
            children: _buildLists(),
            onItemReorder: _onTaskMove,
            onListReorder: (_, __) {}, // Disable list reordering for now
            axis: Axis.horizontal,
            listWidth: 300,
            listDraggingWidth: 300,
            listPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            itemDivider: const SizedBox(height: 8),
            itemDecorationWhileDragging: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
          ),
        ),
      ],
    );
  }

  List<DragAndDropList> _buildLists() {
    if (_grouping == BoardGrouping.status) {
      return [
        _buildList(
          title: 'Pending',
          tasks: widget.tasks.where((t) => !t.isCompleted).toList(),
          color: Colors.orange,
        ),
        _buildList(
          title: 'Completed',
          tasks: widget.tasks.where((t) => t.isCompleted).toList(),
          color: Colors.green,
        ),
      ];
    } else {
      return widget.categories.map((cat) {
        return _buildList(
          title: cat.name,
          tasks: widget.tasks.where((t) => t.categoryId == cat.id).toList(),
          color: cat.color,
        );
      }).toList();
    }
  }

  DragAndDropList _buildList({
    required String title,
    required List<Task> tasks,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return DragAndDropList(
      header: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Row(
          children: [
            Container(width: 4, height: 16, color: color),
            const SizedBox(width: 8),
            Text(
              '$title (${tasks.length})',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
      children: tasks.map((task) {
        return DragAndDropItem(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
