#!/usr/bin/env python3
"""
Quick diagnostic script to check why mock values are being used.
Run this on the backend laptop to see the current configuration.
"""

import os
import sys

def check_config():
    print("=" * 60)
    print("Backend Configuration Check")
    print("=" * 60)
    print()
    
    # Check HUGGINGFACE_API_URL
    hf_url = os.getenv("HUGGINGFACE_API_URL")
    if hf_url:
        print(f"❌ HUGGINGFACE_API_URL is set to: {hf_url}")
        if "localhost" in hf_url or "127.0.0.1" in hf_url or ":8000" in hf_url:
            print("   ⚠️  This points to a MOCK SERVICE! That's why you see [MOCK STORY]")
            print("   💡 Solution: Unset this variable or set it to empty string")
        else:
            print("   ✅ This looks like a real HuggingFace URL")
    else:
        print("✅ HUGGINGFACE_API_URL is NOT set (this is correct for real HuggingFace API)")
    
    print()
    
    # Check HUGGINGFACE_API_TOKEN
    hf_token = os.getenv("HUGGINGFACE_API_TOKEN")
    if hf_token:
        if hf_token.startswith("hf_"):
            print(f"✅ HUGGINGFACE_API_TOKEN is set (starts with 'hf_')")
        else:
            print(f"⚠️  HUGGINGFACE_API_TOKEN is set but doesn't look like a valid token")
    else:
        print("❌ HUGGINGFACE_API_TOKEN is NOT set")
        print("   💡 You need a real HuggingFace token to use the real API")
    
    print()
    
    # Check LOCAL_INFERENCE
    local_inf = os.getenv("LOCAL_INFERENCE", "false").lower()
    if local_inf == "true":
        print("ℹ️  LOCAL_INFERENCE=true (using local models, not HuggingFace)")
    else:
        print("ℹ️  LOCAL_INFERENCE=false (using cloud HuggingFace API)")
    
    print()
    print("=" * 60)
    print("Summary:")
    print("=" * 60)
    
    if hf_url and ("localhost" in hf_url or "127.0.0.1" in hf_url or ":8000" in hf_url):
        print("❌ PROBLEM FOUND: HUGGINGFACE_API_URL points to mock service")
        print()
        print("To fix on Linux/Mac:")
        print("  unset HUGGINGFACE_API_URL")
        print("  export HUGGINGFACE_API_TOKEN=hf_your_token_here")
        print("  # Then restart your backend server")
        print()
        print("To fix on Windows PowerShell:")
        print("  $env:HUGGINGFACE_API_URL = \"\"")
        print("  $env:HUGGINGFACE_API_TOKEN = \"hf_your_token_here\"")
        print("  # Then restart your backend server")
    elif not hf_url and hf_token:
        print("✅ Configuration looks correct for real HuggingFace API")
        print("   If you still see mock values, check backend logs for errors")
    elif not hf_token:
        print("⚠️  Missing HUGGINGFACE_API_TOKEN")
        print("   Get a token from: https://huggingface.co/settings/tokens")
    else:
        print("✅ Configuration looks okay")

if __name__ == "__main__":
    check_config()

