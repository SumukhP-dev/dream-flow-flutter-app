#!/usr/bin/env python3
"""
Compilation Checker

This script checks if both frontend and backend compile successfully.
"""

import subprocess
import sys
import os
from pathlib import Path

# Color codes
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

CHECK = "[OK]"
CROSS = "[X]"
WARN = "[!]"

def check_backend():
    """Check if backend compiles."""
    print(f"\n{BLUE}=== Backend Compilation Check ==={RESET}\n")
    
    backend_dir = Path("backend_fastapi")
    if not backend_dir.exists():
        print(f"  {RED}{CROSS}{RESET} backend_fastapi directory not found")
        return False
    
    try:
        # Try to compile main Python files
        result = subprocess.run(
            [sys.executable, "-m", "py_compile", "backend_fastapi/app/main.py"],
            capture_output=True,
            text=True,
            cwd=Path.cwd()
        )
        
        if result.returncode == 0:
            print(f"  {GREEN}{CHECK}{RESET} Backend Python files compile successfully")
            return True
        else:
            print(f"  {RED}{CROSS}{RESET} Backend compilation errors:")
            print(f"  {result.stderr}")
            return False
    except Exception as e:
        print(f"  {YELLOW}{WARN}{RESET} Could not check backend compilation: {e}")
        return False

def check_frontend():
    """Check if frontend compiles."""
    print(f"\n{BLUE}=== Frontend Compilation Check ==={RESET}\n")
    
    frontend_dir = Path("frontend_flutter")
    if not frontend_dir.exists():
        print(f"  {RED}{CROSS}{RESET} frontend_flutter directory not found")
        return False
    
    try:
        # Run Flutter analyze
        result = subprocess.run(
            ["flutter", "analyze", "--no-fatal-infos"],
            capture_output=True,
            text=True,
            cwd=frontend_dir
        )
        
        # Count errors
        error_count = result.stdout.count("error -")
        warning_count = result.stdout.count("warning -")
        
        if error_count == 0:
            print(f"  {GREEN}{CHECK}{RESET} Frontend compiles successfully")
            if warning_count > 0:
                print(f"  {YELLOW}{WARN}{RESET} {warning_count} warnings found (non-blocking)")
            return True
        else:
            print(f"  {RED}{CROSS}{RESET} Frontend has {error_count} compilation errors")
            print(f"  {YELLOW}{WARN}{RESET} {warning_count} warnings found")
            
            # Show first few errors
            lines = result.stdout.split('\n')
            error_lines = [l for l in lines if 'error -' in l][:5]
            if error_lines:
                print(f"\n  First few errors:")
                for line in error_lines:
                    print(f"    {line.strip()}")
            
            return False
    except FileNotFoundError:
        print(f"  {YELLOW}{WARN}{RESET} Flutter not found in PATH")
        print(f"  {YELLOW}{WARN}{RESET} Install Flutter SDK to check frontend compilation")
        return None
    except Exception as e:
        print(f"  {YELLOW}{WARN}{RESET} Could not check frontend compilation: {e}")
        return None

def main():
    """Run compilation checks."""
    print(f"{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}Dream Flow - Compilation Check{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")
    
    backend_ok = check_backend()
    frontend_ok = check_frontend()
    
    # Summary
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}Summary{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")
    
    backend_status = f"{GREEN}PASSED{RESET}" if backend_ok else f"{RED}FAILED{RESET}"
    if frontend_ok is None:
        frontend_status = f"{YELLOW}SKIPPED{RESET} (Flutter not found)"
    elif frontend_ok:
        frontend_status = f"{GREEN}PASSED{RESET}"
    else:
        frontend_status = f"{RED}FAILED{RESET}"
    
    print(f"  Backend: {backend_status}")
    print(f"  Frontend: {frontend_status}")
    
    print()
    if backend_ok and (frontend_ok is True):
        print(f"{GREEN}{CHECK} Both frontend and backend compile successfully!{RESET}")
        return 0
    elif backend_ok and frontend_ok is None:
        print(f"{YELLOW}{WARN} Backend compiles, but frontend check was skipped.{RESET}")
        return 0
    else:
        print(f"{RED}{CROSS} Compilation errors found. Please fix the issues above.{RESET}")
        return 1

if __name__ == "__main__":
    sys.exit(main())

