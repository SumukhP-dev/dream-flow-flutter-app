import '../core/audio_service.dart';
import '../core/video_service.dart';

enum DownloadType { audio, video, frames }

class DownloadTask {
  final String id;
  final String url;
  final DownloadType type;
  final String fileName;
  double progress;
  bool isCompleted;
  bool isFailed;
  String? error;
  DateTime createdAt;

  DownloadTask({
    required this.id,
    required this.url,
    required this.type,
    required this.fileName,
    this.progress = 0.0,
    this.isCompleted = false,
    this.isFailed = false,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class DownloadQueueService {
  final AudioService _audioService = AudioService();
  final VideoService _videoService = VideoService();

  final List<DownloadTask> _tasks = [];
  bool _isProcessing = false;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  bool get isProcessing => _isProcessing;
  bool get hasPendingTasks => _tasks.any((t) => !t.isCompleted && !t.isFailed);

  /// Add a download task to the queue
  String addTask({
    required String url,
    required DownloadType type,
    required String fileName,
  }) {
    final task = DownloadTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      type: type,
      fileName: fileName,
    );
    _tasks.add(task);
    _processQueue();
    return task.id;
  }

  /// Remove a completed or failed task
  void removeTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
  }

  /// Clear all completed tasks
  void clearCompleted() {
    _tasks.removeWhere((t) => t.isCompleted || t.isFailed);
  }

  /// Get task by ID
  DownloadTask? getTask(String taskId) {
    try {
      return _tasks.firstWhere((t) => t.id == taskId);
    } catch (_) {
      return null;
    }
  }

  /// Process the download queue
  Future<void> _processQueue() async {
    if (_isProcessing) return;

    _isProcessing = true;

    while (hasPendingTasks) {
      final task = _tasks.firstWhere(
        (t) => !t.isCompleted && !t.isFailed,
      );

      try {
        switch (task.type) {
          case DownloadType.audio:
            await _downloadAudio(task);
            break;
          case DownloadType.video:
            await _downloadVideo(task);
            break;
          case DownloadType.frames:
            // Frames are handled differently - download individually
            await _downloadFrames(task);
            break;
        }

        task.isCompleted = true;
        task.progress = 1.0;
      } catch (e) {
        task.isFailed = true;
        task.error = e.toString();
      }
    }

    _isProcessing = false;
  }

  Future<void> _downloadAudio(DownloadTask task) async {
    // Use audio service caching
    await _audioService.cacheNarration(task.url);
    task.progress = 1.0;
  }

  Future<void> _downloadVideo(DownloadTask task) async {
    // Use video service caching
    await _videoService.cacheVideo(task.url);
    task.progress = 1.0;
  }

  Future<void> _downloadFrames(DownloadTask task) async {
    // For frames, we'll download to gallery
    // This is a simplified version - in production, parse the URL list
    // For now, just mark as completed
    task.progress = 1.0;
  }

  /// Get total cache size
  Future<int> getTotalCacheSize() async {
    final audioSize = await _audioService.getCacheSize();
    final videoSize = await _videoService.getCacheSize();
    return audioSize + videoSize;
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    await _audioService.clearCache();
    await _videoService.clearCache();
  }

  /// Format bytes to human-readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

