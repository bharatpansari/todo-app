import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talkative_todo/ui/widgets/quick_add_sheet.dart';


void main() {
  testWidgets('QuickAddSheet UI Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickAddSheet(
            onTaskAdded: () {}, // Mock callback
          ),
        ),
      ),
    );

    // Verify Title field exists
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('I want to...'), findsOneWidget); // Hint text

    // Enter text
    await tester.enterText(find.byType(TextField).first, 'Test Task');
    expect(find.text('Test Task'), findsOneWidget);

    // Verify Submit button exists
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    
    // Note: Actually submitting would require mocking TaskRepository which is initialized inside
    // For a basic widget test, verifying UI elements is sufficient to ensure no render crashes.
  });
}
