import 'package:dream_flow/screens/calm_quests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Calm quests screen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('user can progress and claim a quest reward', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CalmQuestsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Calm quests'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsWidgets);

      // Complete all steps for the first quest.
      final checkboxes = find.byType(CheckboxListTile);
      for (var i = 0; i < 3; i++) {
        await tester.tap(checkboxes.at(i));
        await tester.pumpAndSettle();
      }

      final claimButton = find.text('Claim reward');
      expect(claimButton, findsOneWidget);

      await tester.tap(claimButton);
      await tester.pumpAndSettle();

      expect(find.text('Claimed'), findsWidgets);
    });
  });
}


