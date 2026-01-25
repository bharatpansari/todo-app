import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:talkative_todo/main.dart';
import 'package:talkative_todo/repositories/settings_repository.dart';
import 'package:talkative_todo/repositories/category_repository.dart';
import 'package:talkative_todo/models/task_model.dart';
import 'package:talkative_todo/models/category_model.dart';
import 'dart:io';

void main() {
  setUpAll(() async {
    // Setup Hive for testing
    final tempDir = await Directory.systemTemp.createTemp('widget_test_hive');
    Hive.init(tempDir.path);
    
    // Register Adapters
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(CategoryAdapter());
  });

  testWidgets('App launches and shows task list screen', (WidgetTester tester) async {
    // Initialize repositories
    await SettingsRepository().init();
    await CategoryRepository().initializeDefaultCategories();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(); // Wait for any animations or async data loading

    // Verify that the app bar title is present
    expect(find.text('My Daily Tasks'), findsOneWidget);
    
    // Verify that the New Task FAB is generally present (by icon or tooltip, or text if label is shown)
    // The FAB has label "New Task"
    expect(find.text('New Task'), findsOneWidget);
  });
}
