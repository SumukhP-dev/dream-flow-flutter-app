import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'model_config.dart';

/// Callback for download progress (bytes downloaded, total bytes, percentage)
typedef DownloadProgressCallback = void Function(
    int bytesDownloaded, int totalBytes, double percentage);

/// Service for managing ML model downloads, caching, and versioning
class ModelManager {
  static ModelManager? _instance;
  static ModelManager get instance => _instance ??= ModelManager._();

  ModelManager._();

  Directory? _modelDirectory;
  final Map<String, bool> _downloadingModels = {};

  /// Get the model directory, creating it if necessary
  Future<Directory> _getModelDirectory() async {
    if (_modelDirectory != null && await _modelDirectory!.exists()) {
      return _modelDirectory!;
    }

    // `path_provider` relies on platform channels which are not available in all
    // environments (notably in unit tests). Fall back to a temp directory when
    // the documents directory can't be resolved.
    Directory appDir;
    try {
      appDir = await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint(
        '⚠️ getApplicationDocumentsDirectory() unavailable, using systemTemp. Error: $e',
      );
      appDir = Directory.systemTemp;
    }
    final modelDir = Directory(path.join(appDir.path, 'models'));
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    _modelDirectory = modelDir;
    return modelDir;
  }

  /// Check if a model file exists locally
  Future<bool> modelExists(String filename) async {
    final modelDir = await _getModelDirectory();
    final file = File(path.join(modelDir.path, filename));
    return await file.exists();
  }

  /// Get the local file path for a model
  Future<File> getModelFile(String filename) async {
    final modelDir = await _getModelDirectory();
    return File(path.join(modelDir.path, filename));
  }

  /// Download a model from URL to local storage
  /// Returns the local file path
  Future<File> downloadModel({
    required String url,
    required String filename,
    DownloadProgressCallback? onProgress,
  }) async {
    // Check if already downloading
    if (_downloadingModels[filename] == true) {
      throw Exception('Model $filename is already being downloaded');
    }

    // Check if already exists
    final file = await getModelFile(filename);
    if (await file.exists()) {
      debugPrint('Model $filename already exists, skipping download');
      return file;
    }

    try {
      _downloadingModels[filename] = true;

      debugPrint('Downloading model $filename from $url');
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode >= 400) {
        throw Exception(
            'Failed to download model (${streamedResponse.statusCode})');
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      int bytesDownloaded = 0;

      // Write to temporary file first
      final tempFile = File('${file.path}.tmp');
      final sink = tempFile.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        bytesDownloaded += chunk.length;

        // Report progress if callback provided
        if (onProgress != null && contentLength > 0) {
          final percentage = (bytesDownloaded / contentLength) * 100;
          onProgress(bytesDownloaded, contentLength, percentage);
        }
      }

      await sink.close();

      // Move temp file to final location
      if (await tempFile.exists()) {
        await tempFile.rename(file.path);
      }

      debugPrint('Successfully downloaded model $filename');
      return file;
    } catch (e) {
      // Clean up temp file on error
      final tempFile = File('${file.path}.tmp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    } finally {
      _downloadingModels[filename] = false;
    }
  }

  /// Download story model for current platform
  Future<File> downloadStoryModel({DownloadProgressCallback? onProgress}) async {
    final storyModel = ModelConfig.storyModel;
    final filename = storyModel.getFilename();
    final url = storyModel.getDownloadUrl();

    return downloadModel(
      url: url,
      filename: filename,
      onProgress: onProgress,
    );
  }

  /// Download image generation models for current platform
  Future<List<File>> downloadImageModels({DownloadProgressCallback? onProgress}) async {
    final imageModel = ModelConfig.imageModel;
    final files = <File>[];

    if (Platform.isAndroid) {
      final filenames = imageModel.getAndroidFilenames();
      final urls = imageModel.getAndroidDownloadUrls();

      for (int i = 0; i < filenames.length; i++) {
        final file = await downloadModel(
          url: urls[i],
          filename: filenames[i],
          onProgress: onProgress,
        );
        files.add(file);
      }
    } else if (Platform.isIOS) {
      // Use TFLite models for iOS as well (fallback from Core ML)
      final filenames = imageModel.getIOSFilenames();
      final urls = imageModel.getIOSDownloadUrls();
      
      for (int i = 0; i < filenames.length; i++) {
        final file = await downloadModel(
          url: urls[i],
          filename: filenames[i],
          onProgress: onProgress,
        );
        files.add(file);
      }
    } else {
      throw UnsupportedError('Platform not supported');
    }

    return files;
  }

  /// Check if story model is available locally
  Future<bool> hasStoryModel() async {
    final storyModel = ModelConfig.storyModel;
    final filename = storyModel.getFilename();
    return modelExists(filename);
  }

  /// Check if image models are available locally
  Future<bool> hasImageModels() async {
    final imageModel = ModelConfig.imageModel;

    if (Platform.isAndroid) {
      final filenames = imageModel.getAndroidFilenames();
      for (final filename in filenames) {
        if (!await modelExists(filename)) {
          return false;
        }
      }
      return true;
    } else if (Platform.isIOS) {
      // Check for TFLite models on iOS too
      final filenames = imageModel.getIOSFilenames();
      for (final filename in filenames) {
        if (!await modelExists(filename)) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  /// Get total size of all cached models in bytes
  Future<int> getCachedModelsSize() async {
    final modelDir = await _getModelDirectory();
    if (!await modelDir.exists()) {
      return 0;
    }

    int totalBytes = 0;
    await for (final entity in modelDir.list()) {
      if (entity is File && !entity.path.endsWith('.tmp')) {
        final stat = await entity.stat();
        totalBytes += stat.size;
      }
    }
    return totalBytes;
  }

  /// Delete a specific model file
  Future<void> deleteModel(String filename) async {
    final file = await getModelFile(filename);
    if (await file.exists()) {
      await file.delete();
      debugPrint('Deleted model: $filename');
    }
  }

  /// Clear all cached models
  Future<void> clearAllModels() async {
    final modelDir = await _getModelDirectory();
    if (!await modelDir.exists()) {
      return;
    }

    await for (final entity in modelDir.list()) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (e) {
          debugPrint('Failed to delete ${entity.path}: $e');
        }
      }
    }
    debugPrint('Cleared all cached models');
  }

  /// Verify model file integrity (check file size matches expected)
  Future<bool> verifyModel(String filename, int expectedSize) async {
    final file = await getModelFile(filename);
    if (!await file.exists()) {
      return false;
    }

    final stat = await file.stat();
    // Allow 5% tolerance for file size differences
    final tolerance = expectedSize * 0.05;
    final minSize = expectedSize - tolerance.toInt();
    final maxSize = expectedSize + tolerance.toInt();

    return stat.size >= minSize && stat.size <= maxSize;
  }

  /// Get model version file path
  Future<File> _getVersionFile() async {
    final modelDir = await _getModelDirectory();
    return File(path.join(modelDir.path, 'model_version.txt'));
  }

  /// Save model version
  Future<void> saveModelVersion() async {
    final versionFile = await _getVersionFile();
    await versionFile.writeAsString(ModelConfig.modelVersion);
  }

  /// Get saved model version
  Future<String?> getSavedModelVersion() async {
    final versionFile = await _getVersionFile();
    if (await versionFile.exists()) {
      return await versionFile.readAsString();
    }
    return null;
  }

  /// Check if models need to be updated
  Future<bool> modelsNeedUpdate() async {
    final savedVersion = await getSavedModelVersion();
    return savedVersion != ModelConfig.modelVersion;
  }

  /// Update models if version changed
  Future<void> updateModelsIfNeeded({
    DownloadProgressCallback? onProgress,
  }) async {
    if (await modelsNeedUpdate()) {
      debugPrint('Model version changed, clearing old models');
      await clearAllModels();
      await saveModelVersion();
    }
  }
}

