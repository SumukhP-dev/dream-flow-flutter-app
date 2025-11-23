import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AudioService {
  AudioService();

  final AudioPlayer _player = AudioPlayer();
  Directory? _cacheDirectory;

  static const String _cacheFolderName = 'narration_cache';
  static const int _maxCacheBytes = 150 * 1024 * 1024; // 150 MB
  static const int _targetCacheBytes = 120 * 1024 * 1024; // Trim down to 120 MB

  Future<void> playAsset(String filePath) async {
    await _player.setAsset(filePath);
    await _player.setLoopMode(LoopMode.one);
    _player.play();
  }

  Future<void> playUrl(
    String url, {
    bool preferCache = false,
  }) async {
    if (preferCache) {
      final file = await _ensureNarrationCached(url);
      if (file != null && await file.exists()) {
        await _player.setFilePath(file.path);
      } else {
        await _player.setUrl(url);
      }
    } else {
      await _player.setUrl(url);
    }
    await _player.setLoopMode(LoopMode.one);
    _player.play();
  }

  Future<bool> hasCachedNarration(String url) async {
    final file = await _cacheFileForUrl(url);
    return file.exists();
  }

  Future<File> cacheNarration(String url) async {
    final file = await _cacheFileForUrl(url);
    if (await file.exists()) {
      await file.setLastModified(DateTime.now());
      return file;
    }
    return _downloadInto(file, url);
  }

  Future<void> deleteCachedNarration(String url) async {
    final file = await _cacheFileForUrl(url);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> trimCacheIfNeeded() async {
    await _evictOldEntriesIfNeeded(aggressive: false);
  }

  Future<void> stop() => _player.stop();

  void dispose() => _player.dispose();

  Future<File?> _ensureNarrationCached(String url) async {
    try {
      return await cacheNarration(url);
    } catch (_) {
      return null;
    }
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
    return File(p.join(directory.path, '$safeName.m4a'));
  }

  Future<File> _downloadInto(File file, String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode >= 400) {
      throw Exception('Failed to download narration (${response.statusCode})');
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
