#!/usr/bin/env python3
"""
Quick test to verify Dream Flow performance optimizations
"""
import asyncio
import json
import time
from datetime import datetime
import httpx

async def test_story_generation():
    """Test story generation with performance optimizations."""
    
    print("🧪 Testing Dream Flow Performance Optimizations")
    print("=" * 50)
    
    # Test backend health
    print("1. Testing backend health...")
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get("http://localhost:8080/health")
            if response.status_code == 200:
                health_data = response.json()
                print(f"✅ Backend is healthy: {health_data['status']}")
                print(f"   Story model: {health_data['story_model']}")
            else:
                print(f"❌ Backend health check failed: {response.status_code}")
                return
    except Exception as e:
        print(f"❌ Cannot connect to backend: {e}")
        return
    
    # Test story generation with fast settings
    print("\n2. Testing fast story generation...")
    
    story_request = {
        "prompt": "A gentle fox named Nova explores a starlit forest",
        "theme": "Study Grove",
        "target_length": 300,  # Reduced from 500
        "num_scenes": 2,       # Reduced from 4
        "voice": "alloy",
        "primary_language": "en",
        "secondary_language": "es",
        "profile": {
            "mood": "sleepy and hopeful",
            "ritual": "warm bath then story time",
            "preferences": ["gentle animals", "friendship"],
            "favorite_characters": ["Nova the fox"],
            "calming_elements": ["starlight", "soft clouds"]
        }
    }
    
    start_time = time.time()
    
    try:
        async with httpx.AsyncClient(timeout=600.0) as client:  # 10 minute timeout
            print(f"📤 Sending story request at {datetime.now().strftime('%H:%M:%S')}")
            
            response = await client.post(
                "http://localhost:8080/api/v1/story",
                json=story_request,
                headers={"Content-Type": "application/json"}
            )
            
            end_time = time.time()
            duration = end_time - start_time
            
            print(f"📥 Response received at {datetime.now().strftime('%H:%M:%S')}")
            print(f"⏱️  Total duration: {duration:.2f} seconds ({duration/60:.2f} minutes)")
            
            if response.status_code == 200:
                story_data = response.json()
                print(f"✅ Story generation successful!")
                print(f"   Story length: {len(story_data.get('story', ''))} characters")
                print(f"   Audio URL: {story_data.get('audio_url', 'None')}")
                print(f"   Frames: {len(story_data.get('frames', []))} images")
                print(f"   Session ID: {story_data.get('session_id', 'None')}")
                
                # Performance analysis
                if duration < 60:  # Under 1 minute
                    print(f"🚀 EXCELLENT: Story generated in under 1 minute!")
                elif duration < 180:  # Under 3 minutes  
                    print(f"✅ GOOD: Story generated in under 3 minutes")
                elif duration < 300:  # Under 5 minutes
                    print(f"⚠️  OK: Story generated in under 5 minutes")
                else:
                    print(f"🐌 SLOW: Story took over 5 minutes")
                    
            else:
                print(f"❌ Story generation failed: {response.status_code}")
                print(f"   Response: {response.text[:500]}...")
                
    except asyncio.TimeoutError:
        duration = time.time() - start_time
        print(f"⏰ Request timed out after {duration:.2f} seconds")
    except Exception as e:
        duration = time.time() - start_time
        print(f"❌ Error after {duration:.2f} seconds: {e}")

if __name__ == "__main__":
    asyncio.run(test_story_generation())