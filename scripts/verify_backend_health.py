#!/usr/bin/env python3
"""
Backend Health Check Script

This script verifies that the deployed backend is healthy and accessible.
"""

import sys
import requests
import json
from urllib.parse import urljoin

# Color codes
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

# ASCII-safe symbols
CHECK = "[OK]"
CROSS = "[X]"
WARN = "[!]"

def check_health_endpoint(base_url):
    """Check the /health endpoint."""
    print(f"\n{BLUE}Checking health endpoint...{RESET}")
    
    try:
        health_url = urljoin(base_url, "/health")
        print(f"  URL: {health_url}")
        
        response = requests.get(health_url, timeout=10)
        
        if response.status_code == 200:
            print(f"  {GREEN}{CHECK}{RESET} Health check passed (Status: {response.status_code})")
            try:
                data = response.json()
                print(f"  Response: {json.dumps(data, indent=2)}")
                return True
            except json.JSONDecodeError:
                print(f"  {YELLOW}{WARN}{RESET} Response is not valid JSON")
                print(f"  Response: {response.text[:200]}")
                return True  # Still consider it a pass if status is 200
        else:
            print(f"  {RED}{CROSS}{RESET} Health check failed (Status: {response.status_code})")
            print(f"  Response: {response.text[:200]}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"  {RED}{CROSS}{RESET} Failed to connect: {e}")
        return False

def check_api_docs(base_url):
    """Check if API documentation is accessible."""
    print(f"\n{BLUE}Checking API documentation...{RESET}")
    
    try:
        docs_url = urljoin(base_url, "/docs")
        print(f"  URL: {docs_url}")
        
        response = requests.get(docs_url, timeout=10)
        
        if response.status_code == 200:
            print(f"  {GREEN}{CHECK}{RESET} API docs accessible (Status: {response.status_code})")
            return True
        else:
            print(f"  {YELLOW}{WARN}{RESET} API docs not accessible (Status: {response.status_code})")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"  {YELLOW}{WARN}{RESET} Could not check API docs: {e}")
        return False

def main():
    """Run health checks."""
    if len(sys.argv) < 2:
        print(f"{RED}Usage: python verify_backend_health.py <backend_url>{RESET}")
        print(f"Example: python verify_backend_health.py https://dream-flow-backend.onrender.com")
        return 1
    
    base_url = sys.argv[1].rstrip('/')
    
    print(f"{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}Backend Health Check{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")
    print(f"\nBackend URL: {base_url}")
    
    results = []
    results.append(("Health Endpoint", check_health_endpoint(base_url)))
    results.append(("API Documentation", check_api_docs(base_url)))
    
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
        print(f"{GREEN}{CHECK} Backend is healthy and accessible!{RESET}")
    else:
        print(f"{RED}{CROSS} Backend health check failed. Please investigate.{RESET}")
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())

