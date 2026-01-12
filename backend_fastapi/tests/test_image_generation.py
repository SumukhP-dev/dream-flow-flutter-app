#!/usr/bin/env python3
"""
Test script to debug and verify image generation fixes.
"""

import asyncio
import sys
import os
from pathlib import Path

# Add the backend_fastapi directory to the Python path
backend_path = Path(__file__).parent / "backend_fastapi"
sys.path.insert(0, str(backend_path))

async def test_image_generation():
    """Test the image generation pipeline with improved settings."""
    
    print("🧪 Testing improved image generation...")
    
    try:
        from app.core.prompting import PromptBuilder, PromptContext
        from app.core.local_services import LocalVisualGenerator
        
        # Create test story and context
        story = """In a magical forest glade, a young fox named Nova discovers glowing fireflies dancing in the moonlight. The fireflies whisper ancient secrets about dreams and starlight."""
        
        context = PromptContext(
            prompt="Illustrate Nova's magical adventure with fireflies",
            theme="Dreamy Forest",
            target_length=200,
            profile=None,
        )
        
        # Test with improved configuration
        builder = PromptBuilder()
        generator = LocalVisualGenerator(prompt_builder=builder)
        
        print("📝 Generating single test frame...")
        print(f"   Story: {story[:80]}...")
        
        # Generate just one frame for testing
        frames = await generator.create_frames_progressive(
            story,
            context,
            num_scenes=1,  # Just one for testing
            storage_prefix="test_",
            ultra_fast_mode=False,  # Use normal quality
        )
        
        print("✅ Frame generation completed!")
        print(f"📁 Generated {len(frames)} frame(s):")
        for i, url in enumerate(frames, 1):
            print(f"   {i}. {url}")
        
        return frames
        
    except ImportError as e:
        print(f"❌ Import error: {e}")
        print("💡 Make sure you're in the right directory and dependencies are installed")
        return []
    except Exception as e:
        print(f"❌ Generation error: {e}")
        print(f"🔍 Error type: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        return []

if __name__ == "__main__":
    print("🖼️ Image Generation Test Script")
    print("=" * 50)
    
    # Run the test
    frames = asyncio.run(test_image_generation())
    
    if frames:
        print("\n🎉 Test completed successfully!")
        print(f"✅ Generated {len(frames)} frame(s)")
        print("\n📋 Next steps:")
        print("1. Check the generated images in backend_fastapi/storage/frames/")
        print("2. Compare quality with previous images")
        print("3. If satisfied, restart the backend to apply changes")
    else:
        print("\n❌ Test failed - check errors above")
        print("\n🔧 Troubleshooting:")
        print("1. Ensure torch and diffusers are installed")
        print("2. Check if the Stable Diffusion model can be loaded")
        print("3. Verify sufficient disk space and memory")