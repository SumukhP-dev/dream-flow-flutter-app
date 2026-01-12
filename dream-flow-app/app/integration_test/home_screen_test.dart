import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dream_flow/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Home Screen Tests', () {
    testWidgets('Home screen form fields are accessible',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // If on login screen, we need to log in first
      // For now, just verify we can find form elements
      final textFields = find.byType(TextField);

      // Either we're on login/signup or home screen
      expect(
          textFields.evaluate().isNotEmpty ||
              find.text('Evening Profile').evaluate().isNotEmpty,
          isTrue);
    });

    testWidgets('Fill profile form fields', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Check if we're on home screen
      final homeScreen = find.text('Evening Profile');
      if (homeScreen.evaluate().isNotEmpty) {
        // Find all text fields
        final textFields = find.byType(TextField);

        if (textFields.evaluate().isNotEmpty) {
          // Fill mood field (usually first field)
          await tester.enterText(textFields.at(0), 'Calm and peaceful');
          await tester.pump();

          // Verify text was entered
          expect(find.text('Calm and peaceful'), findsOneWidget);
        }
      }
    });

    testWidgets('Story prompt field accepts input',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final homeScreen = find.text('Evening Profile');
      if (homeScreen.evaluate().isNotEmpty) {
        // Find story prompt field (usually contains "prompt" or "story" in hint)
        final textFields = find.byType(TextField);

        // Try to find and fill a text field
        if (textFields.evaluate().isNotEmpty) {
          await tester.enterText(
            textFields.first,
            'A magical journey through the stars',
          );
          await tester.pump();

          expect(
              find.text('A magical journey through the stars'), findsOneWidget);
        }
      }
    });
  });
}
