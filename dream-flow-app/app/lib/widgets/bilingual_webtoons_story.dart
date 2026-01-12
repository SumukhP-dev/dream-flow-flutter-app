import 'package:flutter/material.dart';

/// Represents a sentence with bilingual content
class BilingualSentence {
  final String primaryText;
  final String secondaryText;
  final String primaryLanguage;
  final String secondaryLanguage;
  final int paragraphIndex;
  final int sentenceIndex;

  BilingualSentence({
    required this.primaryText,
    required this.secondaryText,
    required this.primaryLanguage,
    required this.secondaryLanguage,
    required this.paragraphIndex,
    required this.sentenceIndex,
  });
}

/// Represents a paragraph containing bilingual sentences
class BilingualParagraph {
  final List<BilingualSentence> sentences;
  final int paragraphIndex;

  BilingualParagraph({
    required this.sentences,
    required this.paragraphIndex,
  });
}

/// State for managing language display
class LanguageDisplayState {
  String globalLanguage; // 'primary', 'secondary', or 'both'
  Map<String, String>
      sentenceOverrides; // "paragraphIndex:sentenceIndex" -> language override
  bool isChildMode;

  LanguageDisplayState({
    this.globalLanguage = 'primary',
    Map<String, String>? sentenceOverrides,
    this.isChildMode = false,
  }) : sentenceOverrides = sentenceOverrides ?? {};

  LanguageDisplayState copyWith({
    String? globalLanguage,
    Map<String, String>? sentenceOverrides,
    bool? isChildMode,
  }) {
    return LanguageDisplayState(
      globalLanguage: globalLanguage ?? this.globalLanguage,
      sentenceOverrides: sentenceOverrides ?? Map.from(this.sentenceOverrides),
      isChildMode: isChildMode ?? this.isChildMode,
    );
  }
}

/// Webtoons-style bilingual story display widget with sentence-level switching
class BilingualWebtoonsStory extends StatefulWidget {
  final String storyText;
  final String primaryLanguage;
  final String secondaryLanguage;
  final bool isChildMode;

  const BilingualWebtoonsStory({
    super.key,
    required this.storyText,
    required this.primaryLanguage,
    required this.secondaryLanguage,
    this.isChildMode = false,
  });

  @override
  State<BilingualWebtoonsStory> createState() => _BilingualWebtoonsStoryState();
}

class _BilingualWebtoonsStoryState extends State<BilingualWebtoonsStory> {
  late LanguageDisplayState _languageState;
  List<BilingualParagraph> _paragraphs = [];

  @override
  void initState() {
    super.initState();
    _languageState = LanguageDisplayState(
      isChildMode: widget.isChildMode,
    );
    _parseStoryText();
  }

  /// Parse story text into paragraphs and sentences
  void _parseStoryText() {
    // Split story into paragraphs
    final rawParagraphs =
        widget.storyText.split('\n').where((p) => p.trim().isNotEmpty).toList();

    // Try to detect language markers in the text (e.g., [EN: ...] [ES: ...])
    final hasLanguageMarkers = rawParagraphs.any((p) =>
        p.contains(RegExp(r'\[(EN|ES|FR|JA):')) ||
        p.contains(
            RegExp(r'<lang code="(en|es|fr|ja)">', caseSensitive: false)));

    if (hasLanguageMarkers) {
      _paragraphs = _parseWithLanguageMarkers(rawParagraphs);
    } else {
      // Parse without markers - assume alternating or same text
      _paragraphs = rawParagraphs.asMap().entries.map((entry) {
        final paragraphIndex = entry.key;
        final text = entry.value.trim();

        // Parse paragraph into sentences
        final sentences = _parseSentences(
          text,
          paragraphIndex,
        );

        return BilingualParagraph(
          sentences: sentences,
          paragraphIndex: paragraphIndex,
        );
      }).toList();
    }

    // Ensure all sentences have both language versions
    // If no language markers were found and secondary language is different,
    // we need to note that translations aren't available
    _paragraphs = _paragraphs.map((para) {
      final updatedSentences = para.sentences.map((sent) {
        if (sent.primaryText.isEmpty && sent.secondaryText.isNotEmpty) {
          return BilingualSentence(
            primaryText: sent.secondaryText,
            secondaryText: sent.secondaryText,
            primaryLanguage: sent.primaryLanguage,
            secondaryLanguage: sent.secondaryLanguage,
            paragraphIndex: sent.paragraphIndex,
            sentenceIndex: sent.sentenceIndex,
          );
        } else if (sent.secondaryText.isEmpty && sent.primaryText.isNotEmpty) {
          return BilingualSentence(
            primaryText: sent.primaryText,
            secondaryText: sent.primaryText,
            primaryLanguage: sent.primaryLanguage,
            secondaryLanguage: sent.secondaryLanguage,
            paragraphIndex: sent.paragraphIndex,
            sentenceIndex: sent.sentenceIndex,
          );
        }
        return sent;
      }).toList();

      return BilingualParagraph(
        sentences: updatedSentences,
        paragraphIndex: para.paragraphIndex,
      );
    }).toList();
  }

  /// Parse a paragraph into sentences with edge case handling
  List<BilingualSentence> _parseSentences(String text, int paragraphIndex) {
    final List<BilingualSentence> sentences = [];

    if (text.trim().isEmpty) {
      return sentences;
    }

    // Common abbreviations that shouldn't split sentences
    final abbreviationPattern = RegExp(
      r'\b(Mr|Mrs|Ms|Dr|Prof|Sr|Jr|vs|etc|e\.g|i\.e|a\.m|p\.m|U\.S|U\.K|Ph\.D|B\.A|M\.A)\.',
      caseSensitive: false,
    );

    // Simple sentence splitting: look for . ! ? followed by space or end of string
    // But exclude if it's part of an abbreviation or number
    final List<int> boundaries = [];

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      // Check for sentence endings
      if (char == '.' || char == '!' || char == '?') {
        // Check if it's an ellipsis
        if (i + 2 < text.length && text[i + 1] == '.' && text[i + 2] == '.') {
          // Skip ellipsis, mark end after third dot
          if (i + 3 < text.length && text[i + 3] == '.') {
            // More dots, skip
            continue;
          }
          // Check if next char is space or end
          if (i + 3 >= text.length ||
              text[i + 3] == ' ' ||
              text[i + 3] == '\n' ||
              text[i + 3] == '\t') {
            boundaries.add(i + 3);
            i += 2; // Skip ahead
            continue;
          }
        }

        // Check if it's part of an abbreviation
        final beforeDot = i > 0 ? text.substring(0, i + 1) : '';
        if (abbreviationPattern.hasMatch(beforeDot)) {
          continue; // Skip, it's an abbreviation
        }

        // Check if it's a decimal number (e.g., 3.14)
        if (i > 0 && i + 1 < text.length) {
          final beforeCode = text.codeUnitAt(i - 1);
          final afterCode = text.codeUnitAt(i + 1);
          if (beforeCode >= 48 &&
              beforeCode <= 57 && // digit before
              afterCode >= 48 &&
              afterCode <= 57) {
            // digit after
            continue; // Skip, it's a decimal
          }
        }

        // Check if next char is space, newline, or end of string
        if (i + 1 >= text.length ||
            text[i + 1] == ' ' ||
            text[i + 1] == '\n' ||
            text[i + 1] == '\t') {
          boundaries.add(i + 1);
        }
      }
    }

    // If no boundaries found, treat entire text as one sentence
    if (boundaries.isEmpty) {
      sentences.add(BilingualSentence(
        primaryText: text.trim(),
        secondaryText: text.trim(), // Backend should provide both
        primaryLanguage: widget.primaryLanguage,
        secondaryLanguage: widget.secondaryLanguage,
        paragraphIndex: paragraphIndex,
        sentenceIndex: 0,
      ));
      return sentences;
    }

    // Split text at boundaries
    int lastIndex = 0;
    int sentenceIndex = 0;

    for (final boundary in boundaries) {
      if (boundary > lastIndex) {
        final sentenceText = text.substring(lastIndex, boundary).trim();
        if (sentenceText.isNotEmpty) {
          sentences.add(BilingualSentence(
            primaryText: sentenceText,
            secondaryText: sentenceText, // Backend should provide both
            primaryLanguage: widget.primaryLanguage,
            secondaryLanguage: widget.secondaryLanguage,
            paragraphIndex: paragraphIndex,
            sentenceIndex: sentenceIndex++,
          ));
        }
        lastIndex = boundary;
      }
    }

    // Add remaining text if any
    if (lastIndex < text.length) {
      final remaining = text.substring(lastIndex).trim();
      if (remaining.isNotEmpty) {
        sentences.add(BilingualSentence(
          primaryText: remaining,
          secondaryText: remaining,
          primaryLanguage: widget.primaryLanguage,
          secondaryLanguage: widget.secondaryLanguage,
          paragraphIndex: paragraphIndex,
          sentenceIndex: sentenceIndex,
        ));
      }
    }

    return sentences;
  }

  List<BilingualParagraph> _parseWithLanguageMarkers(
      List<String> rawParagraphs) {
    final List<BilingualParagraph> parsed = [];
    int paragraphIndex = 0;

    for (final para in rawParagraphs) {
      String primaryText = '';
      String secondaryText = '';

      // Debug: log the raw paragraph
      print('🔍 Parsing paragraph $paragraphIndex: "$para"');
      print(
          '   Primary language: ${widget.primaryLanguage}, Secondary: ${widget.secondaryLanguage}');

      // Try to extract [LANG: text] format - handle both complete and incomplete markers
      // First try complete markers: [LANG: text]
      // Use a more robust regex that handles text with brackets inside
      final langMarkerPattern =
          RegExp(r'\[(EN|ES|FR|JA):\s*([^\]]+)\]', caseSensitive: false);
      final matches = langMarkerPattern.allMatches(para);

      for (final match in matches) {
        final langCode = match.group(1)?.toLowerCase() ?? '';
        final text = match.group(2)?.trim() ?? '';

        if (langCode == widget.primaryLanguage.toLowerCase()) {
          // Append if we already have text (multiple markers of same language)
          primaryText = primaryText.isEmpty ? text : '$primaryText $text';
          print('   ✅ Extracted primary text: "$primaryText"');
        } else if (langCode == widget.secondaryLanguage.toLowerCase()) {
          // Append if we already have text (multiple markers of same language)
          secondaryText = secondaryText.isEmpty ? text : '$secondaryText $text';
          print('   ✅ Extracted secondary text: "$secondaryText"');
        } else {
          print(
              '   ⚠️ Found marker for language "$langCode" but it doesn\'t match primary or secondary');
        }
      }

      if (matches.isEmpty) {
        print('   ⚠️ No language markers found in paragraph');
      }

      // If no complete markers found, try to extract incomplete markers (for streaming)
      // This handles cases like "[EN: text without closing bracket"
      if (primaryText.isEmpty && secondaryText.isEmpty) {
        // Pattern for incomplete markers: [LANG: text (may not have closing bracket)
        final incompletePattern = RegExp(
          r'\[(EN|ES|FR|JA):\s*(.+?)(?:\]|$)',
          caseSensitive: false,
        );
        final incompleteMatches = incompletePattern.allMatches(para);

        for (final match in incompleteMatches) {
          final langCode = match.group(1)?.toLowerCase() ?? '';
          final text = match.group(2)?.trim() ?? '';

          if (langCode == widget.primaryLanguage.toLowerCase()) {
            primaryText = text;
          } else if (langCode == widget.secondaryLanguage.toLowerCase()) {
            secondaryText = text;
          }
        }
      }

      // If still no markers found, check if the paragraph starts with a marker but is incomplete
      if (primaryText.isEmpty && secondaryText.isEmpty) {
        // Check for incomplete primary language marker at start
        final primaryLangCode = widget.primaryLanguage.toUpperCase();
        final primaryStartPattern = RegExp(
          '^\\[$primaryLangCode:\\s*(.+)\$',
          caseSensitive: false,
        );
        final primaryMatch = primaryStartPattern.firstMatch(para);
        if (primaryMatch != null) {
          primaryText = primaryMatch.group(1)?.trim() ?? '';
        }

        // Check for incomplete secondary language marker
        final secondaryLangCode = widget.secondaryLanguage.toUpperCase();
        final secondaryStartPattern = RegExp(
          '^\\[$secondaryLangCode:\\s*(.+)\$',
          caseSensitive: false,
        );
        final secondaryMatch = secondaryStartPattern.firstMatch(para);
        if (secondaryMatch != null) {
          secondaryText = secondaryMatch.group(1)?.trim() ?? '';
        }
      }

      // If we have primary but no secondary (or vice versa), use primary for both
      // This handles cases where only one language marker is present
      if (primaryText.isNotEmpty && secondaryText.isEmpty) {
        secondaryText = primaryText; // Use primary as fallback
        print(
            '   ⚠️ Only primary text found, using it for secondary as fallback');
      } else if (secondaryText.isNotEmpty && primaryText.isEmpty) {
        primaryText = secondaryText; // Use secondary as fallback
        print(
            '   ⚠️ Only secondary text found, using it for primary as fallback');
      }

      // If no markers found at all, try to clean up and extract text
      if (primaryText.isEmpty && secondaryText.isEmpty) {
        // Try to remove marker patterns completely: [LANG: text] or [LANG: text
        String cleanedPara = para;

        // Remove complete markers: [LANG: text]
        cleanedPara = cleanedPara.replaceAll(
            RegExp(r'\[(EN|ES|FR|JA):\s*([^\]]+)\]', caseSensitive: false), '');

        // Remove incomplete markers at the start: [LANG: text (no closing bracket)
        cleanedPara = cleanedPara.replaceAll(
            RegExp(r'^\[(EN|ES|FR|JA):\s*', caseSensitive: false), '');

        // Remove any trailing closing brackets that might be left
        cleanedPara = cleanedPara.replaceAll(
            RegExp(r'^\s*\]\s*', caseSensitive: false), '');

        cleanedPara = cleanedPara.trim();

        // Only use cleaned text if we actually removed something
        if (cleanedPara != para.trim() && cleanedPara.isNotEmpty) {
          primaryText = cleanedPara;
          secondaryText = cleanedPara;
        } else {
          // If cleaning didn't work, use the whole paragraph as-is
          primaryText = para.trim();
          secondaryText = para.trim();
        }
      }

      // Parse into sentences
      final primarySentences = _parseSentences(primaryText, paragraphIndex);
      final secondarySentences = _parseSentences(secondaryText, paragraphIndex);

      // Combine sentences (assume same number of sentences in both languages)
      final List<BilingualSentence> combinedSentences = [];
      final maxSentences = primarySentences.length > secondarySentences.length
          ? primarySentences.length
          : secondarySentences.length;

      for (int i = 0; i < maxSentences; i++) {
        final primarySent =
            i < primarySentences.length ? primarySentences[i].primaryText : '';
        final secondarySent = i < secondarySentences.length
            ? secondarySentences[i].primaryText
            : '';

        combinedSentences.add(BilingualSentence(
          primaryText: primarySent.isNotEmpty ? primarySent : secondarySent,
          secondaryText: secondarySent.isNotEmpty ? secondarySent : primarySent,
          primaryLanguage: widget.primaryLanguage,
          secondaryLanguage: widget.secondaryLanguage,
          paragraphIndex: paragraphIndex,
          sentenceIndex: i,
        ));
      }

      parsed.add(BilingualParagraph(
        sentences: combinedSentences,
        paragraphIndex: paragraphIndex++,
      ));
    }

    return parsed;
  }

  String _getLanguageFlag(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'en':
        return '🇺🇸';
      case 'es':
        return '🇪🇸';
      case 'fr':
        return '🇫🇷';
      case 'ja':
        return '🇯🇵';
      default:
        return '🌐';
    }
  }

  String _getLanguageName(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'en':
        return 'English';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'ja':
        return 'Japanese';
      default:
        return langCode.toUpperCase();
    }
  }

  void _toggleGlobalLanguage() {
    setState(() {
      if (_languageState.globalLanguage == 'primary') {
        _languageState = _languageState.copyWith(globalLanguage: 'secondary');
      } else if (_languageState.globalLanguage == 'secondary') {
        _languageState = _languageState.copyWith(globalLanguage: 'both');
      } else {
        _languageState = _languageState.copyWith(globalLanguage: 'primary');
      }
    });
  }

  void _toggleSentenceLanguage(int paragraphIndex, int sentenceIndex) {
    setState(() {
      final key = '$paragraphIndex:$sentenceIndex';
      final currentOverride = _languageState.sentenceOverrides[key];

      if (currentOverride == null) {
        // Use global language as starting point
        final global = _languageState.globalLanguage;
        if (global == 'primary') {
          _languageState.sentenceOverrides[key] = 'secondary';
        } else if (global == 'secondary') {
          _languageState.sentenceOverrides[key] = 'both';
        } else {
          _languageState.sentenceOverrides[key] = 'primary';
        }
      } else if (currentOverride == 'primary') {
        _languageState.sentenceOverrides[key] = 'secondary';
      } else if (currentOverride == 'secondary') {
        _languageState.sentenceOverrides[key] = 'both';
      } else {
        // Remove override to use global language
        _languageState.sentenceOverrides.remove(key);
      }

      _languageState = _languageState.copyWith(
        sentenceOverrides: _languageState.sentenceOverrides,
      );
    });
  }

  String _getDisplayLanguage(int paragraphIndex, int sentenceIndex) {
    final key = '$paragraphIndex:$sentenceIndex';
    final override = _languageState.sentenceOverrides[key];
    return override ?? _languageState.globalLanguage;
  }

  Widget _buildGlobalLanguageToggle() {
    final currentLang = _languageState.globalLanguage;
    String flag;
    String label;

    if (currentLang == 'primary') {
      flag = _getLanguageFlag(widget.primaryLanguage);
      label = _getLanguageName(widget.primaryLanguage);
    } else if (currentLang == 'secondary') {
      flag = _getLanguageFlag(widget.secondaryLanguage);
      label = _getLanguageName(widget.secondaryLanguage);
    } else {
      flag =
          '${_getLanguageFlag(widget.primaryLanguage)}${_getLanguageFlag(widget.secondaryLanguage)}';
      label = 'Both';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: GestureDetector(
          onTap: _toggleGlobalLanguage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.8),
                  const Color(0xFF06B6D4).withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  flag,
                  style: TextStyle(fontSize: widget.isChildMode ? 24 : 20),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.isChildMode ? 14 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSentence(BilingualSentence sentence, bool isFirstInParagraph) {
    final displayLang =
        _getDisplayLanguage(sentence.paragraphIndex, sentence.sentenceIndex);
    final isChildMode = widget.isChildMode;

    String displayText;
    String langCode;
    String langFlag;

    if (displayLang == 'primary') {
      displayText = sentence.primaryText;
      langCode = sentence.primaryLanguage;
      langFlag = _getLanguageFlag(sentence.primaryLanguage);
    } else if (displayLang == 'secondary') {
      displayText = sentence.secondaryText;
      langCode = sentence.secondaryLanguage;
      langFlag = _getLanguageFlag(sentence.secondaryLanguage);
    } else {
      // Show both languages - but only if they're different
      if (sentence.primaryText == sentence.secondaryText) {
        // If texts are the same, just show one
        displayText = sentence.primaryText;
        langCode = 'both';
        langFlag =
            '${_getLanguageFlag(sentence.primaryLanguage)}${_getLanguageFlag(sentence.secondaryLanguage)}';
      } else {
        displayText = '${sentence.primaryText}\n\n${sentence.secondaryText}';
        langCode = 'both';
        langFlag =
            '${_getLanguageFlag(sentence.primaryLanguage)}${_getLanguageFlag(sentence.secondaryLanguage)}';
      }
    }

    final fontSize = isChildMode ? 22.0 : 18.0;
    final lineHeight = isChildMode ? 2.0 : 1.7;
    final minHeight = isChildMode ? 48.0 : 40.0;
    final padding = isChildMode ? 12.0 : 10.0;

    return GestureDetector(
      onTap: () => _toggleSentenceLanguage(
          sentence.paragraphIndex, sentence.sentenceIndex),
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        margin: EdgeInsets.only(
          bottom: isFirstInParagraph ? 8 : 4,
          top: isFirstInParagraph ? 0 : 4,
        ),
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language badge (appears on each sentence)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    langFlag,
                    style: TextStyle(fontSize: isChildMode ? 14 : 12),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    langCode.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isChildMode ? 10 : 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Sentence text
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Text(
                  displayText,
                  key: ValueKey(
                      '$displayLang-${sentence.paragraphIndex}-${sentence.sentenceIndex}'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: fontSize,
                    height: lineHeight,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParagraphPanel(BilingualParagraph paragraph) {
    final isChildMode = widget.isChildMode;
    final padding = isChildMode ? 28.0 : 24.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paragraph header (optional - can show paragraph number or theme)
          const SizedBox(height: 4),
          // Sentences
          ...paragraph.sentences.asMap().entries.map((entry) {
            final index = entry.key;
            final sentence = entry.value;
            return _buildSentence(sentence, index == 0);
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGlobalLanguageToggle(),
        ..._paragraphs.map((para) => _buildParagraphPanel(para)),
      ],
    );
  }
}
