import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'native_ml_bridge.dart';

/// HTTP server that exposes ML inference endpoints for backend communication
///
/// Runs on port 8081 and provides endpoints for:
/// - Story generation: POST /ml/story/generate
/// - Image generation: POST /ml/image/generate
///
/// This allows the Python backend to call native ML inference via HTTP
class MLHttpServer {
  static const int _defaultPort = 8081;
  static InternetAddress get _host => InternetAddress.loopbackIPv4;

  HttpServer? _server;
  final int _port;
  final NativeMLBridge _mlBridge = NativeMLBridge.instance;

  MLHttpServer({int? port}) : _port = port ?? _defaultPort;

  /// Start the ML HTTP server
  Future<void> start() async {
    if (_server != null) {
      return; // Already running
    }

    try {
      _server = await HttpServer.bind(_host, _port);
      debugPrint('✅ ML HTTP server bound to ${_host.address}:$_port');
    } catch (e) {
      debugPrint('❌ Failed to bind ML HTTP server: $e');
      rethrow;
    }

    // Handle requests
    _server!.listen(
      (HttpRequest request) {
        _handleRequest(request);
      },
      onError: (error) {
        debugPrint('❌ ML server error: $error');
      },
      cancelOnError: false,
    );

    debugPrint(
        '✅ ML HTTP server started and listening on http://${_host.address}:$_port');

    // Initialize ML bridge
    await _mlBridge.initialize();
  }

  /// Stop the ML HTTP server
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    debugPrint('ML HTTP server stopped');
  }

  /// Get the server URL
  String get baseUrl => 'http://localhost:$_port';

  /// Handle incoming HTTP requests
  void _handleRequest(HttpRequest request) async {
    try {
      final uri = request.uri;
      final method = request.method;

      debugPrint('📥 ML server received request: $method ${uri.path}');

      // CORS headers
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add(
          'Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      request.response.headers
          .add('Access-Control-Allow-Headers', 'Content-Type, Authorization');

      // Handle OPTIONS requests
      if (method == 'OPTIONS') {
        request.response.statusCode = 204;
        await request.response.close();
        return;
      }

      // Route requests
      if (uri.path == '/ml/story/generate' && method == 'POST') {
        await _handleStoryGeneration(request);
      } else if (uri.path == '/ml/image/generate' && method == 'POST') {
        await _handleImageGeneration(request);
      } else if (uri.path == '/ml/health' && method == 'GET') {
        await _handleHealth(request);
      } else {
        request.response.statusCode = 404;
        request.response.write(jsonEncode({'error': 'Not found'}));
        await request.response.close();
      }
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    }
  }

  /// Handle health check endpoint
  Future<void> _handleHealth(HttpRequest request) async {
    final response = {
      'status': 'ok',
      'storyModelLoaded': _mlBridge.isStoryModelLoaded,
      'imageModelLoaded': _mlBridge.isImageModelLoaded,
      'models': {
        'story': {
          'loaded': _mlBridge.isStoryModelLoaded,
          'status': _mlBridge.isStoryModelLoaded ? 'ready' : 'not_loaded',
          'note': _mlBridge.isStoryModelLoaded 
              ? 'Story generation available' 
              : 'Story model not loaded - will use fallback'
        },
        'image': {
          'loaded': _mlBridge.isImageModelLoaded,
          'status': _mlBridge.isImageModelLoaded ? 'ready' : 'not_loaded',
          'note': _mlBridge.isImageModelLoaded 
              ? 'Image generation available' 
              : 'Image models not loaded - will use placeholder or Dart fallback'
        }
      }
    };

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(response));
    await request.response.close();
  }

  /// Handle story generation endpoint
  Future<void> _handleStoryGeneration(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final requestData = jsonDecode(body) as Map<String, dynamic>;

      final prompt = requestData['prompt'] as String? ?? '';
      final maxTokens = requestData['maxTokens'] as int? ?? 200;
      final temperature =
          (requestData['temperature'] as num?)?.toDouble() ?? 0.8;

      if (prompt.isEmpty) {
        request.response.statusCode = 400;
        request.response.write(jsonEncode({'error': 'Prompt is required'}));
        await request.response.close();
        return;
      }

      // Generate story using native ML bridge
      final storyText = await _mlBridge.generateStory(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
      );

      final response = {
        'story_text': storyText,
        'model': Platform.isIOS ? 'coreml' : 'tflite',
      };

      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    }
  }

  /// Handle image generation endpoint
  Future<void> _handleImageGeneration(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final requestData = jsonDecode(body) as Map<String, dynamic>;

      final prompt = requestData['prompt'] as String? ?? '';
      final width = requestData['width'] as int? ?? 512;
      final height = requestData['height'] as int? ?? 512;
      final numInferenceSteps = requestData['numInferenceSteps'] as int? ?? 20;

      if (prompt.isEmpty) {
        request.response.statusCode = 400;
        request.response.write(jsonEncode({'error': 'Prompt is required'}));
        await request.response.close();
        return;
      }

      // Generate image using native ML bridge
      final imageBytes = await _mlBridge.generateImage(
        prompt: prompt,
        width: width,
        height: height,
        numInferenceSteps: numInferenceSteps,
      );

      if (imageBytes.isEmpty) {
        // Model not implemented or failed - return helpful error message
        request.response.statusCode = 501;
        request.response.write(jsonEncode({
          'error': 'Image generation not available',
          'message': 'Native image generation models are not loaded or not implemented',
          'details': {
            'reason': 'Model files may be missing or native implementation not available',
            'fallback': 'Backend will use placeholder images or Dart-based generation',
            'status': 'expected_behavior'
          },
          'suggestion': 'Ensure image model files (text_encoder.tflite, unet.tflite, vae_decoder.tflite) are available'
        }));
        await request.response.close();
        return;
      }

      // Return image as base64 encoded
      final base64Image = base64Encode(imageBytes);
      final response = {
        'image': base64Image,
        'format': 'png',
        'width': width,
        'height': height,
        'model': Platform.isIOS ? 'coreml' : 'tflite',
      };

      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    }
  }
}
