/// Voice selection service for TTS narration
/// Selects appropriate voices based on story characteristics (theme, mood, etc.)
class VoiceSelectionService {
  VoiceSelectionService._();
  static VoiceSelectionService? _instance;
  static VoiceSelectionService get instance =>
      _instance ??= VoiceSelectionService._();

  /// Select voice based on story characteristics
  /// 
  /// Voice selection rules:
  /// - Themes determine voice gender/style
  /// - Mood affects voice tone/pace
  /// - User preferences can override defaults
  String? selectVoice({
    required String theme,
    String? mood,
    Map<String, dynamic>? profile,
    String? preferredVoice,
  }) {
    // User preference takes priority
    if (preferredVoice != null && preferredVoice.isNotEmpty) {
      return preferredVoice;
    }

    // Select voice based on theme
    final themeVoice = _getVoiceForTheme(theme);
    
    // Adjust based on mood if specified
    if (mood != null) {
      return _adjustVoiceForMood(themeVoice, mood);
    }

    return themeVoice;
  }

  /// Get voice identifier for a given theme
  String? _getVoiceForTheme(String theme) {
    // Map themes to appropriate voices
    final themeLower = theme.toLowerCase();

    // Calming/soothing themes -> gentle female voices
    if (themeLower.contains('aurora') ||
        themeLower.contains('ocean') ||
        themeLower.contains('forest') ||
        themeLower.contains('night') ||
        themeLower.contains('moon')) {
      // iOS: Aria (female, gentle)
      // Android: en-US-female
      return 'en-US-AriaNeural'; // iOS preferred
    }

    // Adventure/active themes -> more energetic voices
    if (themeLower.contains('adventure') ||
        themeLower.contains('journey') ||
        themeLower.contains('quest')) {
      // iOS: Alex (neutral, clear)
      // Android: en-US-male
      return 'en-US-Alex'; // iOS preferred
    }

    // Fantasy/magical themes -> whimsical voices
    if (themeLower.contains('magic') ||
        themeLower.contains('fairy') ||
        themeLower.contains('wizard') ||
        themeLower.contains('dragon')) {
      // iOS: Samantha (female, warm)
      // Android: en-US-female
      return 'en-US-Samantha'; // iOS preferred
    }

    // Nature/peaceful themes -> calm voices
    if (themeLower.contains('nature') ||
        themeLower.contains('garden') ||
        themeLower.contains('meadow')) {
      return 'en-US-AriaNeural'; // Gentle female
    }

    // Default: Calming female voice for bedtime stories
    return 'en-US-AriaNeural';
  }

  /// Adjust voice selection based on mood
  String? _adjustVoiceForMood(String? baseVoice, String mood) {
    final moodLower = mood.toLowerCase();

    // For anxious/restless moods, use extra calming voice
    if (moodLower.contains('anxious') ||
        moodLower.contains('restless') ||
        moodLower.contains('worried')) {
      // Use the calmest available voice
      return 'en-US-AriaNeural'; // Very gentle
    }

    // For excited/happy moods, slightly more energetic
    if (moodLower.contains('excited') || moodLower.contains('happy')) {
      // Keep base voice but can adjust parameters instead
      return baseVoice;
    }

    // For calm/peaceful moods, use default calming voice
    return baseVoice ?? 'en-US-AriaNeural';
  }

  /// Get available voices for platform
  /// 
  /// iOS voices: Aria, Alex, Samantha, etc.
  /// Android voices: Various system TTS voices
  List<String> getAvailableVoices(String platform) {
    if (platform == 'ios') {
      return [
        'en-US-AriaNeural', // Female, gentle (default for bedtime)
        'en-US-Alex', // Neutral, clear
        'en-US-Samantha', // Female, warm
        'en-US-Victoria', // Female, expressive
        'en-US-Daniel', // Male, calm
      ];
    } else if (platform == 'android') {
      return [
        'en-US-female', // Female voice (default)
        'en-US-male', // Male voice
        // Android TTS voices vary by device
        // flutter_tts package can list available voices
      ];
    }
    return ['en-US-AriaNeural']; // Default fallback
  }

  /// Get voice display name for UI
  String getVoiceDisplayName(String voiceId) {
    final voiceMap = {
      'en-US-AriaNeural': 'Aria (Gentle)',
      'en-US-Alex': 'Alex (Clear)',
      'en-US-Samantha': 'Samantha (Warm)',
      'en-US-Victoria': 'Victoria (Expressive)',
      'en-US-Daniel': 'Daniel (Calm)',
      'en-US-female': 'Female Voice',
      'en-US-male': 'Male Voice',
    };

    return voiceMap[voiceId] ?? voiceId;
  }

  /// Get voice description for UI
  String getVoiceDescription(String voiceId) {
    final descMap = {
      'en-US-AriaNeural': 'Soft and calming, perfect for bedtime stories',
      'en-US-Alex': 'Clear and neutral, great for adventures',
      'en-US-Samantha': 'Warm and friendly, ideal for magical tales',
      'en-US-Victoria': 'Expressive and engaging',
      'en-US-Daniel': 'Calm and reassuring',
      'en-US-female': 'Gentle female voice',
      'en-US-male': 'Clear male voice',
    };

    return descMap[voiceId] ?? 'Default voice';
  }
}

