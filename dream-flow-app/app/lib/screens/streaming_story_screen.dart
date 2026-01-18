import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/story_service.dart';
import 'session_screen.dart';

class StreamingStoryScreen extends StatefulWidget {
  final StoryGenerationRequest request;

  const StreamingStoryScreen({
    super.key,
    required this.request,
  });

  @override
  State<StreamingStoryScreen> createState() => _StreamingStoryScreenState();
}

class _StreamingStoryScreenState extends State<StreamingStoryScreen> {
  final StoryService _storyService = StoryService();
  final StringBuffer _buffer = StringBuffer();
  StreamSubscription<String>? _subscription;
  bool _isDone = false;
  bool _hasError = false;
  String? _errorMessage;
  late final StoryGenerationRequest _requestWithUserContext;

  @override
  void initState() {
    super.initState();
    _requestWithUserContext = _attachUserContext(widget.request);
    _startStreaming();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  StoryGenerationRequest _attachUserContext(StoryGenerationRequest request) {
    // Attach user context to the request
    return request;
  }

  Future<void> _startStreaming() async {
    try {
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });

      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;
      final response = await http.post(
        Uri.parse('${_storyService.baseUrl}/api/v1/story/stream'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(_requestWithUserContext.toJson()),
      );

      if (response.statusCode == 200) {
        // Handle successful response - for now, just navigate to session
        var experience = await _storyService.generateStory(_requestWithUserContext);
        if (experience.sessionId == null) {
          final offlineId = await _storyService.saveOfflineStory(
            request: _requestWithUserContext,
            experience: experience,
          );
          experience = experience.copyWith(sessionId: offlineId);
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SessionScreen(experience: experience),
            ),
          );
        }
      } else {
        throw Exception('Failed to start streaming: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _formatErrorMessage(e);
        });
      }
    }
  }

  String _formatErrorMessage(dynamic error) {
    if (error is SocketException) {
      return 'Connection error. Please check your internet connection.';
    } else if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else {
      return error.toString();
    }
  }

  Future<void> _fallbackToRegularGeneration() async {
    try {
      setState(() {
        _hasError = false;
        _errorMessage = null;
        _buffer.clear();
        _isDone = false;
      });

      var experience = await _storyService.generateStory(_requestWithUserContext);
      if (experience.sessionId == null) {
        final offlineId = await _storyService.saveOfflineStory(
          request: _requestWithUserContext,
          experience: experience,
        );
        experience = experience.copyWith(sessionId: offlineId);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SessionScreen(experience: experience),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _formatErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _requestWithUserContext.theme,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _hasError
            ? _buildErrorView()
            : _isDone
                ? _buildCompleteView()
                : _buildStreamingView(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Story Creation Failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unexpected error occurred',
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Go Back'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _fallbackToRegularGeneration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Story Complete!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your story is ready',
            style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFF8B5CF6),
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Creating your story...',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _buffer.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}