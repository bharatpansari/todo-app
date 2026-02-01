import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'category_model.g.dart';

/// Default category ID for migration of existing tasks
const String defaultCategoryId = 'general';

/// Pre-defined default categories
final List<Category> defaultCategories = [
  Category(
    id: 'general',
    name: 'General',
    colorValue: Colors.grey.value,
  ),
  Category(
    id: 'work',
    name: 'Work',
    colorValue: Colors.blue.value,
  ),
  Category(
    id: 'personal',
    name: 'Personal',
    colorValue: Colors.purple.value,
  ),
  Category(
    id: 'health',
    name: 'Health',
    colorValue: Colors.green.value,
  ),
  Category(
    id: 'shopping',
    name: 'Shopping',
    colorValue: Colors.orange.value,
  ),
];

@HiveType(typeId: 1)
class Category extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int colorValue;

  /// Last update timestamp for sync conflict resolution (last-write-wins)
  @HiveField(3)
  DateTime updatedAt;

  Category({
    required this.id,
    required this.name,
    required this.colorValue,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Get the Color object from the stored int value
  Color get color => Color(colorValue);

  /// Check if this is a default (non-deletable) category
  bool get isDefault => defaultCategories.any((c) => c.id == id);

  /// Convert category to JSON for sync/export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create category from JSON for sync/import
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed',
      colorValue: json['colorValue'] as int? ?? 0xFF9E9E9E,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
