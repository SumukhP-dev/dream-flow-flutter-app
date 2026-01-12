import 'package:flutter/material.dart';
import '../services/download_queue_service.dart';
import '../core/audio_service.dart';
import '../core/video_service.dart';

class StorageManagementScreen extends StatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  State<StorageManagementScreen> createState() =>
      _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen> {
  final DownloadQueueService _downloadQueue = DownloadQueueService();
  final AudioService _audioService = AudioService();
  final VideoService _videoService = VideoService();

  int _totalCacheSize = 0;
  int _audioCacheSize = 0;
  int _videoCacheSize = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheSizes();
  }

  Future<void> _loadCacheSizes() async {
    setState(() => _isLoading = true);

    try {
      final audioSize = await _audioService.getCacheSize();
      final videoSize = await _videoService.getCacheSize();
      final totalSize = await _downloadQueue.getTotalCacheSize();

      setState(() {
        _audioCacheSize = audioSize;
        _videoCacheSize = videoSize;
        _totalCacheSize = totalSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearAudioCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Audio Cache'),
        content: const Text(
          'This will remove all cached audio files. You can re-download them when needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _audioService.clearCache();
      await _loadCacheSizes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio cache cleared')),
        );
      }
    }
  }

  Future<void> _clearVideoCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Video Cache'),
        content: const Text(
          'This will remove all cached video files. You can re-download them when needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _videoService.clearCache();
      await _loadCacheSizes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video cache cleared')),
        );
      }
    }
  }

  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Cache'),
        content: const Text(
          'This will remove all cached files. You can re-download them when needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _downloadQueue.clearAllCaches();
      await _loadCacheSizes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All cache cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCacheSizes,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCacheCard(
                      title: 'Total Cache Size',
                      size: _totalCacheSize,
                      icon: Icons.storage,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildCacheCard(
                      title: 'Audio Cache',
                      size: _audioCacheSize,
                      icon: Icons.audiotrack,
                      color: Colors.purple,
                      onClear: _clearAudioCache,
                    ),
                    const SizedBox(height: 16),
                    _buildCacheCard(
                      title: 'Video Cache',
                      size: _videoCacheSize,
                      icon: Icons.video_library,
                      color: Colors.orange,
                      onClear: _clearVideoCache,
                    ),
                    const SizedBox(height: 24),
                    if (_downloadQueue.hasPendingTasks) ...[
                      const Text(
                        'Download Queue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._downloadQueue.tasks
                          .map((task) => _buildTaskCard(task)),
                      const SizedBox(height: 16),
                    ],
                    ElevatedButton.icon(
                      onPressed: _clearAllCache,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear All Cache'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCacheCard({
    required String title,
    required int size,
    required IconData icon,
    required Color color,
    VoidCallback? onClear,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (onClear != null)
                  TextButton(
                    onPressed: onClear,
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DownloadQueueService.formatBytes(size),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(DownloadTask task) {
    return Card(
      child: ListTile(
        leading: _getTaskIcon(task.type),
        title: Text(task.fileName),
        subtitle: task.isCompleted
            ? const Text('Completed', style: TextStyle(color: Colors.green))
            : task.isFailed
                ? Text('Failed: ${task.error ?? "Unknown error"}',
                    style: const TextStyle(color: Colors.red))
                : LinearProgressIndicator(value: task.progress),
        trailing: task.isCompleted || task.isFailed
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _downloadQueue.removeTask(task.id);
                  setState(() {});
                },
              )
            : null,
      ),
    );
  }

  Widget _getTaskIcon(DownloadType type) {
    switch (type) {
      case DownloadType.audio:
        return const Icon(Icons.audiotrack, color: Colors.purple);
      case DownloadType.video:
        return const Icon(Icons.video_library, color: Colors.orange);
      case DownloadType.frames:
        return const Icon(Icons.image, color: Colors.blue);
    }
  }
}
