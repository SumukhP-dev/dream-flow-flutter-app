#!/usr/bin/env python3
"""
Deployment Readiness Verification Script

This script verifies that all necessary files and configurations are in place
before deploying to Render or other platforms.
"""

import os
import sys
import json
from pathlib import Path

# Color codes for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

# Use ASCII-safe checkmarks
CHECK = "[OK]"
CROSS = "[X]"
WARN = "[!]"

def check_file_exists(filepath, description):
    """Check if a file exists and return status."""
    path = Path(filepath)
    exists = path.exists()
    status = f"{GREEN}{CHECK}{RESET}" if exists else f"{RED}{CROSS}{RESET}"
    print(f"  {status} {description}: {filepath}")
    return exists

def check_directory_exists(dirpath, description):
    """Check if a directory exists and return status."""
    path = Path(dirpath)
    exists = path.exists() and path.is_dir()
    status = f"{GREEN}{CHECK}{RESET}" if exists else f"{RED}{CROSS}{RESET}"
    print(f"  {status} {description}: {dirpath}")
    return exists

def verify_render_deployment():
    """Verify Render deployment readiness."""
    print(f"\n{BLUE}=== Render Deployment Readiness ==={RESET}\n")
    
    checks = []
    
    # Check render.yaml
    checks.append(check_file_exists("render.yaml", "Render configuration file"))
    
    # Check Dockerfile
    checks.append(check_file_exists("backend_fastapi/Dockerfile", "Backend Dockerfile"))
    
    # Check .renderignore
    checks.append(check_file_exists("backend_fastapi/.renderignore", "Render ignore file"))
    
    # Check requirements.txt
    checks.append(check_file_exists("backend_fastapi/requirements.txt", "Python dependencies"))
    
    # Check main application files
    checks.append(check_file_exists("backend_fastapi/app/main.py", "Main application file"))
    checks.append(check_file_exists("backend_fastapi/app/config.py", "Configuration module"))
    
    # Check that render.yaml is valid
    if Path("render.yaml").exists():
        try:
            import yaml
            with open("render.yaml", "r") as f:
                config = yaml.safe_load(f)
            if "services" in config and len(config["services"]) > 0:
                print(f"  {GREEN}{CHECK}{RESET} render.yaml is valid YAML")
                checks.append(True)
            else:
                print(f"  {RED}{CROSS}{RESET} render.yaml missing services configuration")
                checks.append(False)
        except ImportError:
            print(f"  {YELLOW}{WARN}{RESET} PyYAML not installed, skipping YAML validation")
            checks.append(True)
        except Exception as e:
            print(f"  {RED}{CROSS}{RESET} Error validating render.yaml: {e}")
            checks.append(False)
    
    all_passed = all(checks)
    
    if all_passed:
        print(f"\n{GREEN}{CHECK} All Render deployment checks passed!{RESET}")
    else:
        print(f"\n{RED}{CROSS} Some checks failed. Please fix the issues above.{RESET}")
    
    return all_passed

def verify_environment_variables():
    """Verify environment variable configuration."""
    print(f"\n{BLUE}=== Environment Variables Check ==={RESET}\n")
    
    required_vars = [
        "SUPABASE_URL",
        "SUPABASE_ANON_KEY",
        "SUPABASE_SERVICE_ROLE_KEY",
        "HUGGINGFACE_API_TOKEN",
        "BACKEND_URL",
    ]
    
    optional_vars = [
        "STRIPE_SECRET_KEY",
        "STRIPE_WEBHOOK_SECRET",
        "REVENUECAT_API_KEY",
        "SENTRY_DSN",
    ]
    
    print(f"{YELLOW}Required Environment Variables (must be set in Render):{RESET}")
    for var in required_vars:
        print(f"  - {var}")
    
    print(f"\n{YELLOW}Optional Environment Variables:{RESET}")
    for var in optional_vars:
        print(f"  - {var}")
    
    # Check if config.json exists
    if Path("config.json").exists():
        print(f"\n{GREEN}{CHECK}{RESET} config.json exists (can be used for automation)")
    else:
        print(f"\n{YELLOW}{WARN}{RESET} config.json not found (create from config.template.json)")
    
    print(f"\n{YELLOW}Note:{RESET} These variables must be set in the Render dashboard after deployment.")
    return True

def verify_git_repository():
    """Verify Git repository status."""
    print(f"\n{BLUE}=== Git Repository Check ==={RESET}\n")
    
    # Check if .git exists
    if not Path(".git").exists():
        print(f"  {RED}{CROSS}{RESET} Not a Git repository")
        print(f"  {YELLOW}{WARN}{RESET} Render requires a Git repository (GitHub/GitLab)")
        return False
    
    print(f"  {GREEN}{CHECK}{RESET} Git repository detected")
    
    # Check if render.yaml is tracked
    try:
        import subprocess
        result = subprocess.run(
            ["git", "ls-files", "render.yaml"],
            capture_output=True,
            text=True
        )
        if result.returncode == 0 and result.stdout.strip():
            print(f"  {GREEN}{CHECK}{RESET} render.yaml is tracked in Git")
        else:
            print(f"  {YELLOW}{WARN}{RESET} render.yaml not tracked in Git (run: git add render.yaml)")
    except Exception:
        print(f"  {YELLOW}{WARN}{RESET} Could not verify Git tracking (Git may not be in PATH)")
    
    return True

def main():
    """Run all verification checks."""
    print(f"{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}Dream Flow - Deployment Readiness Verification{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")
    
    results = []
    
    # Run all checks
    results.append(("Render Deployment", verify_render_deployment()))
    results.append(("Git Repository", verify_git_repository()))
    verify_environment_variables()
    
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
        print(f"{GREEN}{CHECK} Ready for deployment!{RESET}")
        print(f"\n{YELLOW}Next Steps:{RESET}")
        print("  1. Push code to GitHub/GitLab")
        print("  2. Create Render account at https://render.com")
        print("  3. Connect repository and deploy using render.yaml")
        print("  4. Configure environment variables in Render dashboard")
        print("  5. Test health endpoint after deployment")
    else:
        print(f"{RED}{CROSS} Not ready for deployment. Please fix the issues above.{RESET}")
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())

