#!/usr/bin/env python3
"""Test script to debug story generation endpoint."""

import json
import requests
import sys
import os

# Set environment variables for testing
os.environ["LOW_MEMORY_MODE"] = "true"
os.environ["LOCAL_INFERENCE"] = "true"

def test_story_generation():
    """Test the story generation endpoint."""
    url = "http://localhost:8080/api/v1/story"
    
    test_request = {
        "prompt": "Tell me a short bedtime story about a fox",
        "target_length": 200,
        "num_scenes": 2,
        "theme": "bedtime",
        "mood": "calm"
    }
    
    print("=" * 60)
    print("Testing Story Generation Endpoint")
    print("=" * 60)
    print(f"URL: {url}")
    print(f"Request: {json.dumps(test_request, indent=2)}")
    print()
    
    try:
        print("Sending request...")
        response = requests.post(
            url,
            json=test_request,
            timeout=600,  # 10 minutes timeout
            headers={"Content-Type": "application/json"}
        )
        
        print(f"Status Code: {response.status_code}")
        print(f"Headers: {dict(response.headers)}")
        print()
        
        if response.status_code == 200:
            try:
                data = response.json()
                print("[SUCCESS] Story generated!")
                print(f"Session ID: {data.get('session_id', 'N/A')}")
                print(f"Story Length: {len(data.get('story_text', ''))} chars")
                print(f"Theme: {data.get('theme', 'N/A')}")
                assets = data.get('assets', {})
                print(f"Has Audio: {bool(assets.get('audio'))}")
                print(f"Has Video: {bool(assets.get('video'))}")
                print(f"Frames: {len(assets.get('frames', []))}")
                print()
                print("Story Preview:")
                story_text = data.get('story_text', '')
                if story_text:
                    print(story_text[:300] + ("..." if len(story_text) > 300 else ""))
                else:
                    print("[WARNING] Story text is empty!")
            except json.JSONDecodeError as e:
                print(f"[ERROR] Failed to parse JSON response: {e}")
                print(f"Response text: {response.text[:500]}")
        else:
            print(f"[ERROR] HTTP {response.status_code}")
            try:
                error_data = response.json()
                print(f"Error details: {json.dumps(error_data, indent=2)}")
            except:
                print(f"Response text: {response.text[:500]}")
                
    except requests.exceptions.Timeout:
        print("[ERROR] Request timed out (>10 minutes)")
        print("This might indicate the server is hanging or very slow")
    except requests.exceptions.ConnectionError as e:
        print(f"[ERROR] Connection error: {e}")
        print("Make sure the backend server is running on port 8080")
    except Exception as e:
        print(f"[ERROR] Unexpected error: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_story_generation()

