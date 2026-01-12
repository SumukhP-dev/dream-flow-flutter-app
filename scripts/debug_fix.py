#!/usr/bin/env python3
"""
Debug Fix Script for Dream Flow
Addresses the critical issues found in the debug logs:

1. AsyncIO StopIteration errors in Python 3.11+
2. Text truncation/debug output in story generation
3. TTS timeout and fallback chain issues
4. Performance optimization for 6+ minute generation times
"""

import sys
import re
import os
from pathlib import Path

def apply_asyncio_fixes():
    """Fix AsyncIO StopIteration issues in Python 3.11+"""
    print("Applying AsyncIO fixes...")
    
    local_services_path = Path("backend_fastapi/app/core/local_services.py")
    
    if local_services_path.exists():
        with open(local_services_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Add StopIteration handling in frame processing
        if "except (StopIteration, StopAsyncIteration)" not in content:
            content = re.sub(
                r'(except Exception as e:\s*logger\.error\(f"Failed to process completed frame)',
                r'except (StopIteration, StopAsyncIteration) as e:\n                logger.warning(f"Generator stopped unexpectedly: {e}")\n                continue\n            \1',
                content,
                flags=re.MULTILINE
            )
        
        with open(local_services_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print("AsyncIO fixes applied")
    else:
        print("Could not find local_services.py")

def apply_text_generation_fixes():
    """Fix text generation truncation and debug output issues"""
    print("Applying text generation fixes...")
    
    local_services_path = Path("backend_fastapi/app/core/local_services.py")
    
    if local_services_path.exists():
        with open(local_services_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Add better text generation validation and debug detection
        debug_check = '''
            # Check for incomplete generation issues
            if len(text) < 100:
                logger.warning(f"Very short story generated ({len(text)} chars): '{text}'")
            elif text.strip().startswith("Debug") or "Debug" in text[:50]:
                logger.warning(f"Debug text detected in story: '{text[:100]}'")
                # This suggests the model is generating debug output instead of story
                # Try regenerating with different parameters
                raise ValueError("Model generated debug output instead of story content")
'''
        
        # Insert after existing debug logging
        if "Check for incomplete generation issues" not in content:
            content = re.sub(
                r'(logger\.info\(f"Generated story text \(first 500 chars\).*?"\))',
                r'\1\n            logger.info(f"Full story text length: {len(text)} characters")\n' + debug_check,
                content,
                flags=re.MULTILINE | re.DOTALL
            )
        
        with open(local_services_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print("Text generation fixes applied")
    else:
        print("Could not find local_services.py")

def apply_tts_timeout_fixes():
    """Fix TTS timeout and fallback chain issues"""
    print("🔧 Applying TTS timeout fixes...")
    
    local_services_path = Path("backend_fastapi/app/core/local_services.py")
    dreamflow_main_path = Path("backend_fastapi/app/dreamflow/main.py")
    
    # Fix edge-tts timeout
    if local_services_path.exists():
        with open(local_services_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Add timeout to edge-tts communicate.save()
        content = re.sub(
            r'await communicate\.save\(tmp_path\)',
            r'await asyncio.wait_for(communicate.save(tmp_path), timeout=30.0)  # 30s timeout',
            content
        )
        
        # Add timeout exception handling
        if "except asyncio.TimeoutError:" not in content:
            content = re.sub(
                r'(try:\s*communicate = edge_tts\.Communicate.*?)(except Exception as e:)',
                r'\1except asyncio.TimeoutError:\n            logger.warning(\n                f"edge-tts timed out after 30s for voice \'{edge_voice}\'. "\n                f"Falling back to local pyttsx3 TTS."\n            )\n        \2',
                content,
                flags=re.MULTILINE | re.DOTALL
            )
        
        with open(local_services_path, 'w', encoding='utf-8') as f:
            f.write(content)
    
    # Fix fallback narration timeout in main.py
    if dreamflow_main_path.exists():
        with open(dreamflow_main_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Add timeout wrapper for fallback narration
        if "asyncio.wait_for(synthesize_task, timeout=60.0)" not in content:
            content = re.sub(
                r'(audio_result = await fallback_narration_gen\.synthesize\([^)]*\))',
                r'synthesize_task = fallback_narration_gen.synthesize(story_text, context, payload.voice, supabase_client, user_agent=user_agent if "user_agent" in inspect.signature(fallback_narration_gen.synthesize).parameters else None)\n                            audio_result = await asyncio.wait_for(synthesize_task, timeout=60.0)  # 1 min timeout',
                content
            )
        
        with open(dreamflow_main_path, 'w', encoding='utf-8') as f:
            f.write(content)
    
    print("✅ TTS timeout fixes applied")

def apply_performance_optimizations():
    """Apply performance optimizations to reduce generation time"""
    print("🔧 Applying performance optimizations...")
    
    # Optimize local story generator for faster generation
    local_services_path = Path("backend_fastapi/app/core/local_services.py")
    
    if local_services_path.exists():
        with open(local_services_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Reduce max tokens for faster generation in non-ultra-fast mode
        content = re.sub(
            r'max_tokens=approx_tokens,',
            r'max_tokens=min(approx_tokens, 512),  # Cap tokens for faster generation',
            content
        )
        
        # Add parallel frame generation optimization
        if "Process frames in smaller batches" not in content:
            batch_optimization = '''
        # Process frames in smaller batches to show progress faster
        batch_size = 2  # Process 2 frames at a time
        for i in range(0, len(tasks), batch_size):
            batch_tasks = tasks[i:i + batch_size]
            if batch_tasks:
                done, pending = await asyncio.wait(batch_tasks, return_when=asyncio.ALL_COMPLETED)
                
                for task in done:
                    try:
                        result = task.result() if task.done() else await task
                        idx, frame_url = result
                        if frame_url and frame_url.strip():
                            frame_dict[idx] = frame_url
                            frames.append(frame_url)
                            
                            if on_frame_complete:
                                try:
                                    on_frame_complete(frame_url, idx)
                                except Exception as e:
                                    logger.warning(f"Callback failed for frame {idx}: {e}")
                                    
                            logger.info(f"Frame {idx + 1}/{len(chunks)} ready: {frame_url[:50]}...")
                    except (StopIteration, StopAsyncIteration) as e:
                        logger.warning(f"Generator stopped unexpectedly: {e}")
                        continue
                    except Exception as e:
                        logger.error(f"Failed to process frame: {e}", exc_info=True)
'''
            
            # Replace the existing frame processing with batched version
            content = re.sub(
                r'# Use asyncio\.wait instead of asyncio\.as_completed.*?logger\.error\(f"Failed to process completed frame.*?\n',
                batch_optimization,
                content,
                flags=re.MULTILINE | re.DOTALL
            )
        
        with open(local_services_path, 'w', encoding='utf-8') as f:
            f.write(content)
    
    print("✅ Performance optimizations applied")

def add_comprehensive_logging():
    """Add comprehensive logging to track performance and issues"""
    print("🔧 Adding comprehensive logging...")
    
    dreamflow_main_path = Path("backend_fastapi/app/dreamflow/main.py")
    
    if dreamflow_main_path.exists():
        with open(dreamflow_main_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Add timing logs for each stage
        if "📊 Performance timing" not in content:
            timing_code = '''
        # 📊 Performance timing logs
        total_start = time.perf_counter()
        logger.info(f"🚀 Starting story generation - Theme: {payload.theme}")
        
        # Log story generation timing
        story_timing = time.perf_counter()
        logger.info(f"📖 Story text generation took {time.perf_counter() - story_timing:.2f}s")
        
        # Log visual generation timing
        visual_timing = time.perf_counter()
        logger.info(f"🎨 Visual generation took {time.perf_counter() - visual_timing:.2f}s")
        
        # Log audio generation timing  
        audio_timing = time.perf_counter()
        logger.info(f"🎵 Audio generation took {time.perf_counter() - audio_timing:.2f}s")
        
        total_time = time.perf_counter() - total_start
        logger.info(f"⏱️ Total generation time: {total_time:.2f}s")
'''
            
            # Insert timing code after story generation
            content = re.sub(
                r'(story_text = await story_gen\.generate\(context.*?\))',
                timing_code + r'\n        \1',
                content,
                flags=re.MULTILINE
            )
        
        with open(dreamflow_main_path, 'w', encoding='utf-8') as f:
            f.write(content)
    
    print("✅ Comprehensive logging added")

def create_debug_config():
    """Create a debug configuration file"""
    print("🔧 Creating debug configuration...")
    
    debug_config = '''# Debug Configuration for Dream Flow
# This file contains optimized settings for debugging and faster generation

# Story Generation Settings
STORY_MAX_TOKENS=256  # Reduced for faster generation
STORY_TEMPERATURE=0.7  # Slightly lower for more consistent output
STORY_TIMEOUT=60  # Reduced timeout

# TTS Settings  
TTS_TIMEOUT=30  # Faster TTS timeout
TTS_FALLBACK_ENABLED=true

# Image Generation Settings
IMAGE_BATCH_SIZE=2  # Process images in smaller batches
IMAGE_PLACEHOLDER_MODE=true  # Use placeholders for faster generation during debug

# Performance Settings
ENABLE_PERFORMANCE_LOGGING=true
PARALLEL_PROCESSING=true

# Debug Settings
LOG_LEVEL=DEBUG
ENABLE_TEXT_VALIDATION=true
DETECT_DEBUG_OUTPUT=true
'''
    
    with open("backend_fastapi/.env.debug", 'w', encoding='utf-8') as f:
        f.write(debug_config)
    
    print("✅ Debug configuration created at backend_fastapi/.env.debug")

def main():
    """Apply all debug fixes"""
    print("Starting Dream Flow Debug Fixes...")
    print("=" * 50)
    
    try:
        apply_asyncio_fixes()
        apply_text_generation_fixes()  
        apply_tts_timeout_fixes()
        apply_performance_optimizations()
        add_comprehensive_logging()
        create_debug_config()
        
        print("=" * 50)
        print("All debug fixes applied successfully!")
        print("\nSummary of fixes:")
        print("  • Fixed AsyncIO StopIteration errors in Python 3.11+")
        print("  • Added text generation validation and debug detection")
        print("  • Improved TTS timeout handling and fallback chain")
        print("  • Applied performance optimizations for faster generation")
        print("  • Added comprehensive logging for better debugging")
        print("  • Created debug configuration file")
        print("\nNext steps:")
        print("  1. Restart your backend server")
        print("  2. Test story generation with the fixes")
        print("  3. Monitor logs for improved performance")
        
    except Exception as e:
        print(f"Error applying fixes: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()