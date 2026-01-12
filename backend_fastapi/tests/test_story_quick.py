#!/usr/bin/env python3
"""Quick story generation test for Klaviyo event tracking"""

import requests
import json
import uuid

# Generate a valid UUID for testing
test_user_id = str(uuid.uuid4())

payload = {
    'theme': 'Ocean Adventure',
    'prompt': 'A friendly dolphin exploring coral reefs',
    'num_scenes': 3,
    'mood': 'excited',
    'user_id': test_user_id,
    'email': 'judge@klaviyo-hackathon.com'
}

print('Sending story generation request...')
print(f'   Email: {payload["email"]}')
print(f'   User ID: {test_user_id}')
print(f'   Theme: {payload["theme"]}')
print(f'   Scenes: {payload["num_scenes"]}')
print('\nGenerating story (this may take 30-60 seconds)...\n')

try:
    r = requests.post('http://localhost:8000/api/v1/story', json=payload, timeout=120)
    
    if r.status_code < 400:
        print(f'\n✓ SUCCESS! Status: {r.status_code}')
        result = r.json()
        print(f'\nResults:')
        print(f'   Story ID: {result.get("story_id", "N/A")}')
        print(f'   Theme: {result.get("theme", "N/A")}')
        print(f'   Scenes: {len(result.get("frames", []))}')
        print(f'   Text length: {len(result.get("story_text", ""))} characters')
        
        print(f'\n*** CHECK BACKEND TERMINAL FOR KLAVIYO EVENT TRACKING! ***')
        print(f'    Look for: "KLAVIYO EVENT TRACKED: Story Generated"')
        print(f'\n*** NOW CHECK KLAVIYO DASHBOARD: ***')
        print(f'    1. Go to https://www.klaviyo.com')
        print(f'    2. Analytics -> Metrics')
        print(f'    3. Find "Story Generated" event')
        print(f'    4. Verify event properties (theme, mood, etc.)')
        print(f'\n    Email to search: {payload["email"]}')
    else:
        print(f'\nX FAILED! Status: {r.status_code}')
        print(f'Response: {r.text[:500]}')
        
except requests.exceptions.Timeout:
    print('\nX REQUEST TIMEOUT (>120s)')
    print('Story generation is taking longer than expected.')
    print('This is normal for first request (model loading).')
except Exception as e:
    print(f'\nX ERROR: {e}')
