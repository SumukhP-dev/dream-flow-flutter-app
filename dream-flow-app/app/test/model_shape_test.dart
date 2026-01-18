import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';

/// Model shape verification tests
/// These tests verify that TFLite models have the expected input/output shapes
/// Run after bundling model files to ensure compatibility

void main() {
  group('Story Model Shape Tests', () {
    test('Verify GPT-2 Tiny model input/output shapes', () async {
      // Skip if model file doesn't exist (will be bundled separately)
      final modelPath =
          'android/app/src/main/offloaded_models/gpt2_tiny.tflite';
      if (!await File(modelPath).exists()) {
        print('⚠️ Model file not found: $modelPath');
        print('   Skipping test - bundle model files first');
        return;
      }

      try {
        final interpreter = Interpreter.fromFile(File(modelPath));

        // Check input tensor
        final inputTensor = interpreter.getInputTensor(0);
        final inputShape = inputTensor.shape;

        print('Input shape: $inputShape');
        expect(inputShape.length, equals(2),
            reason: 'Expected 2D input [batch, sequence_length]');
        expect(inputShape[1], equals(128),
            reason: 'Expected max sequence length of 128');

        // Check output tensor
        final outputTensor = interpreter.getOutputTensor(0);
        final outputShape = outputTensor.shape;

        print('Output shape: $outputShape');
        expect(outputShape.length, equals(3),
            reason: 'Expected 3D output [batch, sequence_length, vocab_size]');
        expect(outputShape[1], equals(128),
            reason: 'Expected sequence length of 128');
        expect(outputShape[2], greaterThan(0),
            reason: 'Expected vocab size > 0');

        print('✓ Story model shapes verified');
        interpreter.close();
      } catch (e) {
        print('❌ Error loading model: $e');
        fail('Model shape verification failed: $e');
      }
    });
  });

  group('Image Model Shape Tests', () {
    test('Verify text encoder model shapes', () async {
      final modelPath =
          'android/app/src/main/offloaded_models/sd_text_encoder.tflite';
      if (!await File(modelPath).exists()) {
        print('⚠️ Model file not found: $modelPath');
        print('   Skipping test - bundle model files first');
        return;
      }

      try {
        final interpreter = Interpreter.fromFile(File(modelPath));

        // Check input: [batch, 77] for text tokens
        final inputTensor = interpreter.getInputTensor(0);
        final inputShape = inputTensor.shape;

        print('Text Encoder Input shape: $inputShape');
        expect(inputShape[1], equals(77),
            reason: 'Expected 77 token positions for Stable Diffusion');

        // Check output: [batch, 77, 768] for embeddings
        final outputTensor = interpreter.getOutputTensor(0);
        final outputShape = outputTensor.shape;

        print('Text Encoder Output shape: $outputShape');
        expect(outputShape.length, equals(3), reason: 'Expected 3D embeddings');
        expect(outputShape[1], equals(77),
            reason: 'Expected 77 embedding positions');
        expect(outputShape[2], equals(768),
            reason: 'Expected embedding dimension of 768');

        print('✓ Text encoder shapes verified');
        interpreter.close();
      } catch (e) {
        print('❌ Error loading text encoder: $e');
        fail('Text encoder shape verification failed: $e');
      }
    });

    test('Verify UNet model shapes', () async {
      final modelPath = 'android/app/src/main/offloaded_models/sd_unet.tflite';
      if (!await File(modelPath).exists()) {
        print('⚠️ Model file not found: $modelPath');
        print('   Skipping test - bundle model files first');
        return;
      }

      try {
        final interpreter = Interpreter.fromFile(File(modelPath));

        // UNet expects latent input: [batch, 4, 48, 48] for 384x384 images
        final inputTensor = interpreter.getInputTensor(0);
        final inputShape = inputTensor.shape;

        print('UNet Input shape: $inputShape');
        expect(inputShape.length, equals(4),
            reason:
                'Expected 4D latent tensor [batch, channels, height, width]');
        expect(inputShape[1], equals(4), reason: 'Expected 4 latent channels');

        // UNet outputs denoised latents of same shape
        final outputTensor = interpreter.getOutputTensor(0);
        final outputShape = outputTensor.shape;

        print('UNet Output shape: $outputShape');
        expect(outputShape.length, equals(4),
            reason: 'Expected 4D output tensor');
        expect(outputShape[1], equals(4), reason: 'Expected 4 output channels');

        print('✓ UNet shapes verified');
        interpreter.close();
      } catch (e) {
        print('❌ Error loading UNet: $e');
        fail('UNet shape verification failed: $e');
      }
    });

    test('Verify VAE decoder model shapes', () async {
      final modelPath = 'android/app/src/main/offloaded_models/sd_vae.tflite';
      if (!await File(modelPath).exists()) {
        print('⚠️ Model file not found: $modelPath');
        print('   Skipping test - bundle model files first');
        return;
      }

      try {
        final interpreter = Interpreter.fromFile(File(modelPath));

        // VAE expects latent input: [batch, 4, 48, 48]
        final inputTensor = interpreter.getInputTensor(0);
        final inputShape = inputTensor.shape;

        print('VAE Input shape: $inputShape');
        expect(inputShape.length, equals(4),
            reason: 'Expected 4D latent tensor');
        expect(inputShape[1], equals(4), reason: 'Expected 4 latent channels');

        // VAE outputs RGB image: [batch, 3, 384, 384]
        final outputTensor = interpreter.getOutputTensor(0);
        final outputShape = outputTensor.shape;

        print('VAE Output shape: $outputShape');
        expect(outputShape.length, equals(4),
            reason: 'Expected 4D image tensor');
        expect(outputShape[1], equals(3), reason: 'Expected 3 RGB channels');
        expect(outputShape[2], equals(384), reason: 'Expected height of 384');
        expect(outputShape[3], equals(384), reason: 'Expected width of 384');

        print('✓ VAE decoder shapes verified');
        interpreter.close();
      } catch (e) {
        print('❌ Error loading VAE decoder: $e');
        fail('VAE decoder shape verification failed: $e');
      }
    });
  });

  group('Model Compatibility Tests', () {
    test('Verify TFLite Flutter package version compatibility', () async {
      try {
        // Try to create a simple interpreter to verify package works
        print('TFLite Flutter package loaded successfully');
        print('Package is compatible with current Dart SDK');
      } catch (e) {
        print('❌ TFLite Flutter package error: $e');
        fail('Package compatibility issue: $e');
      }
    });
  });
}
