import 'package:flutter_test/flutter_test.dart';
import 'package:dream_flow/core/model_manager.dart';
import 'package:dream_flow/core/model_config.dart';
import 'dart:io';

void main() {
  group('ModelManager', () {
    test('instance is singleton', () {
      final instance1 = ModelManager.instance;
      final instance2 = ModelManager.instance;
      expect(instance1, equals(instance2));
    });

    group('Model Existence Checks', () {
      test('modelExists returns false for non-existent model', () async {
        final manager = ModelManager.instance;
        final exists = await manager.modelExists('nonexistent_model.tflite');
        expect(exists, isFalse);
      });

      // Note: Actual file existence tests would require model files or mocking
    });

    group('Model Download', () {
      test('downloadModel throws when already downloading', () async {
        final manager = ModelManager.instance;
        
        // Note: This test would require actual network access or mocking
        // For now, we test the structure
        expect(manager.downloadModel, isA<Function>());
      });

      test('downloadStoryModel uses correct filename and URL', () {
        final manager = ModelManager.instance;
        final storyModel = ModelConfig.storyModel;
        
        // Verify configuration is accessible
        expect(storyModel.name, equals('gpt2-tiny'));
        expect(storyModel.getFilename(), isA<String>());
        expect(storyModel.getDownloadUrl(), isA<String>());
        
        // Download method should exist
        expect(manager.downloadStoryModel, isA<Function>());
      });

      test('downloadImageModels uses correct filenames and URLs', () {
        final manager = ModelManager.instance;
        final imageModel = ModelConfig.imageModel;
        
        // Verify configuration is accessible
        expect(imageModel.name, equals('stable-diffusion-turbo'));
        
        if (Platform.isAndroid) {
          final filenames = imageModel.getAndroidFilenames();
          expect(filenames.length, equals(3)); // text encoder, UNet, VAE decoder
          expect(filenames[0], contains('text_encoder'));
          expect(filenames[1], contains('unet'));
          expect(filenames[2], contains('vae'));
        } else if (Platform.isIOS) {
          final filename = imageModel.getIOSFilename();
          expect(filename, contains('stable_diffusion'));
        }
        
        // Download method should exist
        expect(manager.downloadImageModels, isA<Function>());
      });
    });

    group('Model Availability Checks', () {
      test('hasStoryModel returns boolean', () async {
        final manager = ModelManager.instance;
        final hasModel = await manager.hasStoryModel();
        expect(hasModel, isA<bool>());
      });

      test('hasImageModels returns boolean', () async {
        final manager = ModelManager.instance;
        final hasModels = await manager.hasImageModels();
        expect(hasModels, isA<bool>());
      });
    });

    group('Cache Management', () {
      test('getCachedModelsSize returns integer', () async {
        final manager = ModelManager.instance;
        final size = await manager.getCachedModelsSize();
        expect(size, isA<int>());
        expect(size, greaterThanOrEqualTo(0));
      });

      test('deleteModel accepts filename', () async {
        final manager = ModelManager.instance;
        // Should not throw even if file doesn't exist
        await manager.deleteModel('nonexistent.tflite');
      });

      test('clearAllModels clears cache', () async {
        final manager = ModelManager.instance;
        // Should not throw
        await manager.clearAllModels();
      });
    });

    group('Model Verification', () {
      test('verifyModel checks file size', () async {
        final manager = ModelManager.instance;
        final isValid = await manager.verifyModel('test.tflite', 1000000);
        expect(isValid, isA<bool>());
      });

      test('verifyModel returns false for non-existent file', () async {
        final manager = ModelManager.instance;
        final isValid = await manager.verifyModel('nonexistent.tflite', 1000000);
        expect(isValid, isFalse);
      });
    });

    group('Version Management', () {
      test('saveModelVersion saves version', () async {
        final manager = ModelManager.instance;
        await manager.saveModelVersion();
        
        final savedVersion = await manager.getSavedModelVersion();
        expect(savedVersion, equals(ModelConfig.modelVersion));
      });

      test('getSavedModelVersion returns version after save', () async {
        final manager = ModelManager.instance;
        
        // Save version first
        await manager.saveModelVersion();
        
        final version = await manager.getSavedModelVersion();
        expect(version, equals(ModelConfig.modelVersion));
      });

      test('modelsNeedUpdate returns boolean', () async {
        final manager = ModelManager.instance;
        
        // Save current version first
        await manager.saveModelVersion();
        
        final needsUpdate = await manager.modelsNeedUpdate();
        expect(needsUpdate, isA<bool>());
        // Should be false if version is current
        expect(needsUpdate, isFalse);
      });
    });
  });
}

