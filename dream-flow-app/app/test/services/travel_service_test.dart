import 'package:dream_flow/services/travel_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late TravelService service;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = TravelService();
  });

  group('TravelService', () {
    test('getStatus returns active and next trips when present', () async {
      final now = DateTime.now();
      final itineraries = [
        TravelItinerary(
          id: 'future',
          location: 'Tokyo',
          locationType: 'vacation',
          start: now.add(const Duration(days: 10)),
          end: now.add(const Duration(days: 14)),
          timezoneOffsetMinutes: 540,
        ),
        TravelItinerary(
          id: 'active',
          location: 'Paris',
          locationType: 'trip',
          start: now.subtract(const Duration(days: 1)),
          end: now.add(const Duration(days: 1)),
          timezoneOffsetMinutes: 60,
        ),
      ];
      for (final itinerary in itineraries) {
        await service.upsertItinerary(itinerary);
      }

      final status = await service.getStatus();

      expect(status.activeTrip?.id, 'active');
      expect(status.nextTrip?.id, 'future');
      expect(status.isTravelMode, isTrue);
    });

    test('timezone delta is tracked when offset changes', () async {
      await prefs.setInt('travel_last_timezone_offset', 0);
      final status = await service.getStatus();

      final expectedDelta = DateTime.now().timeZoneOffset.inMinutes;
      expect(status.timezoneDeltaMinutes, expectedDelta);
    });

    test('setOfflineAssetsReady persists counter', () async {
      await service.setOfflineAssetsReady(5);

      final status = await service.getStatus();
      expect(status.offlineAssetCount, 5);
    });
  });
}


