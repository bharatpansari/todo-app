import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../repositories/task_repository.dart';
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
  late TextEditingController _speakController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _speakController = TextEditingController(text: widget.task?.speakText ?? '');
    
    final scheduled = widget.task?.scheduledTime ?? DateTime.now().add(const Duration(minutes: 5));
    _selectedDate = scheduled;
    _selectedTime = TimeOfDay.fromDateTime(scheduled);
  }

  @override
  void dispose() {
    _titleController.dispose();
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

     final newTask = Task(
         id: widget.task?.id, // Keep ID if editing
         title: _titleController.text,
         scheduledTime: dt,
         speakText: _speakController.text.isEmpty ? _titleController.text : _speakController.text,
     );

     final repo = TaskRepository();
     if (widget.task == null) {
         await repo.addTask(newTask);
     } else {
         await repo.updateTask(newTask);
     }
     
     if (mounted) Navigator.pop(context);
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
              const SizedBox(height: 32),
              
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
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
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
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
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
              
              const SizedBox(height: 32),
              
              // Speak Text
              const Text("Spoken Reminder (TTS)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
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
}
