import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/quest_service.dart';

class CalmQuestsScreen extends StatefulWidget {
  const CalmQuestsScreen({super.key});

  @override
  State<CalmQuestsScreen> createState() => _CalmQuestsScreenState();
}

class _CalmQuestsScreenState extends State<CalmQuestsScreen> {
  final QuestService _questService = QuestService();
  List<CalmQuest> _quests = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadQuests();
  }

  Future<void> _loadQuests() async {
    final quests = await _questService.getQuests();
    if (!mounted) return;
    setState(() {
      _quests = quests;
      _loading = false;
    });
  }

  Future<void> _handlePrintable(QuestReward reward) async {
    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Generate badge content
      final badgeContent = _generateBadgeContent(reward);
      
      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/${reward.title.replaceAll(' ', '_')}.txt';
      final file = File(filePath);
      await file.writeAsString(badgeContent);

      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      // Share the badge
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: reward.title,
        text: 'I earned the ${reward.title} in Dream Flow! 🎉',
      );

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Badge ready to print: ${reward.title}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // Close loading dialog if open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error preparing badge: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generateBadgeContent(QuestReward reward) {
    // Generate a simple text-based badge that can be printed
    return '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
       DREAM FLOW ACHIEVEMENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

            🎉 ${reward.title.toUpperCase()} 🎉

      Congratulations on completing
           your calm quest!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Date Earned: ${DateTime.now().toString().substring(0, 10)}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    Keep up the mindful practice! ✨
    
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';
  }

  Future<void> _handleARBadge(QuestReward reward) async {
    // Placeholder for AR badge functionality
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.view_in_ar, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('AR Badge'),
          ],
        ),
        content: Text(
          'Your ${reward.title} is ready! AR badge viewing will be available in a future update. For now, you\'ve unlocked this achievement!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Calm quests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _quests.length,
              itemBuilder: (context, index) {
                final quest = _quests[index];
                return _QuestCard(
                  quest: quest,
                  onStepCompleted: (steps) async {
                    await _questService.updateQuestProgress(
                      questId: quest.id,
                      completedSteps: steps,
                    );
                    _loadQuests();
                  },
                  onClaim: () async {
                    await _questService.claimReward(quest.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Reward unlocked: ${quest.reward.title}!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadQuests();
                  },
                  onPrintable: () => _handlePrintable(quest.reward),
                  onARBadge: () => _handleARBadge(quest.reward),
                );
              },
            ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.onStepCompleted,
    required this.onClaim,
    required this.onPrintable,
    required this.onARBadge,
  });

  final CalmQuest quest;
  final ValueChanged<int> onStepCompleted;
  final VoidCallback onClaim;
  final VoidCallback onPrintable;
  final VoidCallback onARBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D44),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Description
            Text(
              quest.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              quest.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            
            // Progress bar
            LinearProgressIndicator(
              value: quest.progress,
              backgroundColor: const Color(0xFF3D3D5C),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B7FFF)),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 16),
            
            // Quest steps/checkboxes
            ...quest.steps.asMap().entries.map(
              (entry) {
                final isComplete = entry.key < quest.completedSteps;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isComplete 
                              ? const Color(0xFF8B7FFF) 
                              : Colors.transparent,
                          border: Border.all(
                            color: isComplete 
                                ? const Color(0xFF8B7FFF) 
                                : Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: isComplete
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value.label,
                          style: TextStyle(
                            color: isComplete 
                                ? Colors.white 
                                : Colors.white.withValues(alpha: 0.6),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // Reward badge button
            if (quest.isComplete && quest.claimed) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D3D5C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: InkWell(
                  onTap: () {
                    if (quest.reward.type == 'printable') {
                      onPrintable();
                    } else if (quest.reward.type == 'ar') {
                      onARBadge();
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        quest.reward.type == 'printable' 
                            ? Icons.print 
                            : Icons.view_in_ar,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${quest.reward.type} • ${quest.reward.title}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A4A6A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Claimed',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ] else if (quest.isComplete && !quest.claimed) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D3D5C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      quest.reward.type == 'printable' 
                          ? Icons.print 
                          : Icons.view_in_ar,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${quest.reward.type} • ${quest.reward.title}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onClaim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B7FFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Claim',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D3D5C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      quest.reward.type == 'printable' 
                          ? Icons.print 
                          : Icons.view_in_ar,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${quest.reward.type} • ${quest.reward.title}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

