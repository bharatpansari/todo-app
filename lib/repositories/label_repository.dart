import 'package:hive_flutter/hive_flutter.dart';
import '../models/label_model.dart';
import '../services/sync_queue.dart';

class LabelRepository {
  static const String boxName = 'labelsBox';
  SyncQueue? _syncQueue;
  
  /// Set the sync queue for cloud sync operations
  void setSyncQueue(SyncQueue syncQueue) {
    _syncQueue = syncQueue;
  }

  Future<Box<Label>> get _box async => await Hive.openBox<Label>(boxName);

  /// Initialize default labels if the box is empty
  Future<void> initializeDefaultLabels() async {
    final box = await _box;
    if (box.isEmpty) {
      for (final label in defaultLabels) {
        await box.put(label.id, label);
      }
    }
  }

  /// Get all labels
  Future<List<Label>> getAllLabels() async {
    final box = await _box;
    return box.values.toList();
  }

  /// Get a label by ID
  Future<Label?> getLabelById(String id) async {
    final box = await _box;
    return box.get(id);
  }

  /// Get multiple labels by IDs
  Future<List<Label>> getLabelsByIds(List<String> ids) async {
    final box = await _box;
    return ids.map((id) => box.get(id)).whereType<Label>().toList();
  }

  /// Add a new label
  Future<void> addLabel(Label label) async {
    final box = await _box;
    label.updatedAt = DateTime.now();
    await box.put(label.id, label);
    
    // Enqueue for cloud sync
    _syncQueue?.enqueueLabelUpsert(label);
  }

  /// Update an existing label
  Future<void> updateLabel(Label label) async {
    label.updatedAt = DateTime.now();
    await label.save();
    
    // Enqueue for cloud sync
    _syncQueue?.enqueueLabelUpsert(label);
  }

  /// Delete a label (only custom labels can be deleted)
  Future<bool> deleteLabel(String id) async {
    final box = await _box;
    final label = box.get(id);
    
    // Prevent deletion of default labels
    if (label != null && label.isDefault) {
      return false;
    }
    
    await box.delete(id);
    
    // Enqueue for cloud sync
    _syncQueue?.enqueueLabelDelete(id);
    
    return true;
  }

  /// Check if a label name already exists
  Future<bool> labelNameExists(String name) async {
    final labels = await getAllLabels();
    return labels.any(
      (l) => l.name.toLowerCase() == name.toLowerCase()
    );
  }
}
