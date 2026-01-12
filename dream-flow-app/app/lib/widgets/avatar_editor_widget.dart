import 'package:flutter/material.dart';
import '../services/avatar_service.dart';

/// Widget for editing avatar appearance
class AvatarEditorWidget extends StatefulWidget {
  final AvatarOptions initialOptions;
  final Function(AvatarOptions) onOptionsChanged;
  final bool showPreview;

  const AvatarEditorWidget({
    super.key,
    required this.initialOptions,
    required this.onOptionsChanged,
    this.showPreview = true,
  });

  @override
  State<AvatarEditorWidget> createState() => _AvatarEditorWidgetState();
}

class _AvatarEditorWidgetState extends State<AvatarEditorWidget> {
  late AvatarOptions _currentOptions;
  final AvatarService _avatarService = AvatarService();

  @override
  void initState() {
    super.initState();
    _currentOptions = widget.initialOptions;
  }

  void _updateOption(String category, String value) {
    setState(() {
      _currentOptions = _currentOptions.copyWith(
        faceType: category == 'face' ? value : _currentOptions.faceType,
        hairType: category == 'hair' ? value : _currentOptions.hairType,
        hairColor: category == 'hair_color' ? value : _currentOptions.hairColor,
        skinColor: category == 'skin' ? value : _currentOptions.skinColor,
        clothingType: category == 'clothing' ? value : _currentOptions.clothingType,
        clothingColor: category == 'clothing_color' ? value : _currentOptions.clothingColor,
        accessory: category == 'accessory' ? value : _currentOptions.accessory,
      );
      widget.onOptionsChanged(_currentOptions);
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableOptions = _avatarService.getAvailableOptions();

    return Column(
      children: [
        if (widget.showPreview) ...[
          _buildPreview(),
          const SizedBox(height: 24),
        ],
        Expanded(
          child: ListView(
            children: [
              _buildOptionSelector(
                'Face',
                'face',
                availableOptions['face_types']!,
                _currentOptions.faceType,
              ),
              _buildColorSelector(
                'Skin Color',
                'skin',
                availableOptions['skin_colors']!,
                _currentOptions.skinColor,
              ),
              _buildOptionSelector(
                'Hair Style',
                'hair',
                availableOptions['hair_types']!,
                _currentOptions.hairType,
              ),
              _buildColorSelector(
                'Hair Color',
                'hair_color',
                availableOptions['hair_colors']!,
                _currentOptions.hairColor,
              ),
              _buildOptionSelector(
                'Clothing',
                'clothing',
                availableOptions['clothing_types']!,
                _currentOptions.clothingType,
              ),
              _buildColorSelector(
                'Clothing Color',
                'clothing_color',
                availableOptions['clothing_colors']!,
                _currentOptions.clothingColor,
              ),
              _buildOptionSelector(
                'Accessory',
                'accessory',
                availableOptions['accessories']!,
                _currentOptions.accessory ?? 'none',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400, width: 2),
      ),
      child: Center(
        child: Text(
          _getAvatarEmoji(),
          style: const TextStyle(fontSize: 80),
        ),
      ),
    );
  }

  String _getAvatarEmoji() {
    // Simple emoji representation based on options
    // In production, this would render the actual avatar
    if (_currentOptions.accessory == 'crown') return '👑';
    if (_currentOptions.clothingType == 'costume') return '🦸';
    return '😊';
  }

  Widget _buildOptionSelector(
    String label,
    String category,
    List<String> options,
    String currentValue,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = option == currentValue;
              return GestureDetector(
                onTap: () => _updateOption(category, option),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue.shade400
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.blue.shade600
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    option.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector(
    String label,
    String category,
    List<String> colors,
    String currentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((color) {
              final isSelected = color == currentColor;
              return GestureDetector(
                onTap: () => _updateOption(category, color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _parseColor(color),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }
}

