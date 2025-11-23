#!/usr/bin/env python3
"""
Launch Readiness Checker

This script checks all the critical requirements for launching the app to market.
"""

import os
import sys
import json
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

def check_backend_deployment():
    """Check if backend is deployed."""
    print(f"\n{BLUE}=== Backend Deployment ==={RESET}\n")
    
    # Check if render.yaml exists (indicates readiness)
    if Path("render.yaml").exists():
        print(f"  {GREEN}{CHECK}{RESET} Render configuration ready")
        print(f"  {YELLOW}{WARN}{RESET} Manual: Deploy to Render and verify health endpoint")
        return True
    else:
        print(f"  {RED}{CROSS}{RESET} render.yaml not found")
        return False

def check_payment_setup():
    """Check payment provider setup."""
    print(f"\n{BLUE}=== Payment Providers ==={RESET}\n")
    
    # Check if payment service exists
    payment_service = Path("frontend_flutter/lib/services/payment_service.dart")
    if payment_service.exists():
        print(f"  {GREEN}{CHECK}{RESET} Payment service code exists")
    else:
        print(f"  {RED}{CROSS}{RESET} Payment service not found")
        return False
    
    # Check config.json for payment keys
    if Path("config.json").exists():
        try:
            with open("config.json", "r") as f:
                config = json.load(f)
            
            stripe_configured = any(key.startswith("stripe") for key in config.keys())
            revenuecat_configured = "revenuecat" in config or "revenue_cat" in config
            
            if stripe_configured:
                print(f"  {GREEN}{CHECK}{RESET} Stripe keys in config.json")
            else:
                print(f"  {YELLOW}{WARN}{RESET} Stripe keys not in config.json")
            
            if revenuecat_configured:
                print(f"  {GREEN}{CHECK}{RESET} RevenueCat key in config.json")
            else:
                print(f"  {YELLOW}{WARN}{RESET} RevenueCat key not in config.json")
        except Exception as e:
            print(f"  {YELLOW}{WARN}{RESET} Could not read config.json: {e}")
    
    print(f"  {YELLOW}{WARN}{RESET} Manual: Create Stripe and RevenueCat accounts")
    print(f"  {YELLOW}{WARN}{RESET} Manual: Configure products and webhooks")
    
    return True

def check_app_store_setup():
    """Check app store setup."""
    print(f"\n{BLUE}=== App Store Setup ==={RESET}\n")
    
    # Check bundle IDs
    ios_bundle_id = None
    android_package = None
    
    # Check iOS
    pbxproj = Path("frontend_flutter/ios/Runner.xcodeproj/project.pbxproj")
    if pbxproj.exists():
        with open(pbxproj, "r") as f:
            content = f.read()
            if "com.example" in content:
                print(f"  {YELLOW}{WARN}{RESET} iOS bundle ID still uses placeholder (com.example)")
            else:
                print(f"  {GREEN}{CHECK}{RESET} iOS bundle ID configured")
    
    # Check Android
    build_gradle = Path("frontend_flutter/android/app/build.gradle.kts")
    if build_gradle.exists():
        with open(build_gradle, "r") as f:
            content = f.read()
            if "com.example" in content:
                print(f"  {YELLOW}{WARN}{RESET} Android package name still uses placeholder (com.example)")
            else:
                print(f"  {GREEN}{CHECK}{RESET} Android package name configured")
    
    print(f"  {YELLOW}{WARN}{RESET} Manual: Create Apple Developer account ($99/year)")
    print(f"  {YELLOW}{WARN}{RESET} Manual: Create Google Play Developer account ($25)")
    print(f"  {YELLOW}{WARN}{RESET} Manual: Create apps in App Store Connect and Play Console")
    
    return True

def check_localization():
    """Check localization setup."""
    print(f"\n{BLUE}=== Localization ==={RESET}\n")
    
    # Check if ARB files exist
    arb_en = Path("frontend_flutter/lib/l10n/app_en.arb")
    arb_es = Path("frontend_flutter/lib/l10n/app_es.arb")
    
    if arb_en.exists():
        print(f"  {GREEN}{CHECK}{RESET} English translations (app_en.arb)")
    else:
        print(f"  {RED}{CROSS}{RESET} English translations missing")
    
    if arb_es.exists():
        print(f"  {GREEN}{CHECK}{RESET} Spanish translations (app_es.arb)")
    else:
        print(f"  {RED}{CROSS}{RESET} Spanish translations missing")
    
    # Check if generated files exist
    generated = Path("frontend_flutter/lib/generated/app_localizations.dart")
    if generated.exists():
        print(f"  {GREEN}{CHECK}{RESET} Generated localization files exist")
    else:
        print(f"  {YELLOW}{WARN}{RESET} Generated files missing - run: flutter gen-l10n")
    
    return arb_en.exists() and arb_es.exists()

def check_store_assets():
    """Check store assets."""
    print(f"\n{BLUE}=== Store Assets ==={RESET}\n")
    
    # Check app icons
    ios_icon = Path("frontend_flutter/ios/Runner/Assets.xcassets/AppIcon.appiconset")
    android_icon = Path("frontend_flutter/android/app/src/main/res/mipmap-hdpi/ic_launcher.png")
    
    if ios_icon.exists():
        print(f"  {GREEN}{CHECK}{RESET} iOS app icons exist")
    else:
        print(f"  {RED}{CROSS}{RESET} iOS app icons missing")
    
    if android_icon.exists():
        print(f"  {GREEN}{CHECK}{RESET} Android app icons exist")
    else:
        print(f"  {RED}{CROSS}{RESET} Android app icons missing")
    
    print(f"  {YELLOW}{WARN}{RESET} Manual: Take screenshots for all required sizes")
    print(f"  {YELLOW}{WARN}{RESET} Manual: Write app descriptions")
    print(f"  {YELLOW}{WARN}{RESET} Manual: Create privacy policy")
    
    return ios_icon.exists() and android_icon.exists()

def main():
    """Run all readiness checks."""
    print(f"{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}Dream Flow - Launch Readiness Check{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")
    
    results = []
    results.append(("Backend Deployment", check_backend_deployment()))
    results.append(("Payment Setup", check_payment_setup()))
    results.append(("App Store Setup", check_app_store_setup()))
    results.append(("Localization", check_localization()))
    results.append(("Store Assets", check_store_assets()))
    
    # Summary
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}Summary{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")
    
    code_ready = all(results)
    manual_tasks = [
        "Deploy backend to Render",
        "Set up Stripe account and products",
        "Set up RevenueCat account",
        "Create Apple Developer account",
        "Create Google Play Developer account",
        "Configure in-app purchases",
        "Take store screenshots",
        "Write app descriptions",
        "Create privacy policy",
        "Complete manual testing",
        "Submit to app stores"
    ]
    
    print(f"{GREEN}Code Implementation:{RESET} {'Ready' if code_ready else 'Needs Work'}")
    print(f"\n{YELLOW}Manual Tasks Remaining:{RESET}")
    for i, task in enumerate(manual_tasks, 1):
        print(f"  {i}. {task}")
    
    print(f"\n{YELLOW}Next Steps:{RESET}")
    print("  1. Follow DEPLOYMENT_GUIDE.md for backend deployment")
    print("  2. Follow MANUAL_SETUP_STEPS.md for all manual tasks")
    print("  3. Use scripts/verify_backend_health.py after deployment")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())

