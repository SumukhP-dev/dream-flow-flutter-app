# Share Stories Button Fix

## Problem
The "Share Story" button in the app was not working properly. Users were unable to share their stories with the Dream Flow community.

## Root Cause
The share story API calls in `story_service.dart` were missing authentication headers. The backend API endpoint `/api/v1/stories/{session_id}/share` requires authentication (Bearer token), but the Flutter app was sending requests without the necessary `Authorization` header.

## Solution
Updated `dream-flow-app/app/lib/core/story_service.dart` to include authentication tokens in all story-related API calls:

### Changes Made:

1. **Added Supabase import** (line 6):
   ```dart
   import 'package:supabase_flutter/supabase_flutter.dart';
   ```

2. **Added helper method to get authentication token** (lines 427-436):
   ```dart
   /// Get authentication token from Supabase
   Future<String?> _getAuthToken() async {
     try {
       final session = Supabase.instance.client.auth.currentSession;
       return session?.accessToken;
     } catch (e) {
       print('Failed to get auth token: $e');
       return null;
     }
   }
   ```

3. **Updated `shareStory` method** to include authentication:
   - Added token retrieval
   - Added authentication check (throws error if not logged in)
   - Added `Authorization` header to the API request

4. **Updated `unshareStory` method** to include authentication

5. **Updated `reportStory` method** to include authentication

6. **Updated `likeStory` method** to include authentication

## How It Works Now

When a user taps the "Share Story" button:

1. The app retrieves the user's authentication token from Supabase
2. If no token is found, it shows an error: "You must be logged in to share stories"
3. If authenticated, it sends a POST request to `/api/v1/stories/{session_id}/share` with:
   - `Authorization: Bearer {token}` header
   - Request body: `{ "is_public": true, "age_rating": "all" }`
4. The backend verifies the user owns the story
5. The backend checks parental controls (if applicable)
6. The backend runs content moderation checks
7. The story is made public and shown to the user as shared

## User Experience

- **Success**: Users see "Story shared! It will be visible after moderation." message
- **Not logged in**: Users see "You must be logged in to share stories"
- **Server error**: Users see detailed error message from the backend

## Testing

To test the share button:

1. Launch the app and sign in
2. Create or view a story
3. Tap the "Share Story" button
4. Verify success message appears
5. Check that the story appears in the public stories feed (after moderation approval)

## Backend Requirements

The backend endpoint `/api/v1/stories/{session_id}/share` is already properly implemented and includes:
- Authentication verification
- Ownership verification
- Parental control checks
- Content moderation
- Database updates

No backend changes were needed for this fix.

## Related Files

- `dream-flow-app/app/lib/core/story_service.dart` - Main fix applied here
- `dream-flow-app/app/lib/screens/session_screen.dart` - UI that calls shareStory
- `backend_fastapi/app/dreamflow/main.py` - Backend endpoint (lines 3219-3395)
