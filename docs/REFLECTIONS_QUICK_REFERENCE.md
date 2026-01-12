# Reflections Tracking - Quick Reference

## For Users

### How to View Your Reflections

#### Method 1: From Homepage
1. Open the app
2. Scroll down to see the **"Your Reflection Journey"** card
3. Tap the card to open full reflections screen

#### Method 2: From My Stories
1. Navigate to **My Stories** screen
2. Tap the **sparkle icon (✨)** in the top-right corner
3. Full reflections screen opens

### What You'll See

#### Overview Tab
- **Your Journey Stats**
  - 🔥 **Streak**: Consecutive days of logging reflections
  - 📚 **Total Logs**: Number of reflections you've recorded
  - 😊 **Dominant Mood**: Your most frequent mood
  - 🎤 **Voice Notes**: Count of audio reflections

- **Recommendations**: Personalized tips based on your reflection patterns
- **Achievements**: Badges you've unlocked
- **Recent Reflections**: Last 5 entries at a glance

#### History Tab
- Complete chronological list of all your reflections
- Each entry shows:
  - Mood emoji
  - Date and time
  - Your written notes
  - Voice note indicator (if applicable)

#### Insights Tab
- **Your Topics**: Themes mentioned across reflections
- **Weekly Trends**: Week-by-week mood and topic analysis
- **This Week**: Current week's statistics

### How to Log Reflections

1. Complete a story in the app
2. At the end, you'll see a reflection prompt
3. Choose your mood (😴😊😐😅😣)
4. Optionally add:
   - Written note about your experience
   - Voice recording (30 seconds)
5. Submit to save

### Understanding Your Data

#### Streaks
- Counts consecutive days with at least one reflection
- Breaks if you miss a day
- Motivates consistent practice

#### Moods
- **Very Calm** 😴: Deep relaxation achieved
- **Calm** 😊: Comfortable and peaceful
- **Curious** 😐: Neutral, exploratory state
- **Wiggly** 😅: Restless but engaged
- **Restless** 😣: Difficulty settling

#### Topics
- Automatically detected from your notes
- Common topics: Ocean, Forest, Travel, Music
- Shows what themes resonate with you

#### Recommendations
- Based on your reflection patterns
- Suggests techniques to enhance your practice
- Updates as you log more reflections

#### Achievements/Badges
- **Mindful Scribe**: Log 5 reflections
- **Voice Archivist**: Record 3 voice notes
- **Streak Keeper**: Maintain 3-day streak
- **Pattern Spotter**: Complete 2 weeks of data

## For Developers

### File Structure
```
lib/
├── screens/
│   ├── reflections_screen.dart         # Full 3-tab screen
│   ├── home_screen.dart                # Homepage (updated)
│   └── my_stories_screen.dart          # Stories list (updated)
├── widgets/
│   └── reflection_insights_widget.dart # Compact homepage widget
└── services/
    └── reflection_service.dart         # Data service (existing)
```

### Key Classes

#### ReflectionInsightsWidget
**Purpose**: Compact widget for homepage  
**Location**: `lib/widgets/reflection_insights_widget.dart`  
**Props**:
- `onTap`: Callback when widget is tapped

**Usage**:
```dart
ReflectionInsightsWidget(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReflectionsScreen(),
      ),
    );
  },
)
```

#### ReflectionsScreen
**Purpose**: Full-featured reflections screen  
**Location**: `lib/screens/reflections_screen.dart`  
**Features**:
- 3 tabs: Overview, History, Insights
- Automatic data loading
- Beautiful empty states
- Pull-to-refresh (History tab)

**Usage**:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const ReflectionsScreen(),
  ),
);
```

### Data Models

#### ReflectionEntry
```dart
class ReflectionEntry {
  final String id;
  final String? sessionId;
  final ReflectionMood mood;
  final String? note;
  final String? audioPath;
  final String? transcript;
  final DateTime createdAt;
}
```

#### ReflectionInsights
```dart
class ReflectionInsights {
  final ReflectionMood dominantMood;
  final int streak;
  final List<ReflectionTopic> topics;
  final List<ReflectionEntry> entries;
  final List<ReflectionWeekCluster> weeklyClusters;
  final List<ReflectionRecommendation> recommendations;
  final ReflectionCelebrations celebrations;
}
```

#### ReflectionMood (Enum)
```dart
enum ReflectionMood {
  veryCalm,   // 😴
  calm,       // 😊
  neutral,    // 😐
  wiggly,     // 😅
  restless    // 😣
}
```

### Service Methods

#### ReflectionService

**getReflections()**
```dart
Future<List<ReflectionEntry>> getReflections()
```
Returns all stored reflections from SharedPreferences.

**getInsights()**
```dart
Future<ReflectionInsights> getInsights()
```
Fetches insights from API or computes locally if offline.

**submitReflection()**
```dart
Future<ReflectionEntry> submitReflection({
  String? sessionId,
  required ReflectionMood mood,
  String? note,
  String? audioPath,
  String? transcript,
})
```
Saves a new reflection locally and syncs to backend.

### Database Schema

**Table**: `story_reflections`

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| user_id | UUID | User reference |
| session_id | UUID | Story session reference |
| child_profile_id | UUID | Child profile (optional) |
| mood | TEXT | Mood name |
| note | TEXT | User's written note |
| transcript | TEXT | Voice-to-text |
| audio_url | TEXT | S3/storage URL |
| sentiment | NUMERIC | Sentiment score |
| tags | TEXT[] | Category tags |
| created_at | TIMESTAMPTZ | Creation timestamp |

### API Endpoints

**Submit Reflection**
```
POST /api/v1/reflections
Body: ReflectionEntry JSON
Returns: Created reflection with ID
```

**Get Insights**
```
GET /api/v1/reflections/insights
Returns: ReflectionInsights JSON
```

### Styling Constants

```dart
// Background colors
const bgDark = Color(0xFF0A0A0A);
const bgGradientTop = Color(0xFF120E2B);
const bgGradientBottom = Color(0xFF07040F);

// Accent colors
const accentPurple = Color(0xFF8B5CF6);
const accentBlue = Color(0xFF0EA5E9);
const accentAmber = Color(0xFFFBBF24);
const accentOrange = Color(0xFFFB923C);
const accentGreen = Color(0xFF34D399);

// Opacity values
const cardBg = Colors.white @ 5% opacity
const cardBorder = Colors.white @ 10% opacity
const textPrimary = Colors.white @ 100%
const textSecondary = Colors.white @ 70%
const textTertiary = Colors.white @ 50%
```

### Testing Checklist

- [ ] Empty state displays when no reflections
- [ ] Widget loads on homepage
- [ ] Navigation from homepage works
- [ ] Navigation from My Stories works
- [ ] All 3 tabs load correctly
- [ ] Streak calculation is accurate
- [ ] Dominant mood is correct
- [ ] Topics are extracted properly
- [ ] Weekly clusters group correctly
- [ ] Recommendations appear
- [ ] Badges unlock at right thresholds
- [ ] Loading states display
- [ ] Error states handle gracefully
- [ ] Offline mode works
- [ ] Data persists after app restart
- [ ] Kid mode hides reflections button

### Common Issues & Solutions

**Issue**: Widget not appearing on homepage  
**Solution**: Check if user is logged in. Widget may be hidden for offline users.

**Issue**: Empty insights despite having reflections  
**Solution**: Verify `ReflectionService.getReflections()` returns data. Check SharedPreferences key.

**Issue**: Streak not calculating  
**Solution**: Ensure reflections have `created_at` timestamps. Check consecutive day logic.

**Issue**: Topics not detected  
**Solution**: Verify notes contain keywords (ocean, forest, travel, music). Add more keywords if needed.

**Issue**: Navigation not working  
**Solution**: Ensure `ReflectionsScreen` is imported in calling file.

### Customization

#### Add New Topics
Edit `ReflectionService._keywords`:
```dart
static const Map<String, List<String>> _keywords = {
  'Ocean': ['wave', 'tide', 'sea', 'ocean'],
  'Forest': ['forest', 'tree', 'owl', 'fox'],
  'Travel': ['plane', 'train', 'hotel', 'travel'],
  'Music': ['song', 'music', 'melody', 'piano'],
  'Nature': ['nature', 'wild', 'outdoor'], // Add new
};
```

#### Add New Badges
Edit `ReflectionService._buildBadges()`:
```dart
if (entries.length >= 20) {
  badges.add(
    ReflectionBadge(
      code: 'super_scribe',
      label: 'Super Scribe',
      description: 'Logged 20 reflections.',
      unlockedAt: entries[19].createdAt,
    ),
  );
}
```

#### Customize Colors
Edit widget files to use different color schemes:
```dart
gradient: LinearGradient(
  colors: [
    Colors.teal.withValues(alpha: 0.15),
    Colors.cyan.withValues(alpha: 0.15),
  ],
),
```

### Performance Tips

1. **Limit History**: Only load last 60 entries to avoid memory issues
2. **Cache Insights**: Store computed insights to avoid recalculation
3. **Lazy Load**: Use `ListView.builder` for large lists
4. **Debounce**: Add delays to API calls if user rapidly navigates
5. **Image Optimization**: If adding images, use cached network images

### Future Enhancements

- [ ] Export reflections as PDF/CSV
- [ ] Charts showing mood trends over time
- [ ] Custom topic keywords per user
- [ ] Reflection reminders/notifications
- [ ] Social sharing of insights
- [ ] Multi-language support
- [ ] Voice playback in app
- [ ] Advanced filtering and search
- [ ] Reflection templates
- [ ] Integration with health apps (sleep tracking)

## Support

For issues or questions:
1. Check the implementation files listed above
2. Review the visual guide for expected behavior
3. Verify data in Supabase console
4. Check app logs for errors
5. Test with fresh user data

## Version History

**v1.0** (Current)
- Initial implementation
- Homepage widget
- Full reflections screen with 3 tabs
- My Stories integration
- Basic analytics and insights
- Badges and recommendations
