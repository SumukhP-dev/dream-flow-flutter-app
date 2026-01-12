# Reflections Tracking Feature Implementation

## Overview
Added comprehensive reflections tracking to the Dream Flow app, allowing users to view their reflection insights, history, and analytics in two places: the homepage and the My Stories screen.

## Changes Made

### 1. Created Reflection Insights Widget
**File:** `dream-flow-app/app/lib/widgets/reflection_insights_widget.dart`

A compact, beautiful widget that displays:
- Current reflection streak (🔥)
- Dominant mood with emoji
- Total reflection logs
- Top topics mentioned
- Actionable recommendations

**Features:**
- Empty state for new users with call-to-action
- Loading state while fetching data
- Gradient purple/blue background matching app theme
- Tappable to navigate to full reflections screen

### 2. Created Full Reflections Screen
**File:** `dream-flow-app/app/lib/screens/reflections_screen.dart`

A comprehensive 3-tab screen showing:

#### Tab 1: Overview
- Stats card with streak, total logs, dominant mood, and voice notes count
- Recommendations card with personalized insights
- Achievements/badges card showing unlocked accomplishments
- Recent reflections preview

#### Tab 2: History
- Full list of all reflection entries
- Each entry shows:
  - Mood emoji and label
  - Date and time
  - User notes (if provided)
  - Voice note indicator (if attached)
  - Beautiful card layout with gradients

#### Tab 3: Insights
- Topics card with visual progress bars showing mention counts
- Weekly trends showing dominant mood and topics per week
- Weekly recap with stats (reflections, voice notes, topics)
- Recommendations for habit building

**UI/UX Features:**
- Dark theme matching app design (Color(0xFF0A0A0A))
- Purple accent colors throughout
- Gradient backgrounds and glass morphism effects
- Empty states for new users with motivational messaging
- Beautiful typography hierarchy
- Responsive layouts

### 3. Updated Home Screen
**File:** `dream-flow-app/app/lib/screens/home_screen.dart`

**Changes:**
- Added import for `ReflectionInsightsWidget` and `ReflectionsScreen`
- Inserted `ReflectionInsightsWidget` in the main scroll view
- Positioned after Caregiver Hub (if enabled) and before Recent Stories
- Widget taps navigate to full `ReflectionsScreen`

**User Flow:**
1. User sees reflection insights card on homepage
2. Tapping opens full reflections screen
3. Can explore overview, history, and insights tabs

### 4. Updated My Stories Screen
**File:** `dream-flow-app/app/lib/screens/my_stories_screen.dart`

**Changes:**
- Added import for `ReflectionsScreen`
- Added sparkle icon button (✨) in AppBar actions
- Button labeled "My Reflections" in tooltip
- Only shown for non-kid mode users
- Tapping navigates to full `ReflectionsScreen`

**User Flow:**
1. User browses their story history
2. Sees reflections button in top-right corner
3. Tapping opens reflections screen to review past reflections

## Database Integration

Reflections are stored in the `story_reflections` table in Supabase:
- `id` - UUID primary key
- `user_id` - References profiles table
- `session_id` - Links to the story session
- `child_profile_id` - Optional for family accounts
- `mood` - Reflection mood (veryCalm, calm, neutral, wiggly, restless)
- `note` - Text reflection from user
- `transcript` - Speech-to-text if voice recorded
- `audio_url` - Link to audio file
- `sentiment` - Numerical sentiment score
- `tags` - Array of categorization tags
- `created_at` - Timestamp

## API Integration

Uses existing `ReflectionService` class:
- `getReflections()` - Fetches all user reflections from local storage
- `getInsights()` - Computes analytics (streak, mood, topics, clusters)
- Falls back to local computation if API unavailable
- Offline-first with SharedPreferences caching

## Key Features

### Reflection Insights
- **Streak Tracking**: Shows consecutive days of reflection logging
- **Mood Analysis**: Identifies dominant mood across all entries
- **Topic Detection**: Keyword-based topic extraction (Ocean, Forest, Travel, Music)
- **Weekly Clustering**: Groups reflections by week with trends
- **Recommendations**: Personalized tips based on reflection patterns
- **Badges/Achievements**: Gamification for engagement

### Analytics Computed
1. **Dominant Mood**: Most frequent mood across all reflections
2. **Streak Calculation**: Consecutive daily reflection count
3. **Topic Mentions**: Count of keywords related to themes
4. **Weekly Trends**: Per-week dominant mood and topics
5. **Audio Usage**: Count of voice notes vs text notes

### User Experience
- Beautiful gradient cards throughout
- Consistent purple/blue color scheme
- Empty states with clear calls-to-action
- Loading states for async operations
- Smooth navigation between screens
- Kid mode respects child safety (hides reflections button)

## Testing Recommendations

1. **Empty State Testing**:
   - New user with no reflections
   - Should show empty state with "Create a Story" CTA
   
2. **Data Population**:
   - Create stories and add reflections via SessionScreen
   - Verify reflections appear in both homepage widget and full screen
   
3. **Navigation Testing**:
   - Tap homepage reflection widget → opens ReflectionsScreen
   - Tap My Stories sparkle icon → opens ReflectionsScreen
   - All tabs (Overview, History, Insights) load correctly
   
4. **Analytics Testing**:
   - Add multiple reflections with different moods
   - Verify dominant mood calculation
   - Check streak calculation with consecutive daily entries
   - Verify topic detection with keyword mentions
   
5. **Offline Testing**:
   - Disable network
   - Should fall back to local insights computation
   - Data persists via SharedPreferences

## Future Enhancements

1. **Export Functionality**: Allow users to export reflection history
2. **Charts/Graphs**: Visual mood trends over time
3. **Reflection Reminders**: Push notifications to log reflections
4. **Goal Setting**: Set reflection frequency goals
5. **Share Insights**: Share weekly summaries with family
6. **Advanced Analytics**: Machine learning for deeper insights
7. **Voice Playback**: Play recorded voice reflections in-app
8. **Search/Filter**: Search reflections by date, mood, or keywords

## Conclusion

The reflections tracking feature provides users with:
- **Visibility**: Clear view of their reflection journey
- **Motivation**: Streaks and badges encourage consistent practice
- **Insights**: Analytics help users understand patterns
- **Accessibility**: Easy access from both homepage and stories screen

This feature enhances user engagement and provides value through personalized insights based on their reflection history.
