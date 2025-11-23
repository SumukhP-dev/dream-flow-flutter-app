"""
Locust load test for /api/v1/story endpoint.

Usage:
    locust -f locustfile.py --host=http://localhost:8000 --users=200 --spawn-rate=10 --run-time=5m
    locust -f locustfile.py --host=http://localhost:8000 --users=200 --spawn-rate=10 --run-time=5m --headless
"""

import json
import random
import uuid
from locust import HttpUser, task, between
from typing import Dict, Any


class StoryUser(HttpUser):
    """Simulates a user making story generation requests."""
    
    wait_time = between(1, 3)  # Wait 1-3 seconds between requests
    
    # Sample prompts for testing
    SAMPLE_PROMPTS = [
        "A peaceful walk through a forest at sunset",
        "A cozy cabin by a lake with mountains in the background",
        "A gentle rain falling on a garden",
        "A starry night sky over a calm ocean",
        "A warm fireplace in a quiet room",
        "A meadow filled with wildflowers",
        "A serene mountain landscape at dawn",
        "A peaceful beach with gentle waves",
    ]
    
    # Sample themes
    THEMES = [
        "calm",
        "peaceful",
        "serene",
        "tranquil",
        "relaxing",
    ]
    
    def on_start(self):
        """Called when a simulated user starts."""
        self.user_id = str(uuid.uuid4())
    
    @task(1)
    def generate_story(self):
        """Generate a story - this is the main load test task."""
        prompt = random.choice(self.SAMPLE_PROMPTS)
        theme = random.choice(self.THEMES)
        
        payload: Dict[str, Any] = {
            "prompt": prompt,
            "theme": theme,
            "target_length": 400,
            "num_scenes": 4,
            "user_id": self.user_id,
        }
        
        headers = {
            "Content-Type": "application/json",
            "X-Request-ID": str(uuid.uuid4()),
        }
        
        with self.client.post(
            "/api/v1/story",
            json=payload,
            headers=headers,
            catch_response=True,
            name="POST /api/v1/story"
        ) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    # Verify response structure
                    if "story_text" in data and "assets" in data:
                        response.success()
                    else:
                        response.failure(f"Invalid response structure: {list(data.keys())}")
                except json.JSONDecodeError:
                    response.failure("Invalid JSON response")
            elif response.status_code == 422:
                # Guardrail violations are expected in some cases
                response.failure(f"Guardrail violation: {response.text}")
            elif response.status_code == 503:
                # Service unavailable - might be rate limiting
                response.failure(f"Service unavailable: {response.text}")
            else:
                response.failure(f"Unexpected status code: {response.status_code}")

