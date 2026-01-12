import 'package:flutter_test/flutter_test.dart';
import 'package:dream_flow/core/hardware_detector.dart';

void main() {
  group('HardwareDetector', () {
    test('detectHardware returns environment variables map', () async {
      final detector = HardwareDetector.instance;
      final envVars = await detector.detectHardware();
      
      // Should return a map with hardware detection results
      expect(envVars, isA<Map<String, String>>());
      expect(envVars.containsKey('MOBILE_PLATFORM'), isTrue);
    });
    
    test('getHardwareInfo returns hardware info map', () {
      final detector = HardwareDetector.instance;
      final info = detector.getHardwareInfo();
      
      expect(info, isA<Map<String, dynamic>>());
      expect(info.containsKey('platform'), isTrue);
    });
  });
}

