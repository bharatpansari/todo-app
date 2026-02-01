import 'package:hive/hive.dart';

part 'sync_operation.g.dart';

/// Types of sync operations
@HiveType(typeId: 3)
enum SyncOperationType {
  @HiveField(0)
  upsertTask,
  
  @HiveField(1)
  deleteTask,
  
  @HiveField(2)
  upsertCategory,
  
  @HiveField(3)
  deleteCategory,
  
  @HiveField(4)
  upsertLabel,
  
  @HiveField(5)
  deleteLabel,
}

/// Represents a pending sync operation to be sent to Firebase RTDB
@HiveType(typeId: 2)
class SyncOperation extends HiveObject {
  @HiveField(0)
  final SyncOperationType type;

  @HiveField(1)
  final String entityId;

  /// JSON payload for upsert operations (null for deletes)
  @HiveField(2)
  final String? jsonPayload;

  @HiveField(3)
  final DateTime createdAt;

  /// Number of retry attempts
  @HiveField(4)
  int retryCount;

  SyncOperation({
    required this.type,
    required this.entityId,
    this.jsonPayload,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Max retries before giving up (will be retried on next app launch)
  static const int maxRetries = 3;

  /// Check if this operation can be retried
  bool get canRetry => retryCount < maxRetries;

  /// Increment retry count
  void incrementRetry() {
    retryCount++;
  }

  @override
  String toString() => 'SyncOperation($type, $entityId, retries: $retryCount)';
}
