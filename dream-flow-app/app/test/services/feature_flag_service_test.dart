import 'package:dream_flow/services/feature_flag_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final service = FeatureFlagService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service.debugReset();
  });

  group('FeatureFlagService', () {
    test('defaults to true when no overrides exist', () async {
      expect(await service.isEnabled(FeatureFlag.maestro), isTrue);
    });

    test('overrides persist in SharedPreferences', () async {
      await service.setOverride(FeatureFlag.smartScenes, false);

      expect(await service.isEnabled(FeatureFlag.smartScenes), isFalse);

      await service.clearOverride(FeatureFlag.smartScenes);
      expect(await service.isEnabled(FeatureFlag.smartScenes), isTrue);
    });

    test('environment flags can be overridden for tests', () async {
      service.debugOverrideEnvFlags({'maestro_enabled': false});

      expect(await service.isEnabled(FeatureFlag.maestro), isFalse);

      // Local override takes precedence over env override.
      await service.setOverride(FeatureFlag.maestro, true);
      expect(await service.isEnabled(FeatureFlag.maestro), isTrue);
    });

    test('getOverrides returns copy of persisted flags', () async {
      await service.setOverride(FeatureFlag.moodboard, false);

      final overrides = await service.getOverrides();
      expect(overrides, containsPair('moodboard_beta', false));

      overrides['moodboard_beta'] = true;
      final reloaded = await service.getOverrides();
      expect(reloaded['moodboard_beta'], isFalse);
    });
  });
}


