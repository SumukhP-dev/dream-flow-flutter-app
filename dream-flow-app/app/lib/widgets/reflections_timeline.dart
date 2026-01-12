import 'package:flutter/material.dart';

import '../services/reflection_service.dart';

class ReflectionsTimelineWidget extends StatelessWidget {
  const ReflectionsTimelineWidget({super.key, required this.insights});

  final ReflectionInsights insights;

  @override
  Widget build(BuildContext context) {
    if (insights.entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: const Text(
          'No reflections yet. Log one after tonight\'s session.',
        ),
      );
    }

    final recap = insights.celebrations.weeklyRecap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            _chip(
              'Dominant mood',
              '${insights.dominantMood.emoji} ${insights.dominantMood.label}',
            ),
            _chip('Reflection streak', '${insights.streak} nights'),
            if (insights.topics.isNotEmpty)
              _chip('Top motif', insights.topics.first.label),
            if (recap.entriesLogged > 0)
              _chip(
                'This week',
                '${recap.entriesLogged} notes • ${recap.audioNotes} voice',
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: insights.entries.length.clamp(0, 10),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final entry = insights.entries[index];
              return _ReflectionCard(entry: entry);
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      label: Text('$label • $value'),
    );
  }
}

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({required this.entry});

  final ReflectionEntry entry;

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${entry.createdAt.month}/${entry.createdAt.day}';
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF312e81).withValues(alpha: 0.8),
            const Color(0xFF1e1b4b).withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLabel, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(entry.mood.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            entry.note ?? entry.transcript ?? 'Voice note logged',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
