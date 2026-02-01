import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../repositories/task_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/label_repository.dart';

/// Service for handling Firebase Authentication with Google Sign-In.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Returns the currently signed-in user, or null if not signed in.
  User? get currentUser => _auth.currentUser;
  
  /// Check if user is currently logged in
  bool get isLoggedIn => currentUser != null;
  
  /// Stream of auth state changes for reactive UI
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Signs in with Google OAuth flow.
  /// Returns the [User] on success, or null if cancelled/failed.
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain auth details from the request
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
      
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  /// Signs in with Email and Password.
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  /// Signs up with Email and Password.
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  /// Signs out from both Firebase and Google.
  /// Also clears all local data to prevent data leakage between users.
  Future<void> signOut() async {
    // Clear all local Hive data first
    await clearAllLocalData();
    
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
  
  /// Clears all local Hive data (tasks, categories, labels, sync queue)
  /// Called on logout to prevent data leakage between different user accounts
  Future<void> clearAllLocalData() async {
    try {
      // Clear tasks box
      final tasksBox = await Hive.openBox(TaskRepository.boxName);
      await tasksBox.clear();
      
      // Clear categories box
      final categoriesBox = await Hive.openBox(CategoryRepository.boxName);
      await categoriesBox.clear();
      
      // Clear labels box
      final labelsBox = await Hive.openBox(LabelRepository.boxName);
      await labelsBox.clear();
      
      // Clear sync queue box
      final syncQueueBox = await Hive.openBox('syncQueueBox');
      await syncQueueBox.clear();
      
      print('All local data cleared on logout');
    } catch (e) {
      print('Error clearing local data: $e');
    }
  }
}
