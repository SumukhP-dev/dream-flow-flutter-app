# User Signup Fix - Klaviyo Integration

## Problem Identified

When users signed up through the Dream Flow mobile app, they were **NOT appearing in Klaviyo** and signup events were not being tracked. 

### Root Cause

The Flutter app was calling `Supabase.instance.client.auth.signUp()` directly, which:
1. Created users in Supabase Auth
2. **Bypassed the FastAPI backend entirely**
3. Never triggered `klaviyo_service.track_signed_up()`
4. Never created initial user profiles
5. Never created subscription records

## Solution Implemented

Created a **backend signup endpoint** (`/api/v1/auth/signup`) that handles the complete signup flow:

### Backend Changes

1. **Added signup schemas** (`backend_fastapi/app/dreamflow/schemas.py`):
   - `SignUpRequest`: email, password, full_name, signup_method
   - `SignUpResponse`: user_id, email, message, needs_email_verification

2. **Implemented `/api/v1/auth/signup` endpoint** (`backend_fastapi/app/dreamflow/main.py`):
   ```python
   @app.post("/api/v1/auth/signup", response_model=SignUpResponse)
   async def signup(payload: SignUpRequest) -> SignUpResponse:
       # 1. Create user in Supabase Auth
       # 2. Create initial profile
       # 3. Create free tier subscription  
       # 4. Track signup in Klaviyo
       # 5. Create Klaviyo profile
   ```

### Flutter App Changes

Modified `dream-flow-app/app/lib/core/auth_service.dart`:

```dart
// NOW: Call backend endpoint first
final response = await http.post(
  Uri.parse('$backendUrl/api/v1/auth/signup'),
  body: json.encode({
    'email': email,
    'password': password,
    'full_name': fullName,
    'signup_method': 'email',
  }),
);

// Then sign in to get session
final authResponse = await Supabase.instance.client.auth.signInWithPassword(
  email: email,
  password: password,
);
```

## What This Fixes

✅ **Klaviyo Tracking**: `track_signed_up()` is now called for every signup
✅ **User Profiles**: Initial profile is created in `profiles` table
✅ **Subscriptions**: Free tier subscription is automatically created
✅ **Klaviyo Profiles**: User profiles are synced to Klaviyo with:
   - Email
   - Subscription tier
   - First/last name
   - Signup method

## Testing

### Test Script

Created `backend_fastapi/test_signup_endpoint.py` to verify:
1. POST `/api/v1/auth/signup` creates user
2. Duplicate signups are rejected (409)
3. Backend health check passes

### Running Tests

```bash
cd backend_fastapi
python test_signup_endpoint.py
```

### Manual Testing

1. Start backend: `py -3.11 -m uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload`
2. Start Supabase (if using local): `supabase start`
3. Run Flutter app
4. Sign up with a new email
5. Check Klaviyo dashboard for "Signed Up" event
6. Check Supabase dashboard for:
   - New user in `auth.users`
   - New profile in `profiles`
   - New subscription in `subscriptions`

## Files Changed

```
backend_fastapi/
├── app/
│   └── dreamflow/
│       ├── schemas.py          # Added SignUpRequest, SignUpResponse
│       └── main.py             # Added /api/v1/auth/signup endpoint
├── test_signup_endpoint.py     # Test script
└── test_user_signup.py         # Diagnostic script

dream-flow-app/app/
└── lib/
    └── core/
        └── auth_service.dart   # Modified signUp() to call backend
```

## Next Steps

1. **Deploy Changes**: Push to production
2. **Monitor Klaviyo**: Verify signup events appear
3. **Test Email Flows**: Confirm welcome emails work
4. **Analytics**: Track signup completion rate

## Notes

- The endpoint requires Supabase to be configured
- Klaviyo tracking gracefully degrades if not configured
- Duplicate signups return HTTP 409
- Password must be at least 8 characters
- Email verification can be required (configurable in Supabase)

## Backward Compatibility

Existing users who signed up before this fix:
- Will continue to work normally
- Can be backfilled to Klaviyo using a migration script
- Consider running: `klaviyo_service.sync_full_profile_from_supabase()` for all existing users
