
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'models/task_model.dart';
import 'models/category_model.dart';
import 'models/label_model.dart';
import 'models/sync_operation.dart';
import 'repositories/category_repository.dart';
import 'repositories/task_repository.dart';
import 'repositories/label_repository.dart';
import 'repositories/settings_repository.dart';
import 'services/native_bridge.dart';
import 'services/sync_service.dart';
import 'services/sync_queue.dart';
import 'ui/task_list_screen.dart';
import 'ui/login_screen.dart';

import 'package:permission_handler/permission_handler.dart';

// Global instances for sync
late SyncService syncService;
late SyncQueue syncQueue;
late TaskRepository taskRepository;
late CategoryRepository categoryRepository;
late LabelRepository labelRepository;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(LabelAdapter());
  Hive.registerAdapter(SyncOperationAdapter());
  Hive.registerAdapter(SyncOperationTypeAdapter());
  
  // Initialize repositories
  await SettingsRepository().init();
  categoryRepository = CategoryRepository();
  await categoryRepository.initializeDefaultCategories();
  labelRepository = LabelRepository();
  await labelRepository.initializeDefaultLabels();
  
  // Initialize sync services
  syncService = SyncService();
  syncQueue = SyncQueue();
  syncQueue.initialize(syncService);
  
  // Wire up repositories with sync queue
  taskRepository = TaskRepository();
  taskRepository.setSyncQueue(syncQueue);
  categoryRepository.setSyncQueue(syncQueue);
  
  // Setup alarm fired callback for recurring tasks
  NativeBridge.setAlarmFiredCallback((taskId) async {
    await taskRepository.handleAlarmFired(taskId);
  });
  
  // Setup snooze callback
  NativeBridge.setTaskSnoozedCallback((taskId, snoozeMinutes) async {
    await taskRepository.handleTaskSnoozed(taskId, snoozeMinutes);
  });
  
  // Initialize bridge to setup method handler
  NativeBridge();
  
  // Request permissions
  await [
    Permission.notification,
    Permission.scheduleExactAlarm,
  ].request();
  
  // If user is already logged in, start sync
  if (FirebaseAuth.instance.currentUser != null) {
    _startSync();
  }
  
  // Listen for auth state changes to start/stop sync
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      _startSync();
    } else {
      _stopSync();
    }
  });
  
  runApp(const MyApp());
}

/// Start cloud sync when logged in
void _startSync() {
  syncService.performInitialSync().then((_) {
    // Process any pending queue items
    syncQueue.processQueue();
  });
}

/// Stop sync when logged out
void _stopSync() {
  syncService.stopRealtimeSync();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsRepo = SettingsRepository();
    
    return ValueListenableBuilder(
      valueListenable: settingsRepo.themeModeListenable,
      builder: (context, box, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(MediaQuery.of(context).textScaleFactor.clamp(0.9, 1.2)),
          ),
          child: MaterialApp(
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
              tertiary: const Color(0xFF00D9C0),
            ),
            scaffoldBackgroundColor: const Color(0xFFF8F9FE),
            textTheme: GoogleFonts.outfitTextTheme(),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              backgroundColor: Colors.transparent,
              centerTitle: false,
              titleTextStyle: TextStyle(
                color: Colors.black87, 
                fontSize: 22, 
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
                letterSpacing: -0.3,
              ),
              iconTheme: IconThemeData(color: Colors.black87, size: 24),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              color: Colors.white,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF0F1F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            chipTheme: ChipThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              elevation: 4,
              highlightElevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6C63FF),
              brightness: Brightness.dark,
              primary: const Color(0xFF8B83FF),
              secondary: const Color(0xFFFF6584),
              tertiary: const Color(0xFF00D9C0),
              surface: const Color(0xFF1E1E2E),
              surfaceContainerHighest: const Color(0xFF2A2A3E),
            ),
            scaffoldBackgroundColor: const Color(0xFF121218),
            cardColor: const Color(0xFF1E1E2E),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              backgroundColor: Colors.transparent,
              centerTitle: false,
              titleTextStyle: TextStyle(
                color: Colors.white, 
                fontSize: 22, 
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
                letterSpacing: -0.3,
              ),
              iconTheme: IconThemeData(color: Colors.white, size: 24),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              color: const Color(0xFF1E1E2E),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF2A2A3E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF8B83FF), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            chipTheme: ChipThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              elevation: 4,
              highlightElevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          home: FirebaseAuth.instance.currentUser == null 
              ? const LoginScreen() 
              : const TaskListScreen(),
        ),
      );
      }
    );
  }
}
