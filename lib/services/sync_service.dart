import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_model.dart';
import '../models/category_model.dart';
import '../models/label_model.dart';
import '../repositories/task_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/label_repository.dart';

/// Service for syncing data with Firebase Realtime Database
/// Uses last-write-wins conflict resolution based on updatedAt timestamp
class SyncService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription? _tasksSubscription;
  StreamSubscription? _categoriesSubscription;
  
  /// Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;
  
  /// Get current user ID
  String? get userId => _auth.currentUser?.uid;
  
  /// Firebase RTDB reference for user's tasks
  DatabaseReference get _tasksRef => 
      FirebaseDatabase.instance.ref('users/$userId/tasks');
  
  /// Firebase RTDB reference for user's categories
  DatabaseReference get _categoriesRef => 
      FirebaseDatabase.instance.ref('users/$userId/categories');
  
  /// Firebase RTDB reference for user's labels
  DatabaseReference get _labelsRef => 
      FirebaseDatabase.instance.ref('users/$userId/labels');
  
  // ========== PUSH METHODS ==========
  
  /// Push a task to Firebase RTDB
  Future<void> pushTask(Task task) async {
    if (!isLoggedIn) return;
    await _tasksRef.child(task.id).set(task.toJson());
  }
  
  /// Push a category to Firebase RTDB
  Future<void> pushCategory(Category category) async {
    if (!isLoggedIn) return;
    await _categoriesRef.child(category.id).set(category.toJson());
  }
  
  /// Delete a task from Firebase RTDB
  Future<void> deleteTaskRemote(String taskId) async {
    if (!isLoggedIn) return;
    await _tasksRef.child(taskId).remove();
  }
  
  /// Delete a category from Firebase RTDB
  Future<void> deleteCategoryRemote(String categoryId) async {
    if (!isLoggedIn) return;
    await _categoriesRef.child(categoryId).remove();
  }
  
  /// Push a label to Firebase RTDB
  Future<void> pushLabel(Label label) async {
    if (!isLoggedIn) return;
    await _labelsRef.child(label.id).set(label.toJson());
  }
  
  /// Delete a label from Firebase RTDB
  Future<void> deleteLabelRemote(String labelId) async {
    if (!isLoggedIn) return;
    await _labelsRef.child(labelId).remove();
  }
  
  // ========== PULL & MERGE ==========
  
  /// Pull all remote data and merge with local using last-write-wins
  Future<void> pullAndMerge() async {
    if (!isLoggedIn) return;
    
    await _pullAndMergeTasks();
    await _pullAndMergeCategories();
  }
  
  /// Pull tasks from remote and merge with local
  Future<void> _pullAndMergeTasks() async {
    try {
      final snapshot = await _tasksRef.get();
      if (!snapshot.exists || snapshot.value == null) return;
      
      final remoteData = Map<String, dynamic>.from(snapshot.value as Map);
      final taskBox = await Hive.openBox<Task>(TaskRepository.boxName);
      
      for (final entry in remoteData.entries) {
        final remoteTask = Task.fromJson(Map<String, dynamic>.from(entry.value));
        final localTask = taskBox.values.cast<Task?>().firstWhere(
          (t) => t?.id == remoteTask.id,
          orElse: () => null,
        );
        
        if (localTask == null) {
          // Remote task doesn't exist locally - add it
          await taskBox.add(remoteTask);
        } else {
          // Compare updatedAt timestamps - last write wins
          if (remoteTask.updatedAt.isAfter(localTask.updatedAt)) {
            // Remote is newer - update local
            localTask.title = remoteTask.title;
            localTask.description = remoteTask.description;
            localTask.scheduledTime = remoteTask.scheduledTime;
            localTask.speakText = remoteTask.speakText;
            localTask.isCompleted = remoteTask.isCompleted;
            localTask.isRepeatEnabled = remoteTask.isRepeatEnabled;
            localTask.categoryId = remoteTask.categoryId;
            localTask.repeatType = remoteTask.repeatType;
            localTask.customWeekdays = remoteTask.customWeekdays;
            localTask.parentTaskId = remoteTask.parentTaskId;
            localTask.isRecurringSeries = remoteTask.isRecurringSeries;
            localTask.priority = remoteTask.priority;
            localTask.preReminders = remoteTask.preReminders;
            localTask.updatedAt = remoteTask.updatedAt;
            await localTask.save();
          } else if (localTask.updatedAt.isAfter(remoteTask.updatedAt)) {
            // Local is newer - push to remote
            await pushTask(localTask);
          }
          // If timestamps are equal, no action needed
        }
      }
      
      // Check for local tasks not in remote (new local tasks)
      for (final localTask in taskBox.values) {
        final existsInRemote = remoteData.containsKey(localTask.id);
        if (!existsInRemote) {
          // Push local task to remote
          await pushTask(localTask);
        }
      }
    } catch (e) {
      print('Error pulling and merging tasks: $e');
    }
  }
  
  /// Pull categories from remote and merge with local
  Future<void> _pullAndMergeCategories() async {
    try {
      final snapshot = await _categoriesRef.get();
      if (!snapshot.exists || snapshot.value == null) return;
      
      final remoteData = Map<String, dynamic>.from(snapshot.value as Map);
      final categoryBox = await Hive.openBox<Category>(CategoryRepository.boxName);
      
      for (final entry in remoteData.entries) {
        final remoteCategory = Category.fromJson(Map<String, dynamic>.from(entry.value));
        final localCategory = categoryBox.get(remoteCategory.id);
        
        if (localCategory == null) {
          // Remote category doesn't exist locally - add it
          await categoryBox.put(remoteCategory.id, remoteCategory);
        } else {
          // Compare updatedAt timestamps - last write wins
          if (remoteCategory.updatedAt.isAfter(localCategory.updatedAt)) {
            // Remote is newer - update local
            localCategory.name = remoteCategory.name;
            localCategory.colorValue = remoteCategory.colorValue;
            localCategory.updatedAt = remoteCategory.updatedAt;
            await localCategory.save();
          } else if (localCategory.updatedAt.isAfter(remoteCategory.updatedAt)) {
            // Local is newer - push to remote
            await pushCategory(localCategory);
          }
        }
      }
      
      // Check for local categories not in remote
      for (final localCategory in categoryBox.values) {
        final existsInRemote = remoteData.containsKey(localCategory.id);
        if (!existsInRemote) {
          await pushCategory(localCategory);
        }
      }
    } catch (e) {
      print('Error pulling and merging categories: $e');
    }
  }
  
  // ========== REAL-TIME SYNC ==========
  
  /// Start listening for real-time updates from Firebase
  void startRealtimeSync() {
    if (!isLoggedIn) return;
    
    stopRealtimeSync(); // Clean up any existing listeners
    
    // Listen for task changes
    _tasksSubscription = _tasksRef.onValue.listen((event) async {
      if (!event.snapshot.exists || event.snapshot.value == null) return;
      await _pullAndMergeTasks();
    });
    
    // Listen for category changes
    _categoriesSubscription = _categoriesRef.onValue.listen((event) async {
      if (!event.snapshot.exists || event.snapshot.value == null) return;
      await _pullAndMergeCategories();
    });
  }
  
  /// Stop real-time sync listeners
  void stopRealtimeSync() {
    _tasksSubscription?.cancel();
    _tasksSubscription = null;
    _categoriesSubscription?.cancel();
    _categoriesSubscription = null;
  }
  
  // ========== INITIAL SYNC ==========
  
  /// Perform initial sync when user logs in
  /// Uploads all local data then pulls remote
  Future<void> performInitialSync() async {
    if (!isLoggedIn) return;
    
    // First, push all local data to remote
    await _pushAllLocalTasks();
    await _pushAllLocalCategories();
    
    // Then pull and merge to get any data from other devices
    await pullAndMerge();
    
    // Start real-time sync
    startRealtimeSync();
  }
  
  /// Push all local tasks to remote (for initial sync)
  Future<void> _pushAllLocalTasks() async {
    try {
      final taskBox = await Hive.openBox<Task>(TaskRepository.boxName);
      for (final task in taskBox.values) {
        await pushTask(task);
      }
    } catch (e) {
      print('Error pushing all local tasks: $e');
    }
  }
  
  /// Push all local categories to remote (for initial sync)
  Future<void> _pushAllLocalCategories() async {
    try {
      final categoryBox = await Hive.openBox<Category>(CategoryRepository.boxName);
      for (final category in categoryBox.values) {
        await pushCategory(category);
      }
    } catch (e) {
      print('Error pushing all local categories: $e');
    }
  }
  
  /// Clean up resources
  void dispose() {
    stopRealtimeSync();
  }
}
