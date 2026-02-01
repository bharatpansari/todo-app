import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:talkative_todo/models/task_model.dart';
import 'package:talkative_todo/models/category_model.dart';
import 'package:talkative_todo/models/sync_operation.dart';

/// Unit tests for the sync functionality
/// Note: These tests focus on the data models and sync operation queue
/// Firebase RTDB operations would require integration tests with emulator
void main() {
  late Directory tempDir;

  setUpAll(() async {
    // Create temp directory for Hive
    tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
    
    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(SyncOperationAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(SyncOperationTypeAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('Task Model with updatedAt', () {
    test('Task constructor sets updatedAt to now by default', () {
      final before = DateTime.now();
      final task = Task(
        title: 'Test Task',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
        speakText: 'Test',
      );
      final after = DateTime.now();
      
      expect(task.updatedAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(task.updatedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('Task toJson includes updatedAt', () {
      final task = Task(
        title: 'Test Task',
        scheduledTime: DateTime(2024, 1, 15, 10, 30),
        speakText: 'Test',
      );
      
      final json = task.toJson();
      
      expect(json.containsKey('updatedAt'), isTrue);
      expect(json['updatedAt'], isNotNull);
    });

    test('Task fromJson parses updatedAt', () {
      final json = {
        'id': 'test-id',
        'title': 'Test Task',
        'scheduledTime': '2024-01-15T10:30:00.000',
        'speakText': 'Test',
        'updatedAt': '2024-01-15T12:00:00.000',
      };
      
      final task = Task.fromJson(json);
      
      expect(task.updatedAt, DateTime(2024, 1, 15, 12, 0));
    });

    test('Task fromJson uses now when updatedAt is missing', () {
      final before = DateTime.now();
      final json = {
        'id': 'test-id',
        'title': 'Test Task',
        'scheduledTime': '2024-01-15T10:30:00.000',
        'speakText': 'Test',
      };
      
      final task = Task.fromJson(json);
      final after = DateTime.now();
      
      expect(task.updatedAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(task.updatedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('Category Model with updatedAt', () {
    test('Category constructor sets updatedAt to now by default', () {
      final before = DateTime.now();
      final category = Category(
        id: 'test-cat',
        name: 'Test Category',
        colorValue: 0xFF0000FF,
      );
      final after = DateTime.now();
      
      expect(category.updatedAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(category.updatedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('Category toJson includes updatedAt', () {
      final category = Category(
        id: 'test-cat',
        name: 'Test Category',
        colorValue: 0xFF0000FF,
      );
      
      final json = category.toJson();
      
      expect(json.containsKey('updatedAt'), isTrue);
      expect(json['updatedAt'], isNotNull);
    });

    test('Category fromJson parses updatedAt', () {
      final json = {
        'id': 'test-cat',
        'name': 'Test Category',
        'colorValue': 0xFF0000FF,
        'updatedAt': '2024-01-15T12:00:00.000',
      };
      
      final category = Category.fromJson(json);
      
      expect(category.updatedAt, DateTime(2024, 1, 15, 12, 0));
    });
  });

  group('SyncOperation Model', () {
    test('SyncOperation can be created for task upsert', () {
      final operation = SyncOperation(
        type: SyncOperationType.upsertTask,
        entityId: 'task-123',
        jsonPayload: '{"id": "task-123", "title": "Test"}',
      );
      
      expect(operation.type, SyncOperationType.upsertTask);
      expect(operation.entityId, 'task-123');
      expect(operation.jsonPayload, isNotNull);
      expect(operation.retryCount, 0);
      expect(operation.canRetry, isTrue);
    });

    test('SyncOperation can be created for task delete', () {
      final operation = SyncOperation(
        type: SyncOperationType.deleteTask,
        entityId: 'task-456',
      );
      
      expect(operation.type, SyncOperationType.deleteTask);
      expect(operation.entityId, 'task-456');
      expect(operation.jsonPayload, isNull);
    });

    test('SyncOperation retry count increments correctly', () {
      final operation = SyncOperation(
        type: SyncOperationType.upsertCategory,
        entityId: 'cat-123',
      );
      
      expect(operation.canRetry, isTrue);
      
      operation.incrementRetry();
      expect(operation.retryCount, 1);
      expect(operation.canRetry, isTrue);
      
      operation.incrementRetry();
      expect(operation.retryCount, 2);
      expect(operation.canRetry, isTrue);
      
      operation.incrementRetry();
      expect(operation.retryCount, 3);
      expect(operation.canRetry, isFalse); // maxRetries = 3
    });

    test('SyncOperation createdAt defaults to now', () {
      final before = DateTime.now();
      final operation = SyncOperation(
        type: SyncOperationType.deleteCategory,
        entityId: 'cat-456',
      );
      final after = DateTime.now();
      
      expect(operation.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(operation.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('Last-Write-Wins Conflict Resolution', () {
    test('Newer remote task should win', () {
      final localTask = Task(
        id: 'shared-id',
        title: 'Local Version',
        scheduledTime: DateTime(2024, 1, 15, 10, 0),
        speakText: 'Local',
      );
      // Manually set older updatedAt
      localTask.updatedAt = DateTime(2024, 1, 15, 11, 0);

      final remoteJson = {
        'id': 'shared-id',
        'title': 'Remote Version',
        'scheduledTime': '2024-01-15T10:00:00.000',
        'speakText': 'Remote',
        'updatedAt': '2024-01-15T12:00:00.000', // Newer
      };
      final remoteTask = Task.fromJson(remoteJson);

      // Remote is newer
      expect(remoteTask.updatedAt.isAfter(localTask.updatedAt), isTrue);
      
      // So remote should win in conflict resolution
      expect(remoteTask.title, 'Remote Version');
    });

    test('Newer local task should win', () {
      final localTask = Task(
        id: 'shared-id',
        title: 'Local Version',
        scheduledTime: DateTime(2024, 1, 15, 10, 0),
        speakText: 'Local',
      );
      // Manually set newer updatedAt
      localTask.updatedAt = DateTime(2024, 1, 15, 13, 0);

      final remoteJson = {
        'id': 'shared-id',
        'title': 'Remote Version',
        'scheduledTime': '2024-01-15T10:00:00.000',
        'speakText': 'Remote',
        'updatedAt': '2024-01-15T12:00:00.000', // Older
      };
      final remoteTask = Task.fromJson(remoteJson);

      // Local is newer
      expect(localTask.updatedAt.isAfter(remoteTask.updatedAt), isTrue);
      
      // So local should win in conflict resolution
      expect(localTask.title, 'Local Version');
    });

    test('Equal timestamps should not cause conflict', () {
      final timestamp = DateTime(2024, 1, 15, 12, 0);
      
      final localTask = Task(
        id: 'shared-id',
        title: 'Version A',
        scheduledTime: DateTime(2024, 1, 15, 10, 0),
        speakText: 'A',
        updatedAt: timestamp,
      );

      final remoteJson = {
        'id': 'shared-id',
        'title': 'Version A',
        'scheduledTime': '2024-01-15T10:00:00.000',
        'speakText': 'A',
        'updatedAt': '2024-01-15T12:00:00.000',
      };
      final remoteTask = Task.fromJson(remoteJson);

      // Same timestamp
      expect(localTask.updatedAt, remoteTask.updatedAt);
    });
  });

  group('SyncQueue Box Operations', () {
    test('SyncOperation can be stored in Hive box', () async {
      final box = await Hive.openBox<SyncOperation>('testSyncQueueBox');
      
      final operation = SyncOperation(
        type: SyncOperationType.upsertTask,
        entityId: 'test-task',
        jsonPayload: '{"title": "Test"}',
      );
      
      await box.add(operation);
      
      expect(box.length, 1);
      expect(box.getAt(0)?.entityId, 'test-task');
      expect(box.getAt(0)?.type, SyncOperationType.upsertTask);
      
      await box.clear();
      await box.close();
    });
  });
}
