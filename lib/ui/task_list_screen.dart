import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../models/category_model.dart';

import '../../repositories/task_repository.dart';
import '../../repositories/category_repository.dart';

import 'add_edit_task_screen.dart';
import 'stats_dashboard_screen.dart';
import 'widgets/task_tile.dart';

import 'settings_screen.dart';

import 'login_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';


import '../../services/auth_service.dart';

import '../../services/voice_service.dart';
import '../../repositories/template_repository.dart';
import '../../services/pro_service.dart';
import 'paywall_screen.dart';

import 'views/board_view.dart';
import 'views/calendar_view.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TaskRepository _repository = TaskRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final TemplateRepository _templateRepository = TemplateRepository();
  final VoiceService _voiceService = VoiceService();
  final ProService _proService = ProService();

  List<Task> _tasks = [];
  List<Category> _categories = [];
  Map<String, Category> _categoryMap = {};
  bool _isLoading = true;
  String? _selectedFilterCategoryId; // null means "All"
  bool _sortByPriorityFirst = false;
  bool _filterHighPriorityOnly = false;
  
  // Navigation state
  int _currentIndex = 0; // 0=List, 1=Board, 2=Calendar
  
  // Search & Advanced Filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _filterDateStart;
  DateTime? _filterDateEnd;
  Set<int> _filterPriorities = {}; // empty = all
  int _filterStatus = 0; // 0=all, 1=pending, 2=completed
  bool? _filterHasSpeakText; // null=all, true=has, false=none
  int _sortMode = 0; // 0=time, 1=priority, 2=title
  
  @override
  void initState() {
    super.initState();
    _proService.addListener(_onProStatusChanged);
    _loadData();
  }
  
  @override
  void dispose() {
    _proService.removeListener(_onProStatusChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onProStatusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    final tasks = await _repository.getAllTasks();
    final categories = await _categoryRepository.getAllCategories();
    
    // Sort based on current preference
    _sortTasks(tasks);
    
    // Build category map for quick lookup
    final categoryMap = <String, Category>{};
    for (final category in categories) {
      categoryMap[category.id] = category;
    }
    
    setState(() {
      _tasks = tasks;
      _categories = categories;
      _categoryMap = categoryMap;
      _isLoading = false;
    });
  }

  Future<void> _deleteTask(Task task) async {
    await _repository.deleteTask(task);
    _loadData();
  }

  Future<void> _toggleTaskCompletion(Task task, bool isCompleted) async {
    task.isCompleted = isCompleted;
    await _repository.updateTask(task);
    _loadData();
  }
  
  void _sortTasks(List<Task> tasks) {
    if (_sortByPriorityFirst) {
      // Sort by priority (high first), then by time
      tasks.sort((a, b) {
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return a.scheduledTime.compareTo(b.scheduledTime);
      });
    } else {
      // Sort by time only
      tasks.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    }
  }
  
  List<Task> get _filteredTasks {
    var tasks = _tasks.toList();
    
    // 1. Search filter (title + description)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      tasks = tasks.where((t) => 
        t.title.toLowerCase().contains(query) ||
        t.description.toLowerCase().contains(query)
      ).toList();
    }
    
    // 2. Date range filter
    if (_filterDateStart != null) {
      tasks = tasks.where((t) => !t.scheduledTime.isBefore(_filterDateStart!)).toList();
    }
    if (_filterDateEnd != null) {
      final endOfDay = DateTime(_filterDateEnd!.year, _filterDateEnd!.month, _filterDateEnd!.day, 23, 59, 59);
      tasks = tasks.where((t) => !t.scheduledTime.isAfter(endOfDay)).toList();
    }
    
    // 3. Category filter
    if (_selectedFilterCategoryId != null) {
      tasks = tasks.where((t) => t.categoryId == _selectedFilterCategoryId).toList();
    }
    
    // 4. Priority filter
    if (_filterPriorities.isNotEmpty) {
      tasks = tasks.where((t) => _filterPriorities.contains(t.priority)).toList();
    } else if (_filterHighPriorityOnly) {
      tasks = tasks.where((t) => t.priority == TaskPriority.high).toList();
    }
    
    // 5. Status filter
    if (_filterStatus == 1) {
      tasks = tasks.where((t) => !t.isCompleted).toList();
    } else if (_filterStatus == 2) {
      tasks = tasks.where((t) => t.isCompleted).toList();
    }
    
    // 6. Has speak text filter
    if (_filterHasSpeakText == true) {
      tasks = tasks.where((t) => t.speakText.isNotEmpty && t.speakText != t.title).toList();
    } else if (_filterHasSpeakText == false) {
      tasks = tasks.where((t) => t.speakText.isEmpty || t.speakText == t.title).toList();
    }
    
    // Apply sorting
    _applySorting(tasks);
    
    return tasks;
  }
  
  void _applySorting(List<Task> tasks) {
    switch (_sortMode) {
      case 1: // Priority
        tasks.sort((a, b) {
          final p = b.priority.compareTo(a.priority);
          if (p != 0) return p;
          return a.scheduledTime.compareTo(b.scheduledTime);
        });
        break;
      case 2: // Title
        tasks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      default: // Time
        tasks.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    }
  }
  
  bool get _hasActiveFilters =>
      _filterDateStart != null ||
      _filterDateEnd != null ||
      _filterPriorities.isNotEmpty ||
      _filterStatus != 0 ||
      _filterHasSpeakText != null ||
      _selectedFilterCategoryId != null;

  void _clearAllFilters() {
    setState(() {
      _filterDateStart = null;
      _filterDateEnd = null;
      _filterPriorities = {};
      _filterStatus = 0;
      _filterHasSpeakText = null;
      _selectedFilterCategoryId = null;
      _filterHighPriorityOnly = false;
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        _clearAllFilters();
                        setSheetState(() {});
                      },
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Range
                const Text('Date Range', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(LucideIcons.calendar, size: 16),
                        label: Text(_filterDateStart != null
                            ? DateFormat.MMMd().format(_filterDateStart!)
                            : 'Start'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _filterDateStart ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _filterDateStart = picked);
                            setSheetState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('to'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(LucideIcons.calendar, size: 16),
                        label: Text(_filterDateEnd != null
                            ? DateFormat.MMMd().format(_filterDateEnd!)
                            : 'End'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _filterDateEnd ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _filterDateEnd = picked);
                            setSheetState(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Priority
                const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: TaskPriority.values.map((p) {
                    final selected = _filterPriorities.contains(p);
                    return FilterChip(
                      label: Text(TaskPriority.getLabel(p)),
                      selected: selected,
                      selectedColor: TaskPriority.getColor(p).withValues(alpha: 0.2),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _filterPriorities.add(p);
                          } else {
                            _filterPriorities.remove(p);
                          }
                        });
                        setSheetState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Status
                const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(label: const Text('All'), selected: _filterStatus == 0, onSelected: (_) { setState(() => _filterStatus = 0); setSheetState(() {}); }),
                    ChoiceChip(label: const Text('Pending'), selected: _filterStatus == 1, onSelected: (_) { setState(() => _filterStatus = 1); setSheetState(() {}); }),
                    ChoiceChip(label: const Text('Completed'), selected: _filterStatus == 2, onSelected: (_) { setState(() => _filterStatus = 2); setSheetState(() {}); }),
                  ],
                ),
                const SizedBox(height: 20),

                // Has Speak Text
                const Text('Speak Text', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(label: const Text('Any'), selected: _filterHasSpeakText == null, onSelected: (_) { setState(() => _filterHasSpeakText = null); setSheetState(() {}); }),
                    ChoiceChip(label: const Text('Has Custom'), selected: _filterHasSpeakText == true, onSelected: (_) { setState(() => _filterHasSpeakText = true); setSheetState(() {}); }),
                    ChoiceChip(label: const Text('Default Only'), selected: _filterHasSpeakText == false, onSelected: (_) { setState(() => _filterHasSpeakText = false); setSheetState(() {}); }),
                  ],
                ),
                const SizedBox(height: 30),

                // Apply button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  










  void _showMyAccountSheet() {
    final user = AuthService().currentUser;
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // User profile section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Profile photo
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Icon(LucideIcons.user, size: 32, color: theme.colorScheme.primary)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  
                  // User details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Divider(height: 1),
            
            // Settings option
            ListTile(
              leading: Icon(LucideIcons.settings, color: theme.colorScheme.primary),
              title: const Text('Settings'),
              subtitle: const Text('TTS, Export/Import'),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            
            // Logout option
            ListTile(
              leading: Icon(LucideIcons.logOut, color: theme.colorScheme.error),
              title: Text('Logout', style: TextStyle(color: theme.colorScheme.error)),
              subtitle: const Text('Sign out from your account'),
              onTap: () async {
                Navigator.pop(context);
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                }
              },
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _startVoiceEntry() async {
    if (!_proService.canUseVoice) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
      }
      return;
    }

    // 1. Check permissions and init
    final isAvailable = await _voiceService.init();
    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied or speech recognition unavailable')),
        );
      }
      return;
    }

    String heardText = "";
    
    // 2. Show Dialog
    if (!mounted) return;
    
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Start listening once dialog is built if not already listening
            if (!_voiceService.isListening && heardText.isEmpty) {
               _voiceService.startListening(
                 onResult: (text) {
                   setState(() => heardText = text);
                 },
                 onSoundLevel: (level) {},
               );
            }
            
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(LucideIcons.mic, size: 48, color: Theme.of(context).primaryColor),
                   const SizedBox(height: 16),
                   const Text("Listening...", style: TextStyle(fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   Text(
                     heardText.isEmpty ? "Say something..." : heardText,
                     textAlign: TextAlign.center,
                     style: TextStyle(color: Theme.of(context).primaryColor),
                   ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _voiceService.stop();
                    Navigator.pop(context);
                  },
                  child: const Text("Done"),
                ),
              ],
            );
          },
        );
      },
    );
    
    await _voiceService.stop();

    // 3. Navigate to Add Task with text
    if (heardText.isNotEmpty && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddEditTaskScreen(initialTitle: heardText),
        ),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'My Daily Tasks' : (_currentIndex == 1 ? 'Board' : 'Calendar')),
        titleSpacing: 16,
        actions: _buildAppBarActions(),
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if ((index == 1 || index == 2) && !_proService.isPro) {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
             return;
          }
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
             icon: Icon(LucideIcons.list),
             label: 'List',
          ),
          NavigationDestination(
             icon: Icon(LucideIcons.trello),
             label: 'Board',
          ),
          NavigationDestination(
             icon: Icon(LucideIcons.calendar),
             label: 'Calendar',
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Voice Button
          if (_currentIndex == 0) // Only on list view
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FloatingActionButton.small(
                heroTag: "voice_fab",
                onPressed: _startVoiceEntry,
                backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
                child: const Icon(LucideIcons.mic),
              ),
            ),
            
          // Add Button
          FloatingActionButton.extended(
            heroTag: "add_fab",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddEditTaskScreen(),
                ),
              );
              _loadData();
            },
            elevation: 6,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            icon: const Icon(LucideIcons.plus, size: 22),
            label: const Text("New Task", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_currentIndex != 0) {
       return [
          IconButton(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: AuthService().currentUser?.photoURL != null
                  ? NetworkImage(AuthService().currentUser!.photoURL!)
                  : null,
              child: AuthService().currentUser?.photoURL == null
                  ? Icon(LucideIcons.user, size: 16, color: Theme.of(context).colorScheme.primary)
                  : null,
            ),
            tooltip: 'My Account',
            onPressed: _showMyAccountSheet,
          ),
       ];
    }
    
    return [
          IconButton(
            icon: const Icon(LucideIcons.barChart3, size: 22),
            tooltip: 'Statistics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatsDashboardScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
          PopupMenuButton<int>(
            icon: const Icon(LucideIcons.arrowUpDown, size: 22),
            tooltip: 'Sort by',
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (context) => [
              PopupMenuItem(value: 0, child: Row(children: [const Icon(LucideIcons.clock, size: 16), const SizedBox(width: 8), const Text('Time')])),
              PopupMenuItem(value: 1, child: Row(children: [const Icon(LucideIcons.alertTriangle, size: 16), const SizedBox(width: 8), const Text('Priority')])),
              PopupMenuItem(value: 2, child: Row(children: [const Icon(LucideIcons.type, size: 16), const SizedBox(width: 8), const Text('Title')])),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              child: const Icon(LucideIcons.filter, size: 22),
            ),
            tooltip: 'Filters',
            onPressed: _showFilterSheet,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(LucideIcons.copy, size: 22),
            tooltip: 'Templates',
            onPressed: _showTemplateSheet,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: AuthService().currentUser?.photoURL != null
                  ? NetworkImage(AuthService().currentUser!.photoURL!)
                  : null,
              child: AuthService().currentUser?.photoURL == null
                  ? Icon(LucideIcons.user, size: 16, color: Theme.of(context).colorScheme.primary)
                  : null,
            ),
            tooltip: 'My Account',
            onPressed: _showMyAccountSheet,
          ),
    ];
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    switch (_currentIndex) {
      case 1:
        return BoardView(
           tasks: _tasks, 
           categories: _categories,
           onTaskUpdated: (t) => _loadData(),
        );
      case 2:
        return CalendarView(
           tasks: _tasks,
           onTaskUpdated: (t) => _loadData(),
           onTaskDeleted: (t) => _loadData(),
        );
      case 0:
      default:
        return _buildListView();
    }
  }

  Widget _buildListView() {
    final filteredTasks = _filteredTasks;
    
    return Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        hintStyle: TextStyle(color: Theme.of(context).hintColor.withValues(alpha: 0.6)),
                        prefixIcon: Icon(LucideIcons.search, size: 20, color: Theme.of(context).hintColor),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(LucideIcons.x, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                ),
                // Category filter chips
                if (_categories.isNotEmpty)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // "All" chip
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: const Text('All', style: TextStyle(fontSize: 13)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            selected: _selectedFilterCategoryId == null && !_filterHighPriorityOnly,
                            onSelected: (_) {
                              setState(() {
                                _selectedFilterCategoryId = null;
                                _filterHighPriorityOnly = false;
                              });
                            },
                            selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                            checkmarkColor: Theme.of(context).primaryColor,
                          ),
                        ),
                        // High Priority filter chip
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: Icon(
                              LucideIcons.alertTriangle,
                              size: 14,
                              color: _filterHighPriorityOnly 
                                  ? TaskPriority.getColor(TaskPriority.high)
                                  : Colors.grey,
                            ),
                            label: const Text('High Priority', style: TextStyle(fontSize: 13)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            selected: _filterHighPriorityOnly,
                            onSelected: (_) {
                              setState(() {
                                _filterHighPriorityOnly = !_filterHighPriorityOnly;
                                if (_filterHighPriorityOnly) {
                                  _selectedFilterCategoryId = null;
                                }
                              });
                            },
                            selectedColor: TaskPriority.getColor(TaskPriority.high).withValues(alpha: 0.2),
                            checkmarkColor: TaskPriority.getColor(TaskPriority.high),
                          ),
                        ),
                        // Category chips
                        ..._categories.map((category) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: category.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            label: Text(category.name, style: const TextStyle(fontSize: 13)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            selected: _selectedFilterCategoryId == category.id,
                            onSelected: (_) {
                              setState(() => _selectedFilterCategoryId = 
                                  _selectedFilterCategoryId == category.id ? null : category.id);
                            },
                            selectedColor: category.color.withValues(alpha: 0.2),
                            checkmarkColor: category.color,
                          ),
                        )),
                      ],
                    ),
                  ),
                
                // Task list
                Expanded(
                  child: filteredTasks.isEmpty
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.clipboardList, 
                                  size: 48, 
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _selectedFilterCategoryId != null 
                                    ? "No tasks in this category"
                                    : "No tasks yet", 
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6), 
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Tap + to add your first task",
                                style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];
                          // Simple safe lookup using cache map
                          final category = _categoryMap[task.categoryId];
                          
                          return TaskTile(
                            key: Key(task.id),
                            task: task,
                            category: category,
                            onDelete: () => _deleteTask(task),
                            onRefresh: _loadData,
                            onToggleComplete: (isCompleted) => _toggleTaskCompletion(task, isCompleted),
                          );
                        },
                      ),
                ),
              ],
            );
  }


  void _showTemplateSheet() async {
    if (!_proService.canUseTemplates) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
      }
      return;
    }

    final templates = await _templateRepository.getTemplates();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
           builder: (context, setSheetState) {
             return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text("Templates", style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                
                // Save Button
                ListTile(
                  leading: const Icon(LucideIcons.save),
                  title: const Text("Save Current View as Template"),
                  subtitle: Text("${_filteredTasks.length} tasks visible"),
                  onTap: () {
                    Navigator.pop(context);
                    _showSaveTemplateDialog();
                  },
                  tileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                const SizedBox(height: 24),
                
                const Text("Saved Templates", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                if (templates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "No templates saved yet.",
                      style: TextStyle(color: Theme.of(context).hintColor),
                      textAlign: TextAlign.center,
                    ),
                  ),

                ...templates.map((t) => Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text("${t.tasks.length} tasks"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.playCircle, size: 20),
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () {
                            Navigator.pop(context);
                            _showApplyTemplateDialog(t);
                          },
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.trash2, size: 18),
                          onPressed: () async {
                            await _templateRepository.deleteTemplate(t.id);
                            final newTemplates = await _templateRepository.getTemplates();
                            setSheetState(() {
                               templates.clear();
                               templates.addAll(newTemplates);
                            });
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showApplyTemplateDialog(t);
                    },
                  ),
                )),
              ],
            );
          }
        ),
      ),
    );
  }

  void _showSaveTemplateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save Template"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Template Name",
            hintText: "e.g., Packing List",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                 await _templateRepository.saveTemplateFromTasks(controller.text, _filteredTasks);
                 Navigator.pop(context);
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Template saved")),
                   );
                 }
              }
            }, 
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showApplyTemplateDialog(TaskTemplate template) {
    DateTime startDate = DateTime.now();
    String? selectedCategoryId = _selectedFilterCategoryId ?? defaultCategoryId;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
           // ignore: unused_local_variable
           final categoryName = _categoryMap[selectedCategoryId]?.name ?? "Inbox";
           return AlertDialog(
            title: Text("Apply '${template.name}'"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Start Date"),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)), 
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      initialDate: startDate,
                    );
                    if (date != null) setDialogState(() => startDate = date);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat.MMMMEEEEd().format(startDate)),
                        const Icon(LucideIcons.calendar, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Target Category"),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategoryId,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: _categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              FilledButton(
                onPressed: () async {
                   Navigator.pop(context);
                   if (selectedCategoryId != null) {
                     await _templateRepository.applyTemplate(template, startDate, selectedCategoryId!);
                     _loadData();
                     if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text("Template applied successfully")),
                       );
                     }
                   }
                }, 
                child: const Text("Apply"),
              ),
            ],
          );
        }
      ),
    );
  }
}

