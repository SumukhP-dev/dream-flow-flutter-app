import 'package:flutter/material.dart';
import '../services/parental_control_service.dart';
import '../shared/subscription_service.dart';
import 'kid_home_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  final ParentalControlService _parentalControlService =
      ParentalControlService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  List<Map<String, dynamic>> _childProfiles = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCheckingAccess = true;
  bool _hasFamilyAccess = false;
  String? _accessError;

  @override
  void initState() {
    super.initState();
    _verifyFamilyAccess();
  }

  Future<void> _verifyFamilyAccess() async {
    setState(() {
      _isCheckingAccess = true;
      _accessError = null;
    });

    try {
      final subscription = await _subscriptionService.getSubscription();
      final tier = subscription.tier.toLowerCase();
      final hasAccess = tier == 'family' && subscription.status == 'active';

      if (!mounted) return;
      if (!hasAccess) {
        setState(() {
          _hasFamilyAccess = false;
          _isCheckingAccess = false;
        });
        return;
      }

      setState(() {
        _hasFamilyAccess = true;
      });
      await _loadChildProfiles();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accessError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isCheckingAccess = false;
      });
    }
  }

  Future<void> _loadChildProfiles() async {
    if (!_hasFamilyAccess) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profiles = await _parentalControlService.getChildProfiles();
      setState(() {
        _childProfiles = profiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChildProfiles,
          ),
        ],
      ),
      body: _isCheckingAccess
          ? const Center(child: CircularProgressIndicator())
          : _accessError != null
              ? _buildAccessError()
              : !_hasFamilyAccess
                  ? _buildFamilyPlanRequired()
                  : _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? _buildChildProfileError()
                          : _childProfiles.isEmpty
                              ? _buildEmptyState()
                              : _buildChildProfileList(),
    );
  }

  Widget _buildAccessError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Could not verify subscription: $_accessError',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _verifyFamilyAccess,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyPlanRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Family plan required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upgrade to the Family plan to create child profiles and manage parental controls.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildProfileError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Error: $_errorMessage'),
          ElevatedButton(
            onPressed: _loadChildProfiles,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.child_care, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No child profiles yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a child profile to get started',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildChildProfileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _childProfiles.length,
      itemBuilder: (context, index) {
        final profile = _childProfiles[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                profile['child_name']?[0] ?? '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              profile['child_name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Age: ${profile['age'] ?? 'N/A'} • Filter: ${profile['content_filter_level'] ?? 'standard'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.play_arrow_rounded, color: Colors.blue),
                  tooltip: 'Open for ${profile['child_name'] ?? 'child'}',
                  onPressed: () {
                    final childId = profile['id'] as String?;
                    final childName = profile['child_name'] as String?;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => KidHomeScreen(
                          childProfileId: childId,
                          childName: childName,
                        ),
                      ),
                    );
                  },
                ),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FamilyProfileScreen(
                    childProfileId: profile['id'],
                    childName: profile['child_name'],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// Child profile settings screen with story sharing controls
class FamilyProfileScreen extends StatefulWidget {
  final String childProfileId;
  final String childName;

  const FamilyProfileScreen({
    super.key,
    required this.childProfileId,
    required this.childName,
  });

  @override
  State<FamilyProfileScreen> createState() => _FamilyProfileScreenState();
}

class _FamilyProfileScreenState extends State<FamilyProfileScreen> {
  final ParentalControlService _parentalControlService =
      ParentalControlService();
  bool _storySharingEnabled = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _sharedStories = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadSharedStories();
  }

  Future<void> _loadSettings() async {
    try {
      final canShare = await _parentalControlService.canChildShareStories(
        widget.childProfileId,
      );
      if (mounted) {
        setState(() {
          _storySharingEnabled = canShare;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSharedStories() async {
    try {
      final stories = await _parentalControlService.getChildSharedStories(
        widget.childProfileId,
      );
      if (mounted) {
        setState(() {
          _sharedStories = stories;
        });
      }
    } catch (e) {
      // Silently fail - not critical
      print('Failed to load shared stories: $e');
    }
  }

  Future<void> _toggleStorySharing(bool enabled) async {
    try {
      await _parentalControlService.enableStorySharing(
        childProfileId: widget.childProfileId,
        enabled: enabled,
      );
      if (mounted) {
        setState(() {
          _storySharingEnabled = enabled;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Story sharing enabled for ${widget.childName}'
                  : 'Story sharing disabled for ${widget.childName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update setting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings for ${widget.childName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Story Sharing Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.share, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              'Story Sharing',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Allow ${widget.childName} to share stories publicly with other users.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Enable Story Sharing'),
                          subtitle: Text(
                            _storySharingEnabled
                                ? 'Stories can be shared publicly'
                                : 'Stories are private only',
                          ),
                          value: _storySharingEnabled,
                          onChanged: _toggleStorySharing,
                        ),
                        if (_storySharingEnabled) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'All shared stories are reviewed by moderators before being visible to others.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Shared Stories Section
                if (_storySharingEnabled && _sharedStories.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.public, size: 24),
                              const SizedBox(width: 12),
                              const Text(
                                'Shared Stories',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_sharedStories.length} story${_sharedStories.length != 1 ? 's' : ''} shared by ${widget.childName}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          ..._sharedStories.map((story) {
                            return ListTile(
                              title: Text(story['theme'] ?? 'Untitled'),
                              subtitle: Text(
                                story['is_approved'] == true
                                    ? 'Public • Approved'
                                    : 'Pending Review',
                              ),
                              trailing: story['is_approved'] == true
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : const Icon(Icons.pending,
                                      color: Colors.orange),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}
