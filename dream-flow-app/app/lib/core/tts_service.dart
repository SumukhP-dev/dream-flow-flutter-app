import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_tts/flutter_tts.dart';

/// Native Text-to-Speech service
/// Uses native TTS APIs (no model download required)
/// - iOS: AVSpeechSynthesizer
/// - Android: Android TTS API
class TTSService {
  TTSService._();
  static TTSService? _instance;
  static TTSService get instance => _instance ??= TTSService._();

  bool _initialized = false;
  FlutterTts? _ttsEngine;

  /// Initialize TTS service
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('TTS service already initialized');
      return;
    }

    try {
      if (Platform.isAndroid) {
        await _initializeAndroid();
      } else if (Platform.isIOS) {
        await _initializeIOS();
      } else {
        throw UnsupportedError('Platform not supported');
      }

      _initialized = true;
      debugPrint('TTS service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize TTS service: $e');
      rethrow;
    }
  }

  /// Initialize Android TTS
  Future<void> _initializeAndroid() async {
    try {
      final FlutterTts flutterTts = FlutterTts();
      
      // Set default language and parameters
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.5); // Slower for bedtime stories
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);
      
      // Enable platform-specific features
      if (Platform.isAndroid) {
        await flutterTts.awaitSpeakCompletion(true);
        // Set Android-specific settings
        await flutterTts.setSilence(0);
      }
      
      _ttsEngine = flutterTts;
      debugPrint('Android TTS initialized successfully');
    } catch (e) {
      throw Exception('Failed to initialize Android TTS: $e');
    }
  }

  /// Initialize iOS TTS
  Future<void> _initializeIOS() async {
    try {
      final FlutterTts flutterTts = FlutterTts();
      
      // Set default language and parameters
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.5); // Slower for bedtime stories
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);
      
      // Enable iOS-specific features
      if (Platform.isIOS) {
        await flutterTts.awaitSpeakCompletion(true);
        // iOS uses AVSpeechSynthesizer which is handled by flutter_tts
      }
      
      _ttsEngine = flutterTts;
      debugPrint('iOS TTS initialized successfully');
    } catch (e) {
      throw Exception('Failed to initialize iOS TTS: $e');
    }
  }

  /// Generate audio file from text
  /// Returns audio bytes (WAV or MP3 format)
  Future<Uint8List> synthesizeToFile({
    required String text,
    String language = 'en-US',
    String? voice,
    double speechRate = 0.5, // Slower for bedtime stories
    double volume = 1.0,
    double pitch = 1.0,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Generate temporary file path
      final tempDir = await getTemporaryDirectory();
      final audioFile = File(path.join(tempDir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.wav'));

      if (Platform.isAndroid) {
        await _synthesizeAndroid(text, audioFile, language, voice, speechRate, volume, pitch);
      } else if (Platform.isIOS) {
        await _synthesizeIOS(text, audioFile, language, voice, speechRate, volume, pitch);
      } else {
        throw UnsupportedError('Platform not supported');
      }

      // Read audio file bytes
      if (await audioFile.exists()) {
        final bytes = await audioFile.readAsBytes();
        // Clean up temp file
        await audioFile.delete();
        return bytes;
      }

      throw Exception('Audio file was not created');
    } catch (e) {
      debugPrint('TTS synthesis failed: $e');
      rethrow;
    }
  }

  /// Synthesize audio on Android
  Future<void> _synthesizeAndroid(
    String text,
    File outputFile,
    String language,
    String? voice,
    double speechRate,
    double volume,
    double pitch,
  ) async {
    final flutterTts = _ttsEngine;
    if (flutterTts == null) {
      throw Exception('TTS engine not initialized');
    }
    
    try {
      await flutterTts.setLanguage(language);
      if (voice != null) {
        await flutterTts.setVoice({"name": voice, "locale": language});
      }
      await flutterTts.setSpeechRate(speechRate);
      await flutterTts.setVolume(volume);
      await flutterTts.setPitch(pitch);
      
      // Synthesize to file
      final result = await flutterTts.synthesizeToFile(
        text,
        outputFile.path,
      );
      
      if (result != 1) {
        throw Exception('TTS synthesis failed with result code: $result');
      }
      
      // Verify file was created
      if (!await outputFile.exists()) {
        throw Exception('TTS output file was not created');
      }
      
      debugPrint('Android TTS synthesis completed: ${outputFile.path}');
    } catch (e) {
      debugPrint('Android TTS synthesis error: $e');
      rethrow;
    }
  }

  /// Synthesize audio on iOS
  Future<void> _synthesizeIOS(
    String text,
    File outputFile,
    String language,
    String? voice,
    double speechRate,
    double volume,
    double pitch,
  ) async {
    final flutterTts = _ttsEngine;
    if (flutterTts == null) {
      throw Exception('TTS engine not initialized');
    }
    
    try {
      await flutterTts.setLanguage(language);
      if (voice != null) {
        await flutterTts.setVoice({"name": voice, "locale": language});
      }
      await flutterTts.setSpeechRate(speechRate);
      await flutterTts.setVolume(volume);
      await flutterTts.setPitch(pitch);
      
      // Synthesize to file
      final result = await flutterTts.synthesizeToFile(
        text,
        outputFile.path,
      );
      
      if (result != 1) {
        throw Exception('TTS synthesis failed with result code: $result');
      }
      
      // Verify file was created
      if (!await outputFile.exists()) {
        throw Exception('TTS output file was not created');
      }
      
      debugPrint('iOS TTS synthesis completed: ${outputFile.path}');
    } catch (e) {
      debugPrint('iOS TTS synthesis error: $e');
      rethrow;
    }
  }

  /// Speak text directly (without saving to file)
  Future<void> speak(String text, {String language = 'en-US'}) async {
    if (!_initialized) {
      await initialize();
    }

    final flutterTts = _ttsEngine;
    if (flutterTts == null) {
      throw Exception('TTS engine not initialized');
    }

    try {
      await flutterTts.setLanguage(language);
      await flutterTts.speak(text);
      debugPrint('TTS speaking: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
    } catch (e) {
      debugPrint('TTS speak failed: $e');
      rethrow;
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    if (!_initialized) return;

    final flutterTts = _ttsEngine;
    if (flutterTts == null) return;

    try {
      await flutterTts.stop();
      debugPrint('TTS stopped');
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
  }

  /// Check if TTS is available
  bool get isAvailable => Platform.isIOS || Platform.isAndroid;

  /// Check if service is initialized
  bool get isInitialized => _initialized;
}

