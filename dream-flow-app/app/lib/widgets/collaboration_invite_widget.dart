import 'package:flutter/material.dart';

/// Widget to invite parent for story collaboration
class CollaborationInviteWidget extends StatelessWidget {
  final String childProfileId;
  final Function(String sessionId)? onCollaborationCreated;

  const CollaborationInviteWidget({
    super.key,
    required this.childProfileId,
    this.onCollaborationCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade400,
            Colors.pink.shade400,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '👨‍👩‍👧',
                style: TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Create Story Together',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Invite a parent to help you create a special story!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showInviteDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.purple.shade600,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Invite Parent',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Parent'),
        content: const Text(
          'A notification will be sent to your parent to start creating a story together!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invitation sent!'),
                ),
              );
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }
}

