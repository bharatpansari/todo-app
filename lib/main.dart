import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'models/task_model.dart';
import 'models/category_model.dart';
import 'repositories/category_repository.dart';
import 'repositories/task_repository.dart';
import 'repositories/settings_repository.dart';
import 'services/native_bridge.dart';
import 'ui/task_list_screen.dart';
import 'ui/login_screen.dart';

import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(CategoryAdapter());
  
  // Initialize repositories
  await SettingsRepository().init();
  await CategoryRepository().initializeDefaultCategories();
  
  // Setup alarm fired callback for recurring tasks
  final taskRepository = TaskRepository();
  NativeBridge.setAlarmFiredCallback((taskId) async {
    await taskRepository.handleAlarmFired(taskId);
  });
  
  // Setup snooze callback
  NativeBridge.setTaskSnoozedCallback((taskId, snoozeMinutes) async {
    await taskRepository.handleTaskSnoozed(taskId, snoozeMinutes);
  });
  
  // DEPRECATED: Mark-done callback removed - now using manual checkbox for completion
  // NativeBridge.setTaskMarkedDoneCallback((taskId) async {
  //   await taskRepository.handleTaskMarkedDone(taskId);
  // });
  
  // Initialize bridge to setup method handler
  NativeBridge();
  
  // Request permissions
  await [
    Permission.notification,
    Permission.scheduleExactAlarm,
  ].request();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsRepo = SettingsRepository();
    
    return ValueListenableBuilder(
      valueListenable: settingsRepo.themeModeListenable,
      builder: (context, box, child) {
        return MaterialApp(
          title: 'Talkative Todo',
          debugShowCheckedModeBanner: false,
          themeMode: settingsRepo.getThemeMode(),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6C63FF),
              brightness: Brightness.light,
              primary: const Color(0xFF6C63FF),
              secondary: const Color(0xFFFF6584),
            ),
            scaffoldBackgroundColor: const Color(0xFFF8F9FE),
            textTheme: GoogleFonts.outfitTextTheme(),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              backgroundColor: Colors.transparent,
              centerTitle: false,
              titleTextStyle: TextStyle(
                  color: Colors.black87, 
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit'
              ),
              iconTheme: IconThemeData(color: Colors.black87),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6C63FF),
              brightness: Brightness.dark,
              primary: const Color(0xFF6C63FF),
              secondary: const Color(0xFFFF6584),
              surface: const Color(0xFF1E1E1E),
              background: const Color(0xFF121212),
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              backgroundColor: Colors.transparent,
              centerTitle: false,
              titleTextStyle: TextStyle(
                  color: Colors.white, 
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit'
              ),
              iconTheme: IconThemeData(color: Colors.white),
            ),

          ),
          home: FirebaseAuth.instance.currentUser == null 
              ? const LoginScreen() 
              : const TaskListScreen(),
        );
      }
    );
  }
}
