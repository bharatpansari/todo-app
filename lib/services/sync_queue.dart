import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/sync_operation.dart';
import '../models/task_model.dart';
import '../models/category_model.dart';
import 'sync_service.dart';

/// Manages a queue of pending sync operations with retry logic
class SyncQueue {
  static const String boxName = 'syncQueueBox';
  
  SyncService? _syncService;
  StreamSubscription? _connectivitySubscription;
  bool _isProcessing = false;
  
  Future<Box<SyncOperation>> get _box async => 
      await Hive.openBox<SyncOperation>(boxName);
  
  /// Initialize the sync queue with a sync service
  void initialize(SyncService syncService) {
    _syncService = syncService;
    _startConnectivityMonitor();
  }
  
  /// Start monitoring connectivity changes
  void _startConnectivityMonitor() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      // Check if we have any connectivity
      final hasConnectivity = results.any((r) => 
          r != ConnectivityResult.none);
      if (hasConnectivity) {
        processQueue();
      }
    });
  }
  
  /// Stop connectivity monitoring
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
  
  /// Enqueue a task upsert operation
  Future<void> enqueueTaskUpsert(Task task) async {
    await _enqueue(SyncOperation(
      type: SyncOperationType.upsertTask,
      entityId: task.id,
      jsonPayload: jsonEncode(task.toJson()),
    ));
  }
  
  /// Enqueue a task delete operation
  Future<void> enqueueTaskDelete(String taskId) async {
    await _enqueue(SyncOperation(
      type: SyncOperationType.deleteTask,
      entityId: taskId,
    ));
  }
  
  /// Enqueue a category upsert operation
  Future<void> enqueueCategoryUpsert(Category category) async {
    await _enqueue(SyncOperation(
      type: SyncOperationType.upsertCategory,
      entityId: category.id,
      jsonPayload: jsonEncode(category.toJson()),
    ));
  }
  
  /// Enqueue a category delete operation
  Future<void> enqueueCategoryDelete(String categoryId) async {
    await _enqueue(SyncOperation(
      type: SyncOperationType.deleteCategory,
      entityId: categoryId,
    ));
  }
  
  /// Internal enqueue method
  Future<void> _enqueue(SyncOperation operation) async {
    final box = await _box;
    
    // Remove any existing operation for the same entity to avoid duplicates
    final existing = box.values.where((op) => 
        op.entityId == operation.entityId && op.type == operation.type);
    for (final op in existing.toList()) {
      await op.delete();
    }
    
    await box.add(operation);
    
    // Try to process immediately
    processQueue();
  }
  
  /// Process all pending operations in the queue
  Future<void> processQueue() async {
    if (_isProcessing || _syncService == null) return;
    
    // Check if user is logged in
    if (!_syncService!.isLoggedIn) return;
    
    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasConnectivity = connectivityResult.any((r) => 
        r != ConnectivityResult.none);
    if (!hasConnectivity) return;
    
    _isProcessing = true;
    
    try {
      final box = await _box;
      final operations = box.values.toList();
      
      for (final operation in operations) {
        try {
          await _processOperation(operation);
          await operation.delete(); // Success - remove from queue
        } catch (e) {
          operation.incrementRetry();
          if (operation.canRetry) {
            await operation.save();
          } else {
            // Max retries exceeded - remove from queue
            // Will be synced on next full sync
            await operation.delete();
          }
        }
      }
    } finally {
      _isProcessing = false;
    }
  }
  
  /// Process a single sync operation
  Future<void> _processOperation(SyncOperation operation) async {
    switch (operation.type) {
      case SyncOperationType.upsertTask:
        if (operation.jsonPayload != null) {
          final task = Task.fromJson(jsonDecode(operation.jsonPayload!));
          await _syncService!.pushTask(task);
        }
        break;
        
      case SyncOperationType.deleteTask:
        await _syncService!.deleteTaskRemote(operation.entityId);
        break;
        
      case SyncOperationType.upsertCategory:
        if (operation.jsonPayload != null) {
          final category = Category.fromJson(jsonDecode(operation.jsonPayload!));
          await _syncService!.pushCategory(category);
        }
        break;
        
      case SyncOperationType.deleteCategory:
        await _syncService!.deleteCategoryRemote(operation.entityId);
        break;
    }
  }
  
  /// Get pending operation count
  Future<int> get pendingCount async {
    final box = await _box;
    return box.length;
  }
  
  /// Clear all pending operations
  Future<void> clearQueue() async {
    final box = await _box;
    await box.clear();
  }
}
