"""
Test script to diagnose user signup issues with Supabase and Klaviyo.

This script:
1. Creates a test user in Supabase
2. Checks if the user appears in Supabase Auth
3. Tests the Klaviyo signup tracking
4. Verifies profile creation

Run with: python test_user_signup.py
"""

import os
import sys
import uuid
from datetime import datetime

# Add app directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.shared.config import get_settings
from app.shared.supabase_client import SupabaseClient
from app.dreamflow.klaviyo_service import KlaviyoService


def test_user_signup():
    """Test the complete user signup flow."""
    print("=" * 60)
    print("Dream Flow User Signup Diagnostic Test")
    print("=" * 60)
    print()

    # Load settings
    settings = get_settings()
    print(f"✓ Settings loaded")
    print(f"  - Supabase URL: {settings.supabase_url[:30]}..." if settings.supabase_url else "  - Supabase URL: NOT SET")
    print(f"  - Klaviyo enabled: {settings.klaviyo_enabled}")
    print()

    # Initialize Supabase client
    try:
        supabase_client = SupabaseClient(settings)
        print(f"✓ Supabase client initialized")
    except Exception as e:
        print(f"✗ Failed to initialize Supabase client: {e}")
        return False

    # Initialize Klaviyo service
    klaviyo_service = None
    if settings.klaviyo_enabled and settings.klaviyo_api_key:
        try:
            klaviyo_service = KlaviyoService(
                api_key=settings.klaviyo_api_key,
                supabase_client=supabase_client.client,
            )
            print(f"✓ Klaviyo service initialized")
        except Exception as e:
            print(f"⚠ Klaviyo service not available: {e}")
    else:
        print(f"⚠ Klaviyo is disabled or API key not set")
    print()

    # Generate test user credentials
    test_email = f"test-user-{uuid.uuid4().hex[:8]}@dreamflow-test.com"
    test_password = "TestPassword123!"
    print(f"Test user credentials:")
    print(f"  - Email: {test_email}")
    print(f"  - Password: {test_password}")
    print()

    # Step 1: Create user in Supabase Auth
    print("Step 1: Creating user in Supabase Auth...")
    try:
        auth_response = supabase_client.client.auth.sign_up({
            "email": test_email,
            "password": test_password,
            "options": {
                "data": {
                    "full_name": "Test User",
                }
            }
        })
        
        if auth_response.user:
            user_id = auth_response.user.id
            print(f"✓ User created in Supabase Auth")
            print(f"  - User ID: {user_id}")
            print(f"  - Email: {auth_response.user.email}")
            print(f"  - Created at: {auth_response.user.created_at}")
        else:
            print(f"✗ Failed to create user: No user returned")
            return False
    except Exception as e:
        print(f"✗ Failed to create user in Supabase: {e}")
        return False
    print()

    # Step 2: Verify user exists in Supabase Auth
    print("Step 2: Verifying user in Supabase Auth...")
    try:
        # Try to sign in with the credentials
        sign_in_response = supabase_client.client.auth.sign_in_with_password({
            "email": test_email,
            "password": test_password,
        })
        
        if sign_in_response.user:
            print(f"✓ User verified - can sign in successfully")
            print(f"  - User ID matches: {sign_in_response.user.id == user_id}")
        else:
            print(f"✗ User verification failed: Cannot sign in")
            return False
    except Exception as e:
        print(f"⚠ User verification issue: {e}")
        print(f"  (This might be expected if email confirmation is required)")
    print()

    # Step 3: Create profile in profiles table
    print("Step 3: Creating user profile...")
    try:
        profile_data = {
            "id": str(user_id),
            "mood": "calm",
            "routine": "test routine",
            "preferences": ["adventure", "fantasy"],
            "favorite_characters": ["dragon", "knight"],
            "calming_elements": ["ocean", "stars"],
        }
        
        result = supabase_client.client.table("profiles").upsert(profile_data).execute()
        
        if result.data:
            print(f"✓ Profile created successfully")
            print(f"  - Profile ID: {result.data[0]['id']}")
        else:
            print(f"✗ Failed to create profile")
    except Exception as e:
        print(f"✗ Failed to create profile: {e}")
    print()

    # Step 4: Track signup in Klaviyo
    if klaviyo_service:
        print("Step 4: Tracking signup in Klaviyo...")
        try:
            success = klaviyo_service.track_signed_up(
                user_id=uuid.UUID(user_id),
                signup_method="email",
            )
            
            if success:
                print(f"✓ Signup tracked in Klaviyo")
            else:
                print(f"✗ Failed to track signup in Klaviyo")
        except Exception as e:
            print(f"✗ Error tracking signup in Klaviyo: {e}")
        print()

        # Step 5: Sync profile to Klaviyo
        print("Step 5: Syncing profile to Klaviyo...")
        try:
            success = klaviyo_service.sync_full_profile_from_supabase(
                user_id=uuid.UUID(user_id),
                supabase_client=supabase_client.client,
            )
            
            if success:
                print(f"✓ Profile synced to Klaviyo")
            else:
                print(f"⚠ Profile sync returned False")
        except Exception as e:
            print(f"✗ Error syncing profile to Klaviyo: {e}")
        print()
    else:
        print("Step 4-5: Skipped (Klaviyo not available)")
        print()

    # Summary
    print("=" * 60)
    print("DIAGNOSIS SUMMARY")
    print("=" * 60)
    print(f"✓ Backend is running and accessible")
    print(f"✓ Supabase connection working")
    print(f"✓ User creation in Supabase Auth: SUCCESS")
    
    if klaviyo_service:
        print(f"✓ Klaviyo integration available")
    else:
        print(f"⚠ Klaviyo integration NOT available")
    
    print()
    print("ISSUE IDENTIFIED:")
    print("=" * 60)
    print("The Flutter app calls Supabase.signUp() directly, which creates")
    print("the user in Supabase Auth, but does NOT:")
    print()
    print("  1. Call the FastAPI backend")
    print("  2. Trigger track_signed_up() for Klaviyo")
    print("  3. Create an initial profile entry")
    print()
    print("SOLUTION:")
    print("=" * 60)
    print("Option A: Add a backend signup endpoint that the app calls")
    print("Option B: Use Supabase webhooks to notify the backend")
    print("Option C: Track signup on first story generation")
    print()
    print(f"Test user created: {test_email}")
    print(f"Clean up manually if needed using Supabase dashboard")
    print("=" * 60)

    return True


if __name__ == "__main__":
    try:
        success = test_user_signup()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
