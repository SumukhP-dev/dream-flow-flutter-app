# TTS Voice Selection Guide

## Overview

The app supports **automatic voice selection** based on story characteristics (theme, mood, etc.), allowing different voices for different types of stories.

## Voice Selection Rules

### By Theme

| Theme Type | Selected Voice | Characteristics |
|------------|----------------|-----------------|
| **Calming** (Aurora, Ocean, Forest, Night, Moon) | `en-US-AriaNeural` | Female, gentle, soothing |
| **Adventure** (Journey, Quest, Exploration) | `en-US-Alex` | Neutral, clear, energetic |
| **Fantasy** (Magic, Fairy, Wizard, Dragon) | `en-US-Samantha` | Female, warm, whimsical |
| **Nature** (Garden, Meadow, Peaceful) | `en-US-AriaNeural` | Gentle, calm |
| **Default** | `en-US-AriaNeural` | Calming female (best for bedtime) |

### By Mood

The selected voice can be adjusted based on user mood:

- **Anxious/Restless**: Extra calming voice (Aria)
- **Excited/Happy**: Base theme voice (can adjust pace/pitch)
- **Calm/Peaceful**: Default calming voice

### User Override

Users can specify a preferred voice, which takes priority over automatic selection.

## Platform Support

### iOS

Uses native AVSpeechSynthesizer voices:
- `en-US-AriaNeural` - Female, gentle (recommended)
- `en-US-Alex` - Neutral, clear
- `en-US-Samantha` - Female, warm
- `en-US-Victoria` - Female, expressive
- `en-US-Daniel` - Male, calm

### Android

Uses Android TTS API voices:
- `en-US-female` - Female voice (default)
- `en-US-male` - Male voice
- Additional voices vary by device and installed TTS engines

## Implementation

### Automatic Selection

```dart
// Voice is automatically selected based on theme and mood
final audio = await mlService.generateAudio(
  text: storyText,
  theme: 'Aurora Dreams',  // Selects Aria (gentle)
  mood: 'calm',            // Keeps calming voice
  profile: userProfile,
);
```

### Manual Selection

```dart
// Override automatic selection with specific voice
final audio = await mlService.generateAudio(
  text: storyText,
  voice: 'en-US-Alex',  // Forces Alex voice
  theme: 'Aurora Dreams',
);
```

### In Parallel Generation

The `ParallelGenerationService` automatically passes theme and mood to audio generation:

```dart
final result = await parallelService.generateStoryExperience(
  prompt: 'a magical forest',
  theme: 'Aurora Dreams',  // Auto-selects Aria voice
  profile: {
    'mood': 'calm',        // Confirms calming voice
    ...
  },
);
```

## Voice Characteristics

### Recommended for Bedtime Stories

**Primary Choice**: `en-US-AriaNeural`
- Soft and calming
- Perfect for soothing bedtime stories
- Works well with all calming themes

**Alternative**: `en-US-Samantha`
- Warm and friendly
- Good for magical/fantasy stories
- Still gentle enough for bedtime

### For Active Stories

**Primary Choice**: `en-US-Alex`
- Clear and neutral
- More energetic than Aria
- Good for adventure/quest themes

## Customization

### Adding New Voice Mappings

Edit `voice_selection_service.dart`:

```dart
String? _getVoiceForTheme(String theme) {
  // Add new theme → voice mappings here
  if (themeLower.contains('your-theme')) {
    return 'en-US-VoiceName';
  }
  // ...
}
```

### Voice Parameters

TTS voices also support adjustable parameters:
- **Speech Rate**: 0.5 (slower for bedtime)
- **Volume**: 1.0 (full volume)
- **Pitch**: 1.0 (normal pitch)

These can be adjusted based on mood:
- Anxious mood: Slower speech rate (0.4)
- Excited mood: Slightly faster (0.6)
- Normal: Default (0.5)

## Testing

Test different voices with:

```dart
// Test voice selection
final voiceService = VoiceSelectionService.instance;
final voice = voiceService.selectVoice(
  theme: 'Aurora Dreams',
  mood: 'calm',
);
print('Selected voice: $voice'); // Should be en-US-AriaNeural
```

## Future Enhancements

Potential improvements:
1. **Character-specific voices**: Different voices for story characters
2. **Emotion-aware voices**: Adjust voice tone based on story emotion
3. **User voice preferences**: Learn user preferences over time
4. **Premium voices**: High-quality neural voices for premium users
5. **Multi-language support**: Voices for different languages

