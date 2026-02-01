// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String,
      scheduledTime: fields[3] as DateTime,
      speakText: fields[4] as String,
      isCompleted: fields[5] as bool,
      isRepeatEnabled: fields[6] as bool,
      categoryId: fields[7] as String,
      repeatType: fields[8] as String,
      customWeekdays: (fields[9] as List).cast<int>(),
      parentTaskId: fields[10] as String?,
      isRecurringSeries: fields[11] as bool,
      priority: fields[12] as int,
      preReminders: (fields[13] as List).cast<int>(),
      labelIds: (fields[15] as List).cast<String>(),
      updatedAt: fields[14] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.scheduledTime)
      ..writeByte(4)
      ..write(obj.speakText)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.isRepeatEnabled)
      ..writeByte(7)
      ..write(obj.categoryId)
      ..writeByte(8)
      ..write(obj.repeatType)
      ..writeByte(9)
      ..write(obj.customWeekdays)
      ..writeByte(10)
      ..write(obj.parentTaskId)
      ..writeByte(11)
      ..write(obj.isRecurringSeries)
      ..writeByte(12)
      ..write(obj.priority)
      ..writeByte(13)
      ..write(obj.preReminders)
      ..writeByte(14)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.labelIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
