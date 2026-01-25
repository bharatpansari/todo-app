import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/task_model.dart';
import '../../models/category_model.dart';
import '../../repositories/task_repository.dart';
import '../../repositories/category_repository.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AddEditTaskScreen extends StatefulWidget {
  final Task? task;

  const AddEditTaskScreen({super.key, this.task});

  @override
  State<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _speakController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  
  final CategoryRepository _categoryRepository = CategoryRepository();
  List<Category> _categories = [];
  String _selectedCategoryId = defaultCategoryId;
  bool _isLoadingCategories = true;
  
  // Repeat pattern state
  bool _isRepeatEnabled = false;
  String _repeatType = RepeatType.none;
  List<int> _customWeekdays = [];
  List<int> _preReminders = []; // List of minutes: 15, 30, 60
  
  // Priority state
  int _selectedPriority = TaskPriority.medium;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
    _speakController = TextEditingController(text: widget.task?.speakText ?? '');
    
    final scheduled = widget.task?.scheduledTime ?? DateTime.now().add(const Duration(minutes: 5));
    _selectedDate = scheduled;
    _selectedTime = TimeOfDay.fromDateTime(scheduled);
    _selectedCategoryId = widget.task?.categoryId ?? defaultCategoryId;
    _isRepeatEnabled = widget.task?.isRepeatEnabled ?? false;
    _repeatType = widget.task?.repeatType ?? RepeatType.none;
    _customWeekdays = List.from(widget.task?.customWeekdays ?? []);
    _preReminders = List.from(widget.task?.preReminders ?? []);
    _selectedPriority = widget.task?.priority ?? TaskPriority.medium;
    
    _loadCategories();
  }
  
  Future<void> _loadCategories() async {
    final categories = await _categoryRepository.getAllCategories();
    setState(() {
      _categories = categories;
      _isLoadingCategories = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _speakController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }
  
  void _saveTask() async {
     if (!_formKey.currentState!.validate()) return;
     
     final dt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
     );
     
     if (dt.isBefore(DateTime.now())) {
         ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Cannot schedule task in the past!"))
         );
         return;
     }

     // Preserve existing relationship data if editing
     final isEdit = widget.task != null;
     
     final newTask = Task(
         id: widget.task?.id,
         title: _titleController.text,
         description: _descriptionController.text,
         scheduledTime: dt,
         speakText: _speakController.text.isEmpty ? _titleController.text : _speakController.text,
         categoryId: _selectedCategoryId,
         isRepeatEnabled: _isRepeatEnabled,
         repeatType: _isRepeatEnabled ? _repeatType : RepeatType.none,
         customWeekdays: _repeatType == RepeatType.custom ? _customWeekdays : [],
         // If editing, preserve existing valid values unless logic suggests otherwise.
         // If creating new, calculate isRecurringSeries.
         isRecurringSeries: isEdit ? (widget.task!.isRecurringSeries) : (_isRepeatEnabled), 
         parentTaskId: isEdit ? widget.task!.parentTaskId : null,
         priority: _selectedPriority,
         preReminders: _preReminders,
     );

     final repo = TaskRepository();
     if (widget.task == null) {
         await repo.addTask(newTask);
     } else {
         await repo.updateTask(newTask);
     }
     
     if (mounted) Navigator.pop(context);
  }
  
  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    int selectedColorValue = Colors.teal.value;
    
    final colorOptions = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lime,
      Colors.amber,
      Colors.orange,
      Colors.brown,
    ];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add Custom Category"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Category Name",
                  hintText: "e.g., Urgent, Family",
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              const Text("Color", style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colorOptions.map((color) => GestureDetector(
                  onTap: () => setDialogState(() => selectedColorValue = color.value),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: selectedColorValue == color.value
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a category name")),
                  );
                  return;
                }
                
                final exists = await _categoryRepository.categoryNameExists(name);
                if (exists) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Category name already exists")),
                    );
                  }
                  return;
                }
                
                final newCategory = Category(
                  id: const Uuid().v4(),
                  name: name,
                  colorValue: selectedColorValue,
                );
                
                await _categoryRepository.addCategory(newCategory);
                await _loadCategories();
                
                if (mounted) {
                  setState(() {
                    _selectedCategoryId = newCategory.id;
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'New Task' : 'Edit Task'),
        leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'What needs to be done?',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _descriptionController,
                style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
                maxLines: 3,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Add details, notes, or subtasks...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                  contentPadding: EdgeInsets.zero,
                  prefixIcon: Icon(LucideIcons.alignLeft, size: 18, color: Colors.grey),
                  prefixIconConstraints: BoxConstraints(minWidth: 28),
                ),
              ),
              const SizedBox(height: 24),
              
              // Category Selector
              const Text("Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _isLoadingCategories
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategoryId,
                          isExpanded: true,
                          icon: const Icon(LucideIcons.chevronDown),
                          items: [
                            ..._categories.map((category) => DropdownMenuItem<String>(
                              value: category.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: category.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(category.name),
                                ],
                              ),
                            )),
                            DropdownMenuItem<String>(
                              value: '__add_new__',
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(LucideIcons.plus, size: 12),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text("Add Custom Category...", style: TextStyle(fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == '__add_new__') {
                              _showAddCategoryDialog();
                            } else if (value != null) {
                              setState(() => _selectedCategoryId = value);
                            }
                          },
                        ),
                      ),
                    ),
              
              const SizedBox(height: 24),
              
              // Priority Selector
              const Text("Priority", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: TaskPriority.values.map((priority) {
                    final isSelected = _selectedPriority == priority;
                    final color = TaskPriority.getColor(priority);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedPriority = priority),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: color, width: 2) : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                TaskPriority.getIcon(priority),
                                size: 18,
                                color: isSelected ? color : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                TaskPriority.getLabel(priority),
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? color : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Date & Time
              Row(
                children: [
                    Expanded(
                        child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Theme.of(context).dividerColor),
                                ),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        Row(children: [Icon(LucideIcons.calendar, size: 16, color: Theme.of(context).primaryColor), const SizedBox(width: 8), Text("Date", style: TextStyle(color: Colors.grey[600], fontSize: 12))]),
                                        const SizedBox(height: 8),
                                        Text(DateFormat.MMMEd().format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                    ],
                                ),
                            ),
                        ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                        child: InkWell(
                            onTap: _pickTime,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Theme.of(context).dividerColor),
                                ),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        Row(children: [Icon(LucideIcons.clock, size: 16, color: Theme.of(context).primaryColor), const SizedBox(width: 8), Text("Time", style: TextStyle(color: Colors.grey[600], fontSize: 12))]),
                                        const SizedBox(height: 8),
                                        Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                    ],
                                ),
                            ),
                        ),
                    ),
                ],
              ),
              
              const SizedBox(height: 24),

              // Pre-Reminders
              const Text("Early Reminders", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                   _preReminderChip(15, "15m before"),
                   _preReminderChip(30, "30m before"),
                   _preReminderChip(60, "1h before"),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Repeat Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.repeat, size: 20, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 12),
                        const Expanded(child: Text("Repeat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                        Switch(
                          value: _isRepeatEnabled,
                          onChanged: (val) => setState(() {
                            _isRepeatEnabled = val;
                            if (val && _repeatType == RepeatType.none) {
                              _repeatType = RepeatType.daily;
                            }
                          }),
                          activeColor: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                    if (_isRepeatEnabled) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _repeatType == RepeatType.none ? RepeatType.daily : _repeatType,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          RepeatType.daily,
                          RepeatType.weekly,
                          RepeatType.monthly,
                          RepeatType.custom,
                        ].map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(RepeatType.getLabel(type)),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _repeatType = val);
                        },
                      ),
                      if (_repeatType == RepeatType.custom) ...[
                        const SizedBox(height: 12),
                        const Text("Select days", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _weekdayChip(1, "Mon"),
                            _weekdayChip(2, "Tue"),
                            _weekdayChip(3, "Wed"),
                            _weekdayChip(4, "Thu"),
                            _weekdayChip(5, "Fri"),
                            _weekdayChip(6, "Sat"),
                            _weekdayChip(7, "Sun"),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Speak Text
              const Text("Spoken Reminder (TTS)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: TextField(
                    controller: _speakController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        hintText: "Enter the exact text to speak...",
                        border: InputBorder.none,
                    ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                  children: [
                      const Icon(LucideIcons.info, size: 14, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text("If empty, the title will be spoken.", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
              ),

              const SizedBox(height: 48),
              SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                      onPressed: _saveTask,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                      ),
                      child: const Text("Schedule Task", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weekdayChip(int day, String label) {
    final isSelected = _customWeekdays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _customWeekdays.add(day);
          } else {
            _customWeekdays.remove(day);
          }
        });
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _preReminderChip(int minutes, String label) {
    final isSelected = _preReminders.contains(minutes);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _preReminders.add(minutes);
          } else {
            _preReminders.remove(minutes);
          }
        });
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor, 
    );
  }
}
