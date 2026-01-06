import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/task_model.dart';
import 'ui/task_list_screen.dart';

import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter()); // We will need to generate this
  
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
    return MaterialApp(
      title: 'Talkative Todo',
      debugShowCheckedModeBanner: false,
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
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit'
          ),
          iconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      home: const TaskListScreen(),
    );
  }
}
