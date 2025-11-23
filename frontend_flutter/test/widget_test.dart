// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dream_flow/screens/login_screen.dart';

void main() {
  testWidgets('Login screen displays correctly', (WidgetTester tester) async {
    // Build the login screen widget and trigger a frame.
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    // Verify that the login screen displays the welcome text.
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign in to continue your dream journey'), findsOneWidget);

    // Verify that email and password fields are present.
    expect(find.byType(TextField), findsWidgets);
    
    // Verify that Sign In button is present.
    expect(find.text('Sign In'), findsOneWidget);
    
    // Verify that Sign Up link is present.
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets('Login screen form fields are interactive', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    // Find email field and enter text.
    final emailFields = find.byType(TextField);
    expect(emailFields, findsWidgets);
    
    await tester.enterText(emailFields.at(0), 'test@example.com');
    await tester.pump();
    
    // Verify text was entered.
    expect(find.text('test@example.com'), findsOneWidget);
  });
}
