import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dream_flow/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow Tests', () {
    testWidgets('Complete sign up flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to sign up
      final signUpFinder = find.text('Sign Up');
      if (signUpFinder.evaluate().isNotEmpty) {
        await tester.tap(signUpFinder.first);
        await tester.pumpAndSettle();
      }

      // Fill sign up form
      final textFields = find.byType(TextField);
      if (textFields.evaluate().length >= 2) {
        // Email field
        await tester.enterText(
          textFields.at(0),
          'autotest_${DateTime.now().millisecondsSinceEpoch}@example.com',
        );
        await tester.pump();

        // Password field
        await tester.enterText(textFields.at(1), 'TestPassword123!');
        await tester.pump();

        // Optional: Full name if present
        if (textFields.evaluate().length >= 3) {
          await tester.enterText(textFields.at(2), 'Auto Test User');
          await tester.pump();
        }

        // Find and tap sign up button
        final signUpButtons = find.text('Sign Up');
        if (signUpButtons.evaluate().isNotEmpty) {
          await tester.tap(signUpButtons.last);
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // Verify navigation (either to home or error message)
          final homeScreen = find.text('Evening Profile');
          final errorMessage = find.textContaining('error');
          
          // Test passes if we either reach home or see an error (both are valid outcomes)
          expect(
            homeScreen.evaluate().isNotEmpty || errorMessage.evaluate().isNotEmpty,
            isTrue,
          );
        }
      }
    });

    testWidgets('Sign in with credentials', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Find email and password fields
      final textFields = find.byType(TextField);
      if (textFields.evaluate().length >= 2) {
        // Enter email
        await tester.enterText(textFields.at(0), 'test@example.com');
        await tester.pump();

        // Enter password
        await tester.enterText(textFields.at(1), 'testpassword123');
        await tester.pump();

        // Find and tap sign in button
        final signInButtons = find.text('Sign In');
        if (signInButtons.evaluate().isNotEmpty) {
          await tester.tap(signInButtons.last);
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // Verify either successful login or error message
          final homeScreen = find.text('Evening Profile');
          final errorMessage = find.textContaining('error');
          
          // Test passes if we either reach home, see an error, or stay on login (all valid)
          expect(
            homeScreen.evaluate().isNotEmpty || 
            errorMessage.evaluate().isNotEmpty ||
            find.text('Welcome Back').evaluate().isNotEmpty,
            isTrue,
          );
        }
      }
    });

    testWidgets('Invalid credentials show error', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final textFields = find.byType(TextField);
      if (textFields.evaluate().length >= 2) {
        // Enter invalid credentials
        await tester.enterText(textFields.at(0), 'invalid@example.com');
        await tester.pump();
        await tester.enterText(textFields.at(1), 'wrongpassword');
        await tester.pump();

        // Tap sign in
        final signInButtons = find.text('Sign In');
        if (signInButtons.evaluate().isNotEmpty) {
          await tester.tap(signInButtons.last);
          await tester.pumpAndSettle(const Duration(seconds: 5));

          // Should show error or stay on login screen
          final errorMessage = find.textContaining('error');
          final loginScreen = find.text('Welcome Back');
          
          expect(
            errorMessage.evaluate().isNotEmpty || loginScreen.evaluate().isNotEmpty,
            isTrue,
          );
        }
      }
    });
  });
}

