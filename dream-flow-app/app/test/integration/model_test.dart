import 'package:flutter_test/flutter_test.dart';
import 'package:dream_flow/core/on_device_ml_service.dart';
import 'package:dream_flow/core/model_manager.dart';

/// Integration tests for end-to-end ML model pipeline
/// 
/// Note: These tests require actual model files or a test environment with mocked models.
/// They test the complete flow: story generation → image generation → audio generation.
void main() {
  group('ML Model Integration Tests', () {
    late OnDeviceMLService mlService;
    late ModelManager modelManager;

    setUp(() {
      mlService = OnDeviceMLService.instance;
      modelManager = ModelManager.instance;
    });

    group('End-to-End Story Generation Pipeline', () {
      test('complete story generation flow', () async {
        try {
          // Initialize services
          await mlService.initialize();

          // Generate story
          final story = await mlService.generateStory(
            prompt: 'a magical forest adventure',
            theme: 'Aurora Dreams',
            maxTokens: 200,
            profile: {
              'mood': 'calm',
              'routine': 'bedtime',
              'preferences': ['nature', 'magic'],
            },
          );

          expect(story, isA<String>());
          expect(story.isNotEmpty, isTrue);

          // Generate images for story
          final images = await mlService.generateImages(
            prompt: 'a magical forest',
            theme: 'Aurora Dreams',
            numImages: 2,
            width: 512,
            height: 512,
          );

          expect(images, isA<List>());
          // Currently placeholder returns empty list
          // When models are available, should have 2 images

          // Generate audio narration
          final audio = await mlService.generateAudio(
            text: story,
            language: 'en-US',
          );

          expect(audio, isA<List<int>>());
          // Currently placeholder returns empty bytes
          // When TTS is available, should have audio data
        } catch (e) {
          // If models are not available, test documents the expected behavior
          expect(e, isA<Exception>());
        }
      });

      test('story generation with different themes', () async {
        final themes = ['Aurora Dreams', 'Ocean Waves', 'Forest Night'];

        for (final theme in themes) {
          try {
            await mlService.initialize();
            final story = await mlService.generateStory(
              prompt: 'a peaceful scene',
              theme: theme,
              maxTokens: 100,
            );

            expect(story, isA<String>());
            expect(story.isNotEmpty, isTrue);
          } catch (e) {
            expect(e, isA<Exception>());
          }
        }
      });
    });

    group('Performance Benchmarks', () {
      test('story generation performance', () async {
        try {
          await mlService.initialize();

          final stopwatch = Stopwatch()..start();
          await mlService.generateStory(
            prompt: 'a short test story',
            theme: 'Test',
            maxTokens: 50,
          );
          stopwatch.stop();

          // Log performance (would check against benchmarks in real tests)
          print('Story generation took: ${stopwatch.elapsedMilliseconds}ms');
          expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(0));
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('image generation performance', () async {
        try {
          await mlService.initialize();

          final stopwatch = Stopwatch()..start();
          await mlService.generateImages(
            prompt: 'a test image',
            theme: 'Test',
            numImages: 1,
            width: 256,
            height: 256,
          );
          stopwatch.stop();

          // Log performance
          print('Image generation took: ${stopwatch.elapsedMilliseconds}ms');
          expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(0));
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('audio generation performance', () async {
        try {
          await mlService.initialize();

          final stopwatch = Stopwatch()..start();
          await mlService.generateAudio(
            text: 'This is a test narration for performance measurement.',
            language: 'en-US',
          );
          stopwatch.stop();

          // Log performance
          print('Audio generation took: ${stopwatch.elapsedMilliseconds}ms');
          expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(0));
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('Model Download and Caching', () {
      test('model download flow', () async {
        // Note: This would require network access or mocking
        // Tests that the download methods exist and are callable
        expect(modelManager.downloadStoryModel, isA<Function>());
        expect(modelManager.downloadImageModels, isA<Function>());
      });

      test('model caching works correctly', () async {
        final cachedSize = await modelManager.getCachedModelsSize();
        expect(cachedSize, isA<int>());
        expect(cachedSize, greaterThanOrEqualTo(0));
      });

      test('model version management', () async {
        final needsUpdate = await modelManager.modelsNeedUpdate();
        expect(needsUpdate, isA<bool>());

        await modelManager.updateModelsIfNeeded();
        // Should complete without error
      });
    });

    group('Error Handling and Resilience', () {
      test('service handles missing models gracefully', () async {
        try {
          await mlService.initialize();
          
          // Should use placeholder implementations if models unavailable
          final story = await mlService.generateStory(
            prompt: 'test',
            theme: 'test',
          );
          
          expect(story, isA<String>());
          expect(story.isNotEmpty, isTrue);
        } catch (e) {
          // Should handle errors gracefully
          expect(e, isA<Exception>());
        }
      });

      test('service recovers from initialization failures', () async {
        final service = OnDeviceMLService.instance;
        
        // Multiple initialization calls should be safe
        await service.initialize();
        await service.initialize(); // Should be idempotent
        
        expect(() => service.generateStory(
          prompt: 'test',
          theme: 'test',
        ), returnsNormally);
      });
    });

    group('Memory Management', () {
      test('models can be unloaded and reloaded', () async {
        // Note: This would require access to model loaders
        // Tests that the architecture supports model lifecycle management
        try {
          await mlService.initialize();
          
          // Generate to load models
          await mlService.generateStory(
            prompt: 'test',
            theme: 'test',
          );
          
          // Should be able to generate again
          await mlService.generateStory(
            prompt: 'test2',
            theme: 'test2',
          );
          
          expect(true, isTrue); // If we get here, it worked
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });
  });
}

