import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dream_flow/screens/signup_screen.dart';
import 'package:dream_flow/screens/terms_and_conditions_screen.dart';
import 'package:dream_flow/screens/privacy_policy_screen.dart';

void main() {
  group('SignupScreen Links Test', () {
    testWidgets('Terms and Conditions link navigates to correct screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SignUpScreen(),
        ),
      );

      // Scroll to make the terms section visible
      await tester.ensureVisible(find.text('Terms and Conditions'));
      await tester.pumpAndSettle();

      // Find the Terms and Conditions link
      final termsLink = find.text('Terms and Conditions');
      expect(termsLink, findsOneWidget);

      // Tap the link
      await tester.tap(termsLink);
      await tester.pumpAndSettle();

      // Verify navigation to Terms and Conditions screen
      expect(find.byType(TermsAndConditionsScreen), findsOneWidget);
    });

    testWidgets('Privacy Policy link navigates to correct screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SignUpScreen(),
        ),
      );

      // Scroll to make the terms section visible
      await tester.ensureVisible(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      // Find the Privacy Policy link
      final privacyLink = find.text('Privacy Policy');
      expect(privacyLink, findsOneWidget);

      // Tap the link
      await tester.tap(privacyLink);
      await tester.pumpAndSettle();

      // Verify navigation to Privacy Policy screen
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    });

    testWidgets('Checkbox toggles correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      // Scroll to make the checkbox visible
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Find the checkbox
      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);

      // Initially unchecked
      Checkbox checkboxWidget = tester.widget<Checkbox>(checkbox);
      expect(checkboxWidget.value, false);

      // Tap to check
      await tester.tap(checkbox);
      await tester.pump();

      // Should be checked
      checkboxWidget = tester.widget<Checkbox>(checkbox);
      expect(checkboxWidget.value, true);

      // Tap again to uncheck
      await tester.tap(checkbox);
      await tester.pump();

      // Should be unchecked
      checkboxWidget = tester.widget<Checkbox>(checkbox);
      expect(checkboxWidget.value, false);
    });
  });
}