import 'package:hive_flutter/hive_flutter.dart';
import '../models/category_model.dart';
import '../services/sync_queue.dart';

class CategoryRepository {
  static const String boxName = 'categoriesBox';
  SyncQueue? _syncQueue;
  
  /// Set the sync queue for cloud sync operations
  void setSyncQueue(SyncQueue syncQueue) {
    _syncQueue = syncQueue;
  }

  Future<Box<Category>> get _box async => await Hive.openBox<Category>(boxName);

  /// Initialize default categories if the box is empty
  Future<void> initializeDefaultCategories() async {
    final box = await _box;
    if (box.isEmpty) {
      for (final category in defaultCategories) {
        await box.put(category.id, category);
      }
    }
  }

  /// Get all categories
  Future<List<Category>> getAllCategories() async {
    final box = await _box;
    return box.values.toList();
  }

  /// Get a category by ID
  Future<Category?> getCategoryById(String id) async {
    final box = await _box;
    return box.get(id);
  }

  /// Add a new category
  Future<void> addCategory(Category category) async {
    final box = await _box;
    category.updatedAt = DateTime.now();
    await box.put(category.id, category);
    
    // Enqueue for cloud sync
    _syncQueue?.enqueueCategoryUpsert(category);
  }

  /// Update an existing category
  Future<void> updateCategory(Category category) async {
    category.updatedAt = DateTime.now();
    await category.save();
    
    // Enqueue for cloud sync
    _syncQueue?.enqueueCategoryUpsert(category);
  }

  /// Delete a category (only custom categories can be deleted)
  Future<bool> deleteCategory(String id) async {
    final box = await _box;
    final category = box.get(id);
    
    // Prevent deletion of default categories
    if (category != null && category.isDefault) {
      return false;
    }
    
    await box.delete(id);
    
    // Enqueue for cloud sync
    _syncQueue?.enqueueCategoryDelete(id);
    
    return true;
  }

  /// Check if a category name already exists
  Future<bool> categoryNameExists(String name) async {
    final categories = await getAllCategories();
    return categories.any(
      (c) => c.name.toLowerCase() == name.toLowerCase()
    );
  }
}
