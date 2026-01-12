import 'package:flutter/material.dart';

class ThemeOption {
  final String title;
  final String emoji;
  final String category;
  final Color color;

  const ThemeOption({
    required this.title,
    required this.emoji,
    required this.category,
    required this.color,
  });
}

class KidThemeSelector extends StatefulWidget {
  final List<ThemeOption> themes;
  final ThemeOption? selectedTheme;
  final ValueChanged<ThemeOption> onThemeSelected;

  const KidThemeSelector({
    super.key,
    required this.themes,
    this.selectedTheme,
    required this.onThemeSelected,
  });

  @override
  State<KidThemeSelector> createState() => _KidThemeSelectorState();
}

class _KidThemeSelectorState extends State<KidThemeSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    return widget.themes.map((t) => t.category).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Your Story World',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        ..._categories.map((category) {
          final categoryThemes = widget.themes
              .where((t) => t.category == category)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 12),
                child: Text(
                  category,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: categoryThemes.map((theme) {
                  final isSelected = widget.selectedTheme?.title == theme.title;
                  return _buildThemeCard(theme, isSelected);
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildThemeCard(ThemeOption theme, bool isSelected) {
    return GestureDetector(
      onTap: () {
        _animationController.forward(from: 0.0).then((_) {
          _animationController.reverse();
        });
        widget.onThemeSelected(theme);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.color.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? theme.color
                : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.color.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              theme.emoji,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 8),
            Text(
              theme.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

