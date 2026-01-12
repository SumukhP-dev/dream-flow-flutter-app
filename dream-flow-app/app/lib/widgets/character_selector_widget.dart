import 'package:flutter/material.dart';
import '../services/avatar_service.dart';
import '../services/achievement_service.dart';

/// Widget for selecting a character for story generation
class CharacterSelectorWidget extends StatefulWidget {
  final String? selectedCharacterId;
  final String? childProfileId;
  final Function(String?) onCharacterSelected;

  const CharacterSelectorWidget({
    super.key,
    this.selectedCharacterId,
    this.childProfileId,
    required this.onCharacterSelected,
  });

  @override
  State<CharacterSelectorWidget> createState() =>
      _CharacterSelectorWidgetState();
}

class _CharacterSelectorWidgetState extends State<CharacterSelectorWidget> {
  final AvatarService _avatarService = AvatarService();
  final AchievementService _achievementService = AchievementService();
  List<Avatar> _avatars = [];
  List<Map<String, dynamic>> _characterLibrary = [];
  bool _isLoading = true;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedCharacterId;
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    setState(() => _isLoading = true);

    try {
      // Load user avatars
      if (widget.childProfileId != null) {
        final avatars = await _avatarService.getAvatars(
          childProfileId: widget.childProfileId,
        );
        _avatars = avatars;
      }

      // Load character library (unlockable characters)
      // Default character is always unlocked
      final defaultUnlocked = true;
      
      // Check unlock conditions for other characters
      bool adventurerUnlocked = defaultUnlocked;
      bool princessUnlocked = defaultUnlocked;
      bool knightUnlocked = false;
      
      if (widget.childProfileId != null) {
        try {
          // Get user stats to check unlock conditions
          final stats = await _achievementService.getUserStats(widget.childProfileId!);
          final storiesCompleted = stats['stories_completed'] as int? ?? 0;
          final vocabularyWords = stats['vocabulary_words_learned'] as int? ?? 0;
          
          // Adventurer: Unlock after first story
          adventurerUnlocked = storiesCompleted >= 1;
          
          // Princess: Unlock after 10 stories
          princessUnlocked = storiesCompleted >= 10;
          
          // Knight: Unlock after vocabulary master achievement (50 words) or 50 stories
          knightUnlocked = vocabularyWords >= 50 || storiesCompleted >= 50;
        } catch (e) {
          // On error, use default values (only default character unlocked)
          adventurerUnlocked = defaultUnlocked;
          princessUnlocked = defaultUnlocked;
          knightUnlocked = false;
        }
      }
      
      _characterLibrary = [
        {
          'id': 'default',
          'name': 'Default Character',
          'emoji': '😊',
          'unlocked': defaultUnlocked,
        },
        {
          'id': 'adventurer',
          'name': 'Adventurer',
          'emoji': '🧙',
          'unlocked': adventurerUnlocked,
          'unlockCondition': 'Complete your first story',
        },
        {
          'id': 'princess',
          'name': 'Princess',
          'emoji': '👸',
          'unlocked': princessUnlocked,
          'unlockCondition': 'Complete 10 stories',
        },
        {
          'id': 'knight',
          'name': 'Knight',
          'emoji': '🛡️',
          'unlocked': knightUnlocked,
          'unlockCondition': 'Learn 50 words or complete 50 stories',
        },
      ];

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Your Character',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // User avatars section
        if (_avatars.isNotEmpty) ...[
          const Text(
            'My Avatars',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _buildAvatarGrid(_avatars),
          const SizedBox(height: 24),
        ],
        // Character library section
        const Text(
          'Character Library',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _buildCharacterGrid(_characterLibrary),
      ],
    );
  }

  Widget _buildAvatarGrid(List<Avatar> avatars) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatar = avatars[index];
        final isSelected = _selectedId == avatar.id;

        return GestureDetector(
          onTap: () {
            setState(() => _selectedId = avatar.id);
            widget.onCharacterSelected(avatar.id);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '😊', // Avatar emoji representation
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(height: 4),
                Text(
                  avatar.name,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCharacterGrid(List<Map<String, dynamic>> characters) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        final character = characters[index];
        final isSelected = _selectedId == character['id'];
        final isUnlocked = character['unlocked'] as bool;

        return GestureDetector(
          onTap: isUnlocked
              ? () {
                  setState(() => _selectedId = character['id']);
                  widget.onCharacterSelected(character['id']);
                }
              : null,
          child: Opacity(
            opacity: isUnlocked ? 1.0 : 0.5,
            child: Container(
              decoration: BoxDecoration(
                color: isSelected && isUnlocked
                    ? Colors.blue.shade100
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected && isUnlocked
                      ? Colors.blue.shade400
                      : Colors.grey.shade300,
                  width: isSelected && isUnlocked ? 3 : 1,
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        character['emoji'] as String,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        character['name'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  if (!isUnlocked)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Icon(
                        Icons.lock,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
