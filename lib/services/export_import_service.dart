import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/task_model.dart';
import '../repositories/task_repository.dart';

/// Result of an import operation
class ImportResult {
  final int imported;
  final int skipped;
  final int errors;
  final List<String> errorMessages;

  ImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
    this.errorMessages = const [],
  });

  @override
  String toString() {
    return 'Imported: $imported, Skipped: $skipped, Errors: $errors';
  }
}

/// Service for exporting and importing tasks
class ExportImportService {
  final TaskRepository _taskRepository = TaskRepository();

  /// Export all tasks to JSON string
  Future<String> exportToJson() async {
    final tasks = await _taskRepository.getAllTasks();
    final jsonList = tasks.map((task) => task.toJson()).toList();
    
    final exportData = {
      'version': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'appName': 'TalkativeTodo',
      'taskCount': tasks.length,
      'tasks': jsonList,
    };
    
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Export all tasks to CSV string
  Future<String> exportToCsv() async {
    final tasks = await _taskRepository.getAllTasks();
    
    // CSV header
    final header = [
      'id',
      'title',
      'description',
      'scheduledTime',
      'speakText',
      'isCompleted',
      'isRepeatEnabled',
      'categoryId',
      'repeatType',
      'customWeekdays',
      'parentTaskId',
      'isRecurringSeries',
      'priority',
    ].join(',');
    
    // CSV rows
    final rows = tasks.map((task) {
      return [
        _escapeCsv(task.id),
        _escapeCsv(task.title),
        _escapeCsv(task.description),
        _escapeCsv(task.scheduledTime.toIso8601String()),
        _escapeCsv(task.speakText),
        task.isCompleted.toString(),
        task.isRepeatEnabled.toString(),
        _escapeCsv(task.categoryId),
        _escapeCsv(task.repeatType),
        _escapeCsv(task.customWeekdays.join(';')),
        _escapeCsv(task.parentTaskId ?? ''),
        task.isRecurringSeries.toString(),
        task.priority.toString(),
      ].join(',');
    }).join('\n');
    
    return '$header\n$rows';
  }

  /// Escape a string for CSV (wrap in quotes if contains comma/quote/newline)
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Export to a temporary file and return the file
  Future<File> exportToFile({required String format}) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    String content;
    String filename;
    
    if (format == 'csv') {
      content = await exportToCsv();
      filename = 'talkative_todo_export_$timestamp.csv';
    } else {
      content = await exportToJson();
      filename = 'talkative_todo_export_$timestamp.json';
    }
    
    final file = File('${directory.path}/$filename');
    await file.writeAsString(content);
    return file;
  }

  /// Export and share via system share sheet
  Future<void> shareExport({required String format}) async {
    final file = await exportToFile(format: format);
    
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Talkative Todo Export',
        text: 'My tasks export from Talkative Todo',
      ),
    );
  }

  /// Pick a file for import
  Future<String?> pickImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      return await file.readAsString();
    }
    return null;
  }

  /// Import tasks from JSON string
  /// [merge] = true: keep existing, add new (skip duplicates)
  /// [merge] = false: replace all tasks
  Future<ImportResult> importFromJson(String jsonString, {bool merge = true}) async {
    int imported = 0;
    int skipped = 0;
    int errors = 0;
    List<String> errorMessages = [];
    
    try {
      final data = json.decode(jsonString);
      
      // Validate format
      if (data is! Map<String, dynamic>) {
        return ImportResult(
          imported: 0,
          skipped: 0,
          errors: 1,
          errorMessages: ['Invalid JSON format: expected object'],
        );
      }
      
      // Get tasks array
      final tasksJson = data['tasks'];
      if (tasksJson is! List) {
        return ImportResult(
          imported: 0,
          skipped: 0,
          errors: 1,
          errorMessages: ['Invalid JSON format: missing tasks array'],
        );
      }
      
      // Get existing task IDs if merging
      Set<String> existingIds = {};
      if (merge) {
        final existingTasks = await _taskRepository.getAllTasks();
        existingIds = existingTasks.map((t) => t.id).toSet();
      } else {
        // Replace mode: delete all existing tasks first
        final existingTasks = await _taskRepository.getAllTasks();
        for (final task in existingTasks) {
          await _taskRepository.deleteTask(task);
        }
      }
      
      // Import each task
      for (final taskJson in tasksJson) {
        try {
          if (taskJson is! Map<String, dynamic>) {
            errors++;
            errorMessages.add('Invalid task entry: not an object');
            continue;
          }
          
          final task = Task.fromJson(taskJson);
          
          // Skip duplicates in merge mode
          if (merge && existingIds.contains(task.id)) {
            skipped++;
            continue;
          }
          
          await _taskRepository.addTask(task);
          imported++;
        } catch (e) {
          errors++;
          errorMessages.add('Error importing task: $e');
        }
      }
      
    } catch (e) {
      return ImportResult(
        imported: imported,
        skipped: skipped,
        errors: errors + 1,
        errorMessages: [...errorMessages, 'JSON parse error: $e'],
      );
    }
    
    return ImportResult(
      imported: imported,
      skipped: skipped,
      errors: errors,
      errorMessages: errorMessages,
    );
  }
}
