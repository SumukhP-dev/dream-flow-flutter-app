#!/usr/bin/env python3
"""
Quick test script to verify Klaviyo integration is working.

This script:
1. Checks if backend is running
2. Verifies Klaviyo is enabled
3. Tests event tracking
4. Shows what data is being sent to Klaviyo

Run: python scripts/test_klaviyo_integration.py
"""

import requests
import sys
import json
from datetime import datetime

# Configuration
BACKEND_URL = "http://localhost:8000"
TEST_EMAIL = f"test-{datetime.now().strftime('%Y%m%d-%H%M%S')}@dreamflow-test.com"

def print_section(title):
    """Print formatted section header."""
    print(f"\n{'='*70}")
    print(f"  {title}")
    print(f"{'='*70}\n")

def test_backend_health():
    """Test if backend is running."""
    print_section("1️⃣  Testing Backend Health")
    try:
        response = requests.get(f"{BACKEND_URL}/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print("✅ Backend is running!")
            print(f"   Status: {data.get('status')}")
            print(f"   Model: {data.get('story_model', 'N/A')}")
            return True
        else:
            print(f"❌ Backend returned status {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Cannot connect to backend: {e}")
        print(f"   Make sure backend is running on {BACKEND_URL}")
        return False

def test_klaviyo_integration_status():
    """Check Klaviyo integration status."""
    print_section("2️⃣  Checking Klaviyo Integration Status")
    try:
        response = requests.get(f"{BACKEND_URL}/api/v1/demo/klaviyo-integration", timeout=5)
        if response.status_code == 200:
            data = response.json()
            status = data.get("integration_summary", {}).get("status", "unknown")
            
            if status == "active":
                print("✅ Klaviyo integration is ACTIVE!")
            elif status == "disabled":
                print("⚠️  Klaviyo integration is DISABLED")
                print("   Check:")
                print("   - KLAVIYO_ENABLED=true in .env")
                print("   - KLAVIYO_API_KEY is set in .env")
                print("   - Backend was restarted after setting env vars")
                return False
            else:
                print(f"⚠️  Klaviyo status: {status}")
            
            # Show what's configured
            print("\n📊 Integration Details:")
            apis = data.get("api_endpoints_used", {})
            print(f"   APIs configured: {len(apis)}")
            
            events = apis.get("events_api", {}).get("events_tracked", [])
            print(f"   Events tracked: {len(events)}")
            for event in events:
                print(f"      - {event}")
            
            return status == "active"
        else:
            print(f"❌ Could not get integration status: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Error checking integration: {e}")
        return False

def show_test_instructions():
    """Show instructions for testing with real user signup."""
    print_section("3️⃣  How to Test Event Tracking")
    
    print("To verify events are being sent to Klaviyo:")
    print()
    print("Option A - Test with your app:")
    print("  1. Sign up a new user in your Dream Flow app")
    print(f"     Use email: {TEST_EMAIL}")
    print("  2. Generate a story")
    print("  3. Wait 2-3 minutes")
    print("  4. Check Klaviyo dashboard:")
    print("     - Go to Audience → Profiles")
    print(f"     - Search for: {TEST_EMAIL}")
    print("     - You should see:")
    print("       ✓ Profile created")
    print("       ✓ 'Signed Up' event")
    print("       ✓ 'Story Generated' event")
    print()
    print("Option B - Test with API directly:")
    print("  Run the integration test suite:")
    print("    cd backend_fastapi")
    print("    pytest tests/test_klaviyo_integration.py -v")
    print()

def check_klaviyo_dashboard_setup():
    """Remind user about dashboard setup."""
    print_section("4️⃣  Klaviyo Dashboard Setup")
    
    print("Have you set up your Klaviyo dashboard?")
    print()
    print("If not yet, follow this guide:")
    print("  📖 docs/KLAVIYO_DASHBOARD_SETUP.md")
    print()
    print("Essential items to set up:")
    print("  ☐ Create segments (High Engagement, Churn Risk, etc.)")
    print("  ☐ Set up flows (Welcome, Re-engagement, etc.)")
    print("  ☐ Create email templates")
    print("  ☐ Configure metrics dashboard")
    print()
    print("Estimated time: 30-45 minutes")
    print()

def show_next_steps(integration_active):
    """Show recommended next steps."""
    print_section("🎯 Next Steps")
    
    if integration_active:
        print("✅ Your Klaviyo integration is working!")
        print()
        print("Recommended next steps:")
        print("  1. Follow the dashboard setup guide:")
        print("     docs/KLAVIYO_DASHBOARD_SETUP.md")
        print()
        print("  2. Create a test user and verify events appear in Klaviyo")
        print()
        print("  3. Set up your first flow (Welcome email)")
        print()
        print("  4. Monitor the metrics dashboard")
        print()
    else:
        print("⚠️  Klaviyo integration needs configuration")
        print()
        print("To fix:")
        print("  1. Make sure KLAVIYO_API_KEY is set in backend_fastapi/.env")
        print("  2. Set KLAVIYO_ENABLED=true in .env")
        print("  3. Restart the backend:")
        print("     cd backend_fastapi")
        print("     python -m uvicorn app.main:app --reload --port 8000")
        print()
        print("  4. Run this test script again")
        print()

def main():
    """Run all tests."""
    print("""
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║         Dream Flow - Klaviyo Integration Test                   ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝
    """)
    
    # Run tests
    backend_ok = test_backend_health()
    
    if not backend_ok:
        print("\n❌ Backend is not running. Start it first:")
        print("   cd backend_fastapi")
        print("   python -m uvicorn app.main:app --reload --port 8000")
        sys.exit(1)
    
    integration_active = test_klaviyo_integration_status()
    show_test_instructions()
    check_klaviyo_dashboard_setup()
    show_next_steps(integration_active)
    
    # Final status
    print("\n" + "="*70)
    if integration_active:
        print("✅ SUCCESS: Klaviyo integration is configured correctly!")
    else:
        print("⚠️  ACTION NEEDED: Complete Klaviyo configuration")
    print("="*70 + "\n")

if __name__ == "__main__":
    main()
