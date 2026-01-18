import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _healthStatus = 'Not checked';
  String _publicStoriesStatus = 'Not checked';
  String _supabaseStatus = 'Unknown';
  String _backendType = 'Unknown';
  String _currentBackendUrl = 'Unknown';
  final List<String> _backendLogs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _detectBackendInfo();
    _runAllTests();
  }

  Future<void> _detectBackendInfo() async {
    // Get the current backend URL using the same logic as the app
    final dartDefineBackendUrl =
        const String.fromEnvironment('BACKEND_URL', defaultValue: '');
    final rawBackendUrl =
        dartDefineBackendUrl.isNotEmpty ? dartDefineBackendUrl : '';

    setState(() {
      _currentBackendUrl = rawBackendUrl.isEmpty
          ? 'http://localhost:8080 (Local Backend)'
          : rawBackendUrl;
      _backendType = rawBackendUrl.isEmpty
          ? '📱 Local (On-Device)'
          : '☁️ External (FastAPI)';
    });

    _log('Backend URL: $_currentBackendUrl');
    _log('Backend Type: $_backendType');
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isLoading = true;
      _backendLogs.clear();
    });

    await _testHealthEndpoint();
    await _testPublicStoriesEndpoint();
    await _testSupabaseConnection();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _testHealthEndpoint() async {
    _log('Testing health endpoint...');
    try {
      final response = await http
          .get(Uri.parse('http://localhost:8080/health'))
          .timeout(const Duration(seconds: 5));

      setState(() {
        _healthStatus =
            'Status: ${response.statusCode}\nResponse: ${response.body}';
      });
      _log('✅ Health endpoint working: ${response.statusCode}');
    } catch (e) {
      setState(() {
        _healthStatus = 'Error: $e';
      });
      _log('❌ Health endpoint failed: $e');
    }
  }

  Future<void> _testPublicStoriesEndpoint() async {
    _log('Testing public stories endpoint...');
    try {
      final response = await http
          .get(Uri.parse('http://localhost:8080/api/v1/stories/public?limit=3'))
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      final stories = data['stories'] as List;

      setState(() {
        _publicStoriesStatus = 'Status: ${response.statusCode}\n'
            'Stories found: ${stories.length}\n'
            'Titles: ${stories.map((s) => s['theme']).join(', ')}';
      });
      _log('✅ Public stories working: ${stories.length} stories found');
    } catch (e) {
      setState(() {
        _publicStoriesStatus = 'Error: $e';
      });
      _log('❌ Public stories failed: $e');
    }
  }

  Future<void> _testSupabaseConnection() async {
    _log('Testing Supabase connection...');
    try {
      // This will be visible in the app logs
      _log('Supabase URL: https://dbpvmfglduprtbpaygmo.supabase.co');
      _log('Check main app logs for "Supabase init completed"');

      setState(() {
        _supabaseStatus =
            'Check main logs for "Supabase init completed" message';
      });
    } catch (e) {
      setState(() {
        _supabaseStatus = 'Error: $e';
      });
      _log('❌ Supabase test failed: $e');
    }
  }

  void _log(String message) {
    print('🔍 DEBUG: $message');
    setState(() {
      _backendLogs
          .add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Backend Debug Monitor',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Backend Type Info (New!)
            _buildStatusCard('Backend Type', _backendType,
                _backendType.contains('External') ? Colors.blue : Colors.green),
            const SizedBox(height: 16),
            _buildStatusCard('Backend URL', _currentBackendUrl, Colors.blue),
            const SizedBox(height: 16),

            // Status Cards
            _buildStatusCard('Health Endpoint', _healthStatus,
                _healthStatus.contains('200') ? Colors.green : Colors.red),
            const SizedBox(height: 16),
            _buildStatusCard(
                'Public Stories API',
                _publicStoriesStatus,
                _publicStoriesStatus.contains('200')
                    ? Colors.green
                    : Colors.red),
            const SizedBox(height: 16),
            _buildStatusCard(
                'Supabase Connection', _supabaseStatus, Colors.blue),

            const SizedBox(height: 24),

            // Refresh Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _runAllTests,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh, color: Colors.white),
                label: Text(_isLoading ? 'Testing...' : 'Refresh Tests',
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Logs Section
            const Text(
              'Backend Logs:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _backendLogs.reversed.take(20).join('\n'),
                  style: const TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Instructions
            const Text(
              'Quick Tips:',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildTip('✅ Green status = Backend working'),
            _buildTip('❌ Red status = Check network/config'),
            _buildTip('📱 Use "Refresh Tests" to recheck'),
            _buildTip('📖 Stories should load in Discover screen'),
            _buildTip('🎨 Story creation should work without hanging'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, String status, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getStatusIcon(status),
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    if (status.contains('200') || status.contains('✅')) {
      return Icons.check_circle;
    } else if (status.contains('Error') || status.contains('❌')) {
      return Icons.error;
    } else {
      return Icons.info;
    }
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        tip,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
