import 'package:firebase_database/firebase_database.dart';

/// Service for Firebase Realtime Database operations.
/// Currently sets up the database structure; CRUD methods will be added later.
class DatabaseService {
  final String userId;

  DatabaseService({required this.userId});

  /// Reference to the user's tasks in the database.
  /// Structure: /users/{userId}/tasks
  DatabaseReference get tasksRef => 
      FirebaseDatabase.instance.ref('users/$userId/tasks');
}
