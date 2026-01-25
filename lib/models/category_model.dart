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

  Category({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  /// Get the Color object from the stored int value
  Color get color => Color(colorValue);

  /// Check if this is a default (non-deletable) category
  bool get isDefault => defaultCategories.any((c) => c.id == id);
}
