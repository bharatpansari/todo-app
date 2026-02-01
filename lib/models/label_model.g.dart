// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'label_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LabelAdapter extends TypeAdapter<Label> {
  @override
  final int typeId = 4;

  @override
  Label read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Label(
      id: fields[0] as String,
      name: fields[1] as String,
      colorValue: fields[2] as int,
      updatedAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Label obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorValue)
      ..writeByte(3)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
