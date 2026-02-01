// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_operation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncOperationAdapter extends TypeAdapter<SyncOperation> {
  @override
  final int typeId = 2;

  @override
  SyncOperation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncOperation(
      type: fields[0] as SyncOperationType,
      entityId: fields[1] as String,
      jsonPayload: fields[2] as String?,
      createdAt: fields[3] as DateTime?,
      retryCount: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SyncOperation obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.entityId)
      ..writeByte(2)
      ..write(obj.jsonPayload)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.retryCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOperationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SyncOperationTypeAdapter extends TypeAdapter<SyncOperationType> {
  @override
  final int typeId = 3;

  @override
  SyncOperationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncOperationType.upsertTask;
      case 1:
        return SyncOperationType.deleteTask;
      case 2:
        return SyncOperationType.upsertCategory;
      case 3:
        return SyncOperationType.deleteCategory;
      case 4:
        return SyncOperationType.upsertLabel;
      case 5:
        return SyncOperationType.deleteLabel;
      default:
        return SyncOperationType.upsertTask;
    }
  }

  @override
  void write(BinaryWriter writer, SyncOperationType obj) {
    switch (obj) {
      case SyncOperationType.upsertTask:
        writer.writeByte(0);
        break;
      case SyncOperationType.deleteTask:
        writer.writeByte(1);
        break;
      case SyncOperationType.upsertCategory:
        writer.writeByte(2);
        break;
      case SyncOperationType.deleteCategory:
        writer.writeByte(3);
        break;
      case SyncOperationType.upsertLabel:
        writer.writeByte(4);
        break;
      case SyncOperationType.deleteLabel:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOperationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
