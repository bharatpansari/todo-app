import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'label_model.g.dart';

/// Pre-defined default labels
final List<Label> defaultLabels = [
  Label(
    id: 'urgent',
    name: 'Urgent',
    colorValue: const Color(0xFFE53935).value,
  ),
  Label(
    id: 'important',
    name: 'Important',
    colorValue: const Color(0xFFFF9800).value,
  ),
  Label(
    id: 'quick',
    name: 'Quick Win',
    colorValue: const Color(0xFF4CAF50).value,
  ),
  Label(
    id: 'waiting',
    name: 'Waiting',
    colorValue: const Color(0xFF9C27B0).value,
  ),
  Label(
    id: 'focus',
    name: 'Focus',
    colorValue: const Color(0xFF2196F3).value,
  ),
];

@HiveType(typeId: 4)
class Label extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int colorValue;

  /// Last update timestamp for sync conflict resolution
  @HiveField(3)
  DateTime updatedAt;

  Label({
    required this.id,
    required this.name,
    required this.colorValue,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Get the Color object from the stored int value
  Color get color => Color(colorValue);

  /// Check if this is a default label
  bool get isDefault => defaultLabels.any((l) => l.id == id);

  /// Convert label to JSON for sync/export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create label from JSON for sync/import
  factory Label.fromJson(Map<String, dynamic> json) {
    return Label(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed',
      colorValue: json['colorValue'] as int? ?? 0xFF9E9E9E,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
