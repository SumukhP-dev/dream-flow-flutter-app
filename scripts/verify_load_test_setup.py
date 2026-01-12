"""
Quick verification script to check if load testing setup is correct.

Usage:
    python verify_load_test_setup.py
"""

import sys
from pathlib import Path


def check_imports():
    """Check if all required packages are installed."""
    print("Checking required packages...")
    
    required = {
        "locust": "locust",
        "psutil": "psutil",
        "gputil": "gputil (optional for GPU monitoring)",
    }
    
    missing = []
    for package, name in required.items():
        try:
            __import__(package)
            print(f"  [OK] {name}")
        except ImportError:
            print(f"  [FAIL] {name} - NOT INSTALLED")
            if package != "gputil":
                missing.append(package)
    
    return len(missing) == 0


def check_files():
    """Check if all required files exist."""
    print("\nChecking required files...")
    
    files = [
        "locustfile.py",
        "monitor_resources.py",
        "run_load_test.py",
    ]
    
    all_exist = True
    for file in files:
        path = Path(file)
        if path.exists():
            print(f"  [OK] {file}")
        else:
            print(f"  [FAIL] {file} - NOT FOUND")
            all_exist = False
    
    return all_exist


def check_services_patch():
    """Check if MoviePy resource leak fix is in place."""
    print("\nChecking MoviePy resource leak fix...")
    
    services_file = Path("app/services.py")
    if not services_file.exists():
        print("  ✗ app/services.py not found")
        return False
    
    content = services_file.read_text()
    
    checks = [
        ("try:", "Try block for error handling"),
        ("finally:", "Finally block for cleanup"),
        ("audio.close()", "AudioFileClip cleanup"),
        ("clip.close()", "ImageClip cleanup"),
        ("video.close()", "Video clip cleanup"),
    ]
    
    all_good = True
    for pattern, description in checks:
        if pattern in content:
            print(f"  [OK] {description}")
        else:
            print(f"  [FAIL] {description} - NOT FOUND")
            all_good = False
    
    return all_good


def main():
    print("=" * 60)
    print("Load Testing Setup Verification")
    print("=" * 60)
    
    checks = [
        ("Package Imports", check_imports),
        ("Required Files", check_files),
        ("MoviePy Resource Leak Fix", check_services_patch),
    ]
    
    results = []
    for name, check_func in checks:
        try:
            result = check_func()
            results.append((name, result))
        except Exception as e:
            print(f"  ERROR: {e}")
            results.append((name, False))
    
    print("\n" + "=" * 60)
    print("Summary")
    print("=" * 60)
    
    all_passed = True
    for name, result in results:
        status = "[PASS]" if result else "[FAIL]"
        print(f"{status} - {name}")
        if not result:
            all_passed = False
    
    print("=" * 60)
    
    if all_passed:
        print("\n[SUCCESS] All checks passed! Load testing setup is ready.")
        print("\nNext steps:")
        print("  1. Start your API server: uvicorn app.main:app --host 0.0.0.0 --port 8000")
        print("  2. Run load test: python run_load_test.py --host=http://localhost:8000 --users=200 --duration=300")
        return 0
    else:
        print("\n[ERROR] Some checks failed. Please fix the issues above.")
        print("\nTo install missing packages:")
        print("  pip install -r requirements.txt")
        return 1


if __name__ == "__main__":
    sys.exit(main())

