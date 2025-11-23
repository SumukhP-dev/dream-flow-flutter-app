import 'dart:io';

import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SessionAssetService {
  SessionAssetService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const String _downloadFolderName = 'DreamFlow';

  Future<File> downloadVideo({required String url, required String fileName}) {
    return _downloadIntoDownloads(
      url: url,
      fileName: fileName.endsWith('.mp4') ? fileName : '$fileName.mp4',
    );
  }

  Future<File> downloadAudio({required String url, required String fileName}) {
    return _downloadIntoDownloads(url: url, fileName: fileName);
  }

  Future<int> saveFramesToGallery(
    List<String> frameUrls, {
    required String albumName,
  }) async {
    int savedCount = 0;
    for (int i = 0; i < frameUrls.length; i++) {
      final frameUrl = frameUrls[i];
      final tempFile = await _downloadToTemp(
        url: frameUrl,
        fileName:
            '${_sanitizeAlbumName(albumName)}_frame_$i'
            '${_extensionFromUrl(frameUrl, fallback: '.png')}',
      );
      final result = await ImageGallerySaver.saveFile(
        tempFile.path,
        name: '${_sanitizeAlbumName(albumName)}_frame_$i',
      );
      try {
        await tempFile.delete();
      } catch (_) {
        // Ignore delete errors
      }
      if (_didSaveSucceed(result)) {
        savedCount++;
      }
    }

    if (savedCount == 0) {
      throw Exception('Unable to save frames to gallery');
    }

    return savedCount;
  }

  Future<File> cacheForShare({required String url, required String fileName}) {
    return _downloadToTemp(url: url, fileName: fileName);
  }

  Future<File> _downloadIntoDownloads({
    required String url,
    required String fileName,
  }) async {
    final directory = await _resolveDownloadDirectory();
    final file = File(p.join(directory.path, fileName));
    final bytes = await _downloadBytes(url);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> _downloadToTemp({
    required String url,
    required String fileName,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(tempDir.path, fileName));
    final bytes = await _downloadBytes(url);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<List<int>> _downloadBytes(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode >= 400) {
      throw Exception('Failed to download asset (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  Future<Directory> _resolveDownloadDirectory() async {
    Directory baseDirectory;

    if (Platform.isAndroid) {
      final downloads = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (downloads != null && downloads.isNotEmpty) {
        baseDirectory = downloads.first;
      } else {
        baseDirectory =
            await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isIOS) {
      baseDirectory = await getApplicationDocumentsDirectory();
    } else {
      baseDirectory = await getApplicationDocumentsDirectory();
    }

    final directory = Directory(
      p.join(baseDirectory.path, _downloadFolderName),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _extensionFromUrl(String url, {required String fallback}) {
    final parsed = Uri.parse(url);
    final ext = p.extension(parsed.path);
    if (ext.isEmpty) {
      final normalizedFallback = fallback.startsWith('.')
          ? fallback
          : '.$fallback';
      return normalizedFallback;
    }
    return ext;
  }

  bool _didSaveSucceed(dynamic result) {
    if (result is bool) {
      return result;
    }
    if (result is Map && result['isSuccess'] is bool) {
      return result['isSuccess'] as bool;
    }
    return false;
  }

  String _sanitizeAlbumName(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}
