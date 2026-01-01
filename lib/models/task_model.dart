import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'task_model.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  DateTime scheduledTime;

  @HiveField(4)
  String speakText;

  @HiveField(5)
  bool isCompleted;

  @HiveField(6)
  bool isRepeatEnabled;

  Task({
    String? id,
    required this.title,
    this.description = '',
    required this.scheduledTime,
    required this.speakText,
    this.isCompleted = false,
    this.isRepeatEnabled = false,
  }) : id = id ?? const Uuid().v4();
}
