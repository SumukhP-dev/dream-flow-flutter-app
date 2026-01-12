# How to Remove Text from Images in Dream Flow

## Overview

The Dream Flow app now supports generating images **without text overlays**! This feature allows you to create clean, text-free images that show only the visual content of your stories.

## Backend Changes Made

### 1. Updated VisualGenerator Classes
- Added `include_text_overlay` parameter to all `create_frames` methods
- Modified image processing to conditionally apply text captions
- Updated both cloud and local visual generators

### 2. Updated API Schema
- Added `include_text_overlay: bool = True` to `StoryRequest` model
- Maintains backward compatibility (defaults to `True`)

### 3. Updated API Endpoints
- Modified story generation endpoints to pass the parameter through
- Works with both progressive and regular frame generation

## How to Use

### From API (Backend)

```json
{
  "prompt": "A young fox exploring a magical forest",
  "theme": "Adventure",
  "num_scenes": 4,
  "include_text_overlay": false,
  "language": "en"
}
```

### From Flutter App (Frontend)

Update your story request to include the new parameter:

```dart
// In your story request model
class StoryRequest {
  final String prompt;
  final String theme;
  final int numScenes;
  final bool includeTextOverlay; // Add this field
  final String language;

  const StoryRequest({
    required this.prompt,
    required this.theme,
    this.numScenes = 4,
    this.includeTextOverlay = true, // Default to true for backward compatibility
    this.language = 'en',
  });

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'theme': theme,
    'num_scenes': numScenes,
    'include_text_overlay': includeTextOverlay, // Include in API call
    'language': language,
  };
}
```

### Example Usage in Flutter

```dart
// Generate story WITHOUT text overlays
final request = StoryRequest(
  prompt: 'A magical adventure in an enchanted forest',
  theme: 'Fantasy Adventure',
  numScenes: 4,
  includeTextOverlay: false, // This removes text from images!
);

final story = await storyService.generateStory(request);
// Images will now be clean without text captions
```

## Testing

Run the test script to verify the feature works:

```bash
cd backend_fastapi
python test_no_overlay.py
```

This will generate two stories:
1. One WITHOUT text overlays (clean images)
2. One WITH text overlays (for comparison)

## Benefits

✅ **Clean Images**: Generate images without text clutter  
✅ **Better Visual Focus**: Images showcase artwork without distractions  
✅ **Flexible Display**: Frontend can overlay custom text styling  
✅ **Backward Compatible**: Existing apps continue working unchanged  
✅ **User Choice**: Users can toggle text on/off per story  

## Use Cases

- **Art Gallery Mode**: Display stories as pure visual narratives
- **Custom Text Styling**: Frontend controls text appearance and timing
- **Translation Ready**: Generate images once, overlay different languages
- **Clean Exports**: Share or print images without embedded text
- **Accessibility**: Use screen readers with separate text content

The images you showed earlier would now appear without the black text boxes at the bottom, showing only the beautiful illustrated scenes of Nova the fox in the enchanted forest! 🦊✨