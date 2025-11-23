import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VideoService {
  VideoService();

  Directory? _cacheDirectory;

  static const String _cacheFolderName = 'video_cache';
  static const int _maxCacheBytes = 500 * 1024 * 1024; // 500 MB (videos are larger)
  static const int _targetCacheBytes = 400 * 1024 * 1024; // Trim down to 400 MB

  /// Check if video is cached
  Future<bool> hasCachedVideo(String url) async {
    final file = await _cacheFileForUrl(url);
    return file.exists();
  }

  /// Get cached video file path, or null if not cached
  Future<File?> getCachedVideo(String url) async {
    final file = await _cacheFileForUrl(url);
    if (await file.exists()) {
      await file.setLastModified(DateTime.now());
      return file;
    }
    return null;
  }

  /// Cache video from URL
  Future<File> cacheVideo(String url) async {
    final file = await _cacheFileForUrl(url);
    if (await file.exists()) {
      await file.setLastModified(DateTime.now());
      return file;
    }
    return _downloadInto(file, url);
  }

  /// Delete cached video
  Future<void> deleteCachedVideo(String url) async {
    final file = await _cacheFileForUrl(url);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Get total cache size in bytes
  Future<int> getCacheSize() async {
    final directory = await _getCacheDirectory();
    if (!await directory.exists()) {
      return 0;
    }

    int totalBytes = 0;
    await for (final entity in directory.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        totalBytes += stat.size;
      }
    }
    return totalBytes;
  }

  /// Clear all cached videos
  Future<void> clearCache() async {
    final directory = await _getCacheDirectory();
    if (!await directory.exists()) {
      return;
    }

    await for (final entity in directory.list()) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {
          // Ignore delete failures
        }
      }
    }
  }

  /// Trim cache if needed
  Future<void> trimCacheIfNeeded() async {
    await _evictOldEntriesIfNeeded(aggressive: false);
  }

  Future<Directory> _getCacheDirectory() async {
    if (_cacheDirectory != null) return _cacheDirectory!;

    Directory baseDirectory;
    try {
      baseDirectory = await getApplicationCacheDirectory();
    } catch (_) {
      baseDirectory = await getTemporaryDirectory();
    }

    final directory = Directory(
      p.join(baseDirectory.path, _cacheFolderName),
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    _cacheDirectory = directory;
    return directory;
  }

  Future<File> _cacheFileForUrl(String url) async {
    final directory = await _getCacheDirectory();
    final safeName = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
    // Determine extension from URL or default to mp4
    final extension = _getExtensionFromUrl(url) ?? 'mp4';
    return File(p.join(directory.path, '$safeName.$extension'));
  }

  String? _getExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final extension = p.extension(path);
      if (extension.isNotEmpty) {
        return extension.substring(1); // Remove the dot
      }
    } catch (_) {
      // Ignore parsing errors
    }
    return null;
  }

  Future<File> _downloadInto(File file, String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode >= 400) {
      throw Exception('Failed to download video (${response.statusCode})');
    }

    try {
      await file.writeAsBytes(response.bodyBytes, flush: true);
    } on FileSystemException {
      await _evictOldEntriesIfNeeded(aggressive: true);
      await file.writeAsBytes(response.bodyBytes, flush: true);
    }

    await _evictOldEntriesIfNeeded(aggressive: false);
    return file;
  }

  Future<void> _evictOldEntriesIfNeeded({required bool aggressive}) async {
    final directory = await _getCacheDirectory();
    if (!await directory.exists()) {
      return;
    }

    final entries = <_CacheEntry>[];
    int totalBytes = 0;

    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      totalBytes += stat.size;
      entries.add(_CacheEntry(file: entity, stat: stat));
    }

    final threshold = aggressive ? _targetCacheBytes : _maxCacheBytes;
    if (totalBytes <= threshold) {
      return;
    }

    entries.sort(
      (a, b) => a.stat.modified.compareTo(b.stat.modified),
    );

    final target = aggressive ? (_targetCacheBytes ~/ 2) : _targetCacheBytes;
    for (final entry in entries) {
      if (totalBytes <= target) break;
      try {
        await entry.file.delete();
        totalBytes -= entry.stat.size;
      } catch (_) {
        // Ignore deletes that fail, we'll try again next run.
      }
    }
  }
}

class _CacheEntry {
  const _CacheEntry({required this.file, required this.stat});

  final File file;
  final FileStat stat;
}

