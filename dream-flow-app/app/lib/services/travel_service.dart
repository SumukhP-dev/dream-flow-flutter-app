import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TravelService {
  static const _itineraryKey = 'travel_itineraries';
  static const _offlineAssetsKey = 'travel_offline_assets';
  static const _lastTimezoneKey = 'travel_last_timezone_offset';

  Future<TravelStatus> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final itineraries = await _loadItineraries(prefs);
    final offlineAssets = prefs.getInt(_offlineAssetsKey) ?? 0;
    final now = DateTime.now();
    final timezoneOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    final lastOffset = prefs.getInt(_lastTimezoneKey) ?? timezoneOffsetMinutes;
    if (lastOffset != timezoneOffsetMinutes) {
      await prefs.setInt(_lastTimezoneKey, timezoneOffsetMinutes);
    }

    TravelItinerary? active;
    TravelItinerary? nextTrip;

    for (final itinerary in itineraries) {
      if (itinerary.isActive(now)) {
        active = itinerary;
        break;
      } else if (itinerary.startsInFuture(now)) {
        nextTrip ??= itinerary;
        if (itinerary.start.isBefore(nextTrip.start)) {
          nextTrip = itinerary;
        }
      }
    }

    return TravelStatus(
      activeTrip: active,
      nextTrip: nextTrip,
      offlineAssetCount: offlineAssets,
      timezoneDeltaMinutes: timezoneOffsetMinutes - lastOffset,
    );
  }

  Future<void> upsertItinerary(TravelItinerary itinerary) async {
    final prefs = await SharedPreferences.getInstance();
    final itineraries = await _loadItineraries(prefs);
    itineraries.removeWhere((item) => item.id == itinerary.id);
    itineraries.add(itinerary);
    await prefs.setString(
      _itineraryKey,
      jsonEncode(itineraries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> setOfflineAssetsReady(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_offlineAssetsKey, count);
  }

  Future<List<TravelItinerary>> _loadItineraries(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_itineraryKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (item) => TravelItinerary.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class TravelStatus {
  TravelStatus({
    required this.activeTrip,
    required this.nextTrip,
    required this.offlineAssetCount,
    required this.timezoneDeltaMinutes,
  });

  final TravelItinerary? activeTrip;
  final TravelItinerary? nextTrip;
  final int offlineAssetCount;
  final int timezoneDeltaMinutes;

  bool get isTravelMode => activeTrip != null;
  bool get needsTimezoneAssist => timezoneDeltaMinutes.abs() >= 120;
}

class TravelItinerary {
  TravelItinerary({
    required this.id,
    required this.location,
    required this.locationType,
    required this.start,
    required this.end,
    required this.timezoneOffsetMinutes,
  });

  final String id;
  final String location;
  final String locationType;
  final DateTime start;
  final DateTime end;
  final int timezoneOffsetMinutes;

  bool isActive(DateTime reference) {
    return !reference.isBefore(start) && !reference.isAfter(end);
  }

  bool startsInFuture(DateTime reference) {
    return reference.isBefore(start);
  }

  factory TravelItinerary.fromJson(Map<String, dynamic> json) {
    return TravelItinerary(
      id: json['id'] as String,
      location: json['location'] as String? ?? 'Getaway',
      locationType: json['location_type'] as String? ?? 'trip',
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      timezoneOffsetMinutes: json['timezone_offset'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'location': location,
        'location_type': locationType,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'timezone_offset': timezoneOffsetMinutes,
      };
}

