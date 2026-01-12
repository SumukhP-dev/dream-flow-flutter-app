import 'package:flutter/material.dart';

/// Widget to display character illustrations in stories
class CharacterIllustrationWidget extends StatelessWidget {
  final String characterId;
  final String? characterName;
  final double size;
  final Color? backgroundColor;

  const CharacterIllustrationWidget({
    super.key,
    required this.characterId,
    this.characterName,
    this.size = 100,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // For now, use emoji representation
    // In production, this would load actual character illustrations from assets
    final emoji = _getCharacterEmoji(characterId);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.shade100,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: size * 0.6),
        ),
      ),
    );
  }

  String _getCharacterEmoji(String characterId) {
    switch (characterId) {
      case 'adventurer':
        return '🧙';
      case 'princess':
        return '👸';
      case 'knight':
        return '🛡️';
      case 'wizard':
        return '🧙‍♂️';
      case 'fairy':
        return '🧚';
      case 'dragon':
        return '🐉';
      default:
        return '😊';
    }
  }
}

/// Widget to display character in story panel
class StoryCharacterWidget extends StatelessWidget {
  final String characterId;
  final String? characterName;
  final Alignment alignment;
  final double size;

  const StoryCharacterWidget({
    super.key,
    required this.characterId,
    this.characterName,
    this.alignment = Alignment.center,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: CharacterIllustrationWidget(
        characterId: characterId,
        characterName: characterName,
        size: size,
      ),
    );
  }
}

