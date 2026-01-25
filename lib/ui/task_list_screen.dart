import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../models/category_model.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/category_repository.dart';
import 'add_edit_task_screen.dart';
import 'stats_dashboard_screen.dart';
import 'widgets/task_tile.dart';
import 'tts_settings_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/native_bridge.dart';
import '../../services/export_import_service.dart';
import '../../repositories/settings_repository.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TaskRepository _repository = TaskRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  List<Task> _tasks = [];
  List<Category> _categories = [];
  Map<String, Category> _categoryMap = {};
  bool _isLoading = true;
  String? _selectedFilterCategoryId; // null means "All"
  bool _sortByPriorityFirst = false;
  bool _filterHighPriorityOnly = false;
  
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
    _loadData();
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
  
  void _toggleSortMode() {
    setState(() {
      _sortByPriorityFirst = !_sortByPriorityFirst;
      _sortTasks(_tasks);
    });
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
                      selectedColor: TaskPriority.getColor(p).withOpacity(0.2),
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
  
  Category? _getCategoryForTask(Task task) {
    return _categoryMap[task.categoryId];
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final settingsRepo = SettingsRepository();
        return AlertDialog(
          title: const Text("Settings"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Theme", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              ValueListenableBuilder(
                valueListenable: settingsRepo.themeModeListenable,
                builder: (context, box, _) {
                  final current = settingsRepo.getThemeMode();
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _themeOption(context, settingsRepo, current, ThemeMode.system, "System Default", LucideIcons.smartphone),
                        const Divider(height: 1),
                        _themeOption(context, settingsRepo, current, ThemeMode.light, "Light Mode", LucideIcons.sun),
                        const Divider(height: 1),
                        _themeOption(context, settingsRepo, current, ThemeMode.dark, "Dark Mode", LucideIcons.moon),
                      ],
                    ),
                  );
                }
              ),
              
              const SizedBox(height: 24),
              const Text("Permissions", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Allow Exact Alarms"),
                subtitle: const Text("Required for precise timing", style: TextStyle(fontSize: 12)),
                trailing: const Icon(LucideIcons.arrowRight, size: 16),
                onTap: () {
                  NativeBridge().requestExactAlarmPermission();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Ignore Battery Optimizations"),
                subtitle: const Text("Prevents delayed alarms", style: TextStyle(fontSize: 12)),
                trailing: const Icon(LucideIcons.arrowRight, size: 16),
                onTap: () {
                  NativeBridge().requestBatteryOptimizationIgnore();
                },
              ),
              
              const SizedBox(height: 24),
              const Text("Voice", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(LucideIcons.volume2, color: Theme.of(context).primaryColor),
                title: const Text("TTS Settings"),
                subtitle: const Text("Language, speed, pitch", style: TextStyle(fontSize: 12)),
                trailing: const Icon(LucideIcons.arrowRight, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TtsSettingsScreen()),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              const Text("Data", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(LucideIcons.upload, color: Theme.of(context).primaryColor),
                title: const Text("Export Tasks"),
                subtitle: const Text("Save to JSON or CSV", style: TextStyle(fontSize: 12)),
                trailing: const Icon(LucideIcons.arrowRight, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _showExportDialog();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(LucideIcons.download, color: Theme.of(context).primaryColor),
                title: const Text("Import Tasks"),
                subtitle: const Text("Restore from JSON file", style: TextStyle(fontSize: 12)),
                trailing: const Icon(LucideIcons.arrowRight, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  _showImportDialog();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        );
      }
    );
  }

  Widget _themeOption(BuildContext context, SettingsRepository repo, ThemeMode current, ThemeMode mode, String label, IconData icon) {
    final isSelected = current == mode;
    return InkWell(
      onTap: () => repo.setThemeMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).iconTheme.color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
            if (isSelected)
              Icon(LucideIcons.check, size: 18, color: Theme.of(context).primaryColor),
          ],
        ),
      ),
    );
  }

  void _showExportDialog() {
    final exportService = ExportImportService();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Export Tasks"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.fileJson),
              title: const Text("Export as JSON"),
              subtitle: const Text("Full data, can be re-imported"),
              onTap: () async {
                Navigator.pop(context);
                _showLoadingDialog("Exporting...");
                try {
                  await exportService.shareExport(format: 'json');
                } finally {
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.fileSpreadsheet),
              title: const Text("Export as CSV"),
              subtitle: const Text("For spreadsheets"),
              onTap: () async {
                Navigator.pop(context);
                _showLoadingDialog("Exporting...");
                try {
                  await exportService.shareExport(format: 'csv');
                } finally {
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Import Tasks"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Choose how to handle imported tasks:"),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(LucideIcons.merge),
              title: const Text("Merge"),
              subtitle: const Text("Keep existing, add new tasks"),
              onTap: () {
                Navigator.pop(context);
                _performImport(merge: true);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.replace),
              title: const Text("Replace All"),
              subtitle: const Text("Delete existing, import fresh"),
              onTap: () {
                Navigator.pop(context);
                _confirmReplaceImport();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  void _confirmReplaceImport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⚠️ Replace All Tasks?"),
        content: const Text(
          "This will DELETE all existing tasks and replace them with the imported data. This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _performImport(merge: false);
            },
            child: const Text("Replace All"),
          ),
        ],
      ),
    );
  }

  Future<void> _performImport({required bool merge}) async {
    final exportService = ExportImportService();
    
    _showLoadingDialog("Selecting file...");
    
    try {
      final jsonContent = await exportService.pickImportFile();
      if (mounted) Navigator.pop(context); // Close loading
      
      if (jsonContent == null) {
        _showSnackBar("Import cancelled");
        return;
      }
      
      _showLoadingDialog("Importing...");
      final result = await exportService.importFromJson(jsonContent, merge: merge);
      if (mounted) Navigator.pop(context); // Close loading
      
      _showSnackBar(
        "Imported ${result.imported} tasks" +
        (result.skipped > 0 ? ", skipped ${result.skipped} duplicates" : "") +
        (result.errors > 0 ? ", ${result.errors} errors" : ""),
      );
      
      _loadData(); // Refresh task list
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar("Import failed: $e");
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _filteredTasks;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Daily Tasks'),
        actions: [
          // Stats dashboard
          IconButton(
            icon: const Icon(LucideIcons.barChart3),
            tooltip: 'Statistics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatsDashboardScreen()),
              );
            },
          ),
          // Sort toggle
          PopupMenuButton<int>(
            icon: const Icon(LucideIcons.arrowUpDown),
            tooltip: 'Sort by',
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (context) => [
              PopupMenuItem(value: 0, child: Row(children: [Icon(_sortMode == 0 ? LucideIcons.check : null, size: 16), const SizedBox(width: 8), const Text('Time')])),
              PopupMenuItem(value: 1, child: Row(children: [Icon(_sortMode == 1 ? LucideIcons.check : null, size: 16), const SizedBox(width: 8), const Text('Priority')])),
              PopupMenuItem(value: 2, child: Row(children: [Icon(_sortMode == 2 ? LucideIcons.check : null, size: 16), const SizedBox(width: 8), const Text('Title')])),
            ],
          ),
          // Filter button
          IconButton(
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              child: const Icon(LucideIcons.filter),
            ),
            tooltip: 'Filters',
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: () {
               _showSettingsDialog();
            },
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      prefixIcon: const Icon(LucideIcons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                // Category filter chips
                if (_categories.isNotEmpty)
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // "All" chip
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('All'),
                            selected: _selectedFilterCategoryId == null && !_filterHighPriorityOnly,
                            onSelected: (_) {
                              setState(() {
                                _selectedFilterCategoryId = null;
                                _filterHighPriorityOnly = false;
                              });
                            },
                            selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                            checkmarkColor: Theme.of(context).primaryColor,
                          ),
                        ),
                        // High Priority filter chip
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: Icon(
                              LucideIcons.alertTriangle,
                              size: 14,
                              color: _filterHighPriorityOnly 
                                  ? TaskPriority.getColor(TaskPriority.high)
                                  : Colors.grey,
                            ),
                            label: const Text('High Priority'),
                            selected: _filterHighPriorityOnly,
                            onSelected: (_) {
                              setState(() {
                                _filterHighPriorityOnly = !_filterHighPriorityOnly;
                                if (_filterHighPriorityOnly) {
                                  _selectedFilterCategoryId = null;
                                }
                              });
                            },
                            selectedColor: TaskPriority.getColor(TaskPriority.high).withOpacity(0.2),
                            checkmarkColor: TaskPriority.getColor(TaskPriority.high),
                          ),
                        ),
                        // Category chips
                        ..._categories.map((category) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: category.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            label: Text(category.name),
                            selected: _selectedFilterCategoryId == category.id,
                            onSelected: (_) {
                              setState(() => _selectedFilterCategoryId = 
                                  _selectedFilterCategoryId == category.id ? null : category.id);
                            },
                            selectedColor: category.color.withOpacity(0.2),
                            checkmarkColor: category.color,
                          ),
                        )),
                      ],
                    ),
                  ),
                
                // Task list
                Expanded(
                  child: filteredTasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.clipboardList, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFilterCategoryId != null 
                                  ? "No tasks in this category!"
                                  : "No tasks yet!", 
                              style: TextStyle(color: Colors.grey[500], fontSize: 18)
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredTasks.length,
                        itemBuilder: (context, index) {
                          final task = filteredTasks[index];
                          final category = _getCategoryForTask(task);
                          
                          return TaskTile(
                            key: Key(task.id),
                            task: task,
                            category: category,
                            onDelete: () => _deleteTask(task),
                            onRefresh: _loadData,
                          );
                        },
                      ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditTaskScreen(),
            ),
          );
          _loadData();
        },
        backgroundColor: Colors.black,
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text("New Task", style: TextStyle(color: Colors.white)),
      ),
    );
  }


}

