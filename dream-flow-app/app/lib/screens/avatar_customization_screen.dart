import 'package:flutter/material.dart';
import '../services/avatar_service.dart';
import '../widgets/avatar_editor_widget.dart';
import '../core/auth_service.dart';

class AvatarCustomizationScreen extends StatefulWidget {
  final String? childProfileId;
  final Avatar? existingAvatar;

  const AvatarCustomizationScreen({
    super.key,
    this.childProfileId,
    this.existingAvatar,
  });

  @override
  State<AvatarCustomizationScreen> createState() =>
      _AvatarCustomizationScreenState();
}

class _AvatarCustomizationScreenState
    extends State<AvatarCustomizationScreen> {
  final AvatarService _avatarService = AvatarService();
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  late AvatarOptions _currentOptions;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentOptions = widget.existingAvatar?.options ??
        AvatarOptions(
          faceType: 'happy',
          hairType: 'short',
          hairColor: '#000000',
          skinColor: '#FFDBAC',
          clothingType: 'tshirt',
          clothingColor: '#4A90E2',
        );
    _nameController.text = widget.existingAvatar?.name ?? 'My Avatar';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveAvatar() async {
    final user = _authService.currentUser;
    if (user == null) {
      _showError('Please log in to save your avatar');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.existingAvatar != null) {
        await _avatarService.updateAvatar(
          avatarId: widget.existingAvatar!.id,
          options: _currentOptions,
          name: _nameController.text.trim(),
        );
      } else {
        await _avatarService.createAvatar(
          userId: user.id,
          childProfileId: widget.childProfileId,
          options: _currentOptions,
          name: _nameController.text.trim(),
          isDefault: true,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Failed to save avatar: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Avatar'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveAvatar,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Name input
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Avatar Name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          // Avatar editor
          Expanded(
            child: AvatarEditorWidget(
              initialOptions: _currentOptions,
              onOptionsChanged: (options) {
                setState(() => _currentOptions = options);
              },
              showPreview: true,
            ),
          ),
        ],
      ),
    );
  }
}

