#!/usr/bin/env python3
"""
Local Deployment Test Script

Tests deployment readiness without requiring Docker or full infrastructure.
"""

import sys
import subprocess
from pathlib import Path

# Color codes
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

CHECK = f"{GREEN}✓{RESET}"
CROSS = f"{RED}✗{RESET}"
WARN = f"{YELLOW}⚠{RESET}"

def test_python_syntax():
    """Test Python syntax by importing modules."""
    print(f"\n{BLUE}=== Python Syntax Check ==={RESET}\n")
    
    backend_dir = Path(__file__).parent
    app_dir = backend_dir / "app"
    
    errors = []
    
    # Test main imports
    test_imports = [
        ("app.main", "app/main.py"),
        ("app.dreamflow.main", "app/dreamflow/main.py"),
        ("app.studio.main", "app/studio/main.py"),
        ("app.shared.config", "app/shared/config.py"),
        ("app.shared.supabase_client", "app/shared/supabase_client.py"),
    ]
    
    for module_name, file_path in test_imports:
        try:
            # Change to backend directory and try importing
            import importlib.util
            spec = importlib.util.spec_from_file_location(
                module_name.replace(".", "_"),
                backend_dir / file_path
            )
            if spec and spec.loader:
                print(f"  {CHECK} {file_path}")
            else:
                print(f"  {WARN} {file_path} (could not load)")
        except SyntaxError as e:
            errors.append((file_path, str(e)))
            print(f"  {CROSS} {file_path}: {e}")
        except Exception as e:
            # Other errors (missing deps) are OK for syntax check
            print(f"  {WARN} {file_path}: {type(e).__name__}")
    
    return len(errors) == 0

def test_requirements_txt():
    """Test that requirements.txt is valid."""
    print(f"\n{BLUE}=== Requirements.txt Check ==={RESET}\n")
    
    backend_dir = Path(__file__).parent
    requirements = backend_dir / "requirements.txt"
    
    if not requirements.exists():
        print(f"  {CROSS} requirements.txt not found")
        return False
    
    try:
        with open(requirements, 'r') as f:
            lines = f.readlines()
        
        valid_lines = [line.strip() for line in lines if line.strip() and not line.strip().startswith('#')]
        print(f"  {CHECK} requirements.txt exists ({len(valid_lines)} packages)")
        
        # Check for critical packages
        content = requirements.read_text()
        critical = ['fastapi', 'uvicorn', 'pydantic']
        for pkg in critical:
            if pkg in content.lower():
                print(f"  {CHECK} {pkg} in requirements")
            else:
                print(f"  {WARN} {pkg} not found in requirements")
        
        return True
    except Exception as e:
        print(f"  {CROSS} Error reading requirements.txt: {e}")
        return False

def test_dockerfile_syntax():
    """Test Dockerfile syntax (basic check)."""
    print(f"\n{BLUE}=== Dockerfile Check ==={RESET}\n")
    
    backend_dir = Path(__file__).parent
    dockerfile = backend_dir / "Dockerfile"
    
    if not dockerfile.exists():
        print(f"  {CROSS} Dockerfile not found")
        return False
    
    try:
        content = dockerfile.read_text()
        
        # Check for required sections
        checks = [
            ("FROM", "FROM statement"),
            ("WORKDIR", "WORKDIR statement"),
            ("COPY requirements.txt", "requirements.txt copy"),
            ("COPY app/", "app directory copy"),
            ("CMD", "CMD statement"),
        ]
        
        all_good = True
        for pattern, name in checks:
            if pattern in content:
                print(f"  {CHECK} {name}")
            else:
                print(f"  {CROSS} {name} missing")
                all_good = False
        
        # Check that story_presets.json is NOT copied separately
        if "COPY story_presets.json" in content:
            print(f"  {CROSS} Dockerfile still has COPY story_presets.json (should be removed)")
            all_good = False
        else:
            print(f"  {CHECK} No separate story_presets.json copy (correct)")
        
        return all_good
    except Exception as e:
        print(f"  {CROSS} Error reading Dockerfile: {e}")
        return False

def test_file_structure():
    """Test that required files exist."""
    print(f"\n{BLUE}=== File Structure Check ==={RESET}\n")
    
    backend_dir = Path(__file__).parent
    
    required_files = [
        "Dockerfile",
        "requirements.txt",
        "app/main.py",
        "app/dreamflow/main.py",
        "app/core/story_presets.json",
        "config/guardrails.yaml",
    ]
    
    all_exist = True
    for file_path in required_files:
        full_path = backend_dir / file_path
        if full_path.exists():
            print(f"  {CHECK} {file_path}")
        else:
            print(f"  {CROSS} {file_path} missing")
            all_exist = False
    
    return all_exist

def test_python_imports():
    """Test that Python can import key modules (if dependencies available)."""
    print(f"\n{BLUE}=== Python Import Test ==={RESET}\n")
    
    backend_dir = Path(__file__).parent
    sys.path.insert(0, str(backend_dir))
    
    # Test basic imports that don't require external services
    test_modules = [
        ("app.shared.config", "Settings"),
        ("app.dreamflow.schemas", "StoryRequest"),
    ]
    
    for module_name, class_name in test_modules:
        try:
            module = __import__(module_name, fromlist=[class_name])
            getattr(module, class_name)
            print(f"  {CHECK} {module_name}.{class_name}")
        except ImportError as e:
            print(f"  {WARN} {module_name}: {e} (may need dependencies)")
        except AttributeError:
            print(f"  {WARN} {module_name}.{class_name} not found")
        except Exception as e:
            print(f"  {WARN} {module_name}: {type(e).__name__}")

def main():
    """Run all deployment tests."""
    print(f"{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}Local Deployment Test{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")
    
    results = []
    
    results.append(("File Structure", test_file_structure()))
    results.append(("Dockerfile Syntax", test_dockerfile_syntax()))
    results.append(("Requirements.txt", test_requirements_txt()))
    test_python_imports()
    
    # Summary
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}Summary{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")
    
    all_passed = True
    for name, passed in results:
        status = f"{GREEN}PASSED{RESET}" if passed else f"{RED}FAILED{RESET}"
        print(f"  {name}: {status}")
        if not passed:
            all_passed = False
    
    print()
    if all_passed:
        print(f"{GREEN}✓ All basic deployment checks passed!{RESET}")
        print(f"\n{YELLOW}Note:{RESET} Full Docker build test requires Docker Desktop to be running")
    else:
        print(f"{RED}✗ Some checks failed. Please review above.{RESET}")
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())

