#!/usr/bin/env python3
"""
Dream Flow App - Automated Setup Script

This script automates several manual setup steps:
- Bundle ID/package name updates
- AdMob configuration injection
- Environment file generation
- Build script generation
- Keystore generation (with prompts)
- Localization file generation

Usage:
    python setup_automation.py --config config.json
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, Optional

# Project root directory
PROJECT_ROOT = Path(__file__).parent.resolve()
IOS_PROJECT_FILE = PROJECT_ROOT / "frontend_flutter" / "ios" / "Runner.xcodeproj" / "project.pbxproj"
IOS_INFO_PLIST = PROJECT_ROOT / "frontend_flutter" / "ios" / "Runner" / "Info.plist"
ANDROID_BUILD_GRADLE = PROJECT_ROOT / "frontend_flutter" / "android" / "app" / "build.gradle.kts"
ANDROID_MANIFEST = PROJECT_ROOT / "frontend_flutter" / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
BACKEND_ENV = PROJECT_ROOT / "backend_fastapi" / ".env"
ANDROID_KEY_PROPERTIES = PROJECT_ROOT / "frontend_flutter" / "android" / "key.properties"


def load_config(config_path: Path) -> Dict:
    """Load configuration from JSON file."""
    if not config_path.exists():
        print(f"ERROR: Config file not found: {config_path}")
        print(f"TIP: Create a config.json file based on config.template.json")
        sys.exit(1)
    
    with open(config_path, 'r') as f:
        return json.load(f)


def update_bundle_id_ios(bundle_id: str) -> bool:
    """Update bundle identifier in iOS project file."""
    if not IOS_PROJECT_FILE.exists():
        print(f"[WARN] iOS project file not found: {IOS_PROJECT_FILE}")
        return False
    
    try:
        with open(IOS_PROJECT_FILE, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Replace bundle identifier
        pattern = r'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;'
        replacement = f'PRODUCT_BUNDLE_IDENTIFIER = {bundle_id};'
        new_content = re.sub(pattern, replacement, content)
        
        if new_content != content:
            with open(IOS_PROJECT_FILE, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"[OK] Updated iOS bundle ID to: {bundle_id}")
            return True
        else:
            print(f"[WARN] Bundle ID already set or pattern not found")
            return False
    except Exception as e:
        print(f"[ERROR] Error updating iOS bundle ID: {e}")
        return False


def update_package_name_android(package_name: str) -> bool:
    """Update package name in Android build.gradle.kts."""
    if not ANDROID_BUILD_GRADLE.exists():
        print(f"[WARN] Android build.gradle.kts not found: {ANDROID_BUILD_GRADLE}")
        return False
    
    try:
        with open(ANDROID_BUILD_GRADLE, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Replace applicationId
        pattern = r'applicationId\s*=\s*"[^"]+"'
        replacement = f'applicationId = "{package_name}"'
        new_content = re.sub(pattern, replacement, content)
        
        if new_content != content:
            with open(ANDROID_BUILD_GRADLE, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"[OK] Updated Android package name to: {package_name}")
            return True
        else:
            print(f"[WARN] Package name already set or pattern not found")
            return False
    except Exception as e:
        print(f"[ERROR] Error updating Android package name: {e}")
        return False


def add_admob_ios(app_id: str) -> bool:
    """Add AdMob App ID to iOS Info.plist."""
    if not IOS_INFO_PLIST.exists():
        print(f"[WARN] iOS Info.plist not found: {IOS_INFO_PLIST}")
        return False
    
    try:
        with open(IOS_INFO_PLIST, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if already exists
        if 'GADApplicationIdentifier' in content:
            print(f"[WARN] AdMob App ID already configured in Info.plist")
            return False
        
        # Find the </dict> before </plist> and insert before it
        pattern = r'(</dict>\s*</plist>)'
        replacement = f'''    <key>GADApplicationIdentifier</key>
    <string>{app_id}</string>
\\1'''
        new_content = re.sub(pattern, replacement, content)
        
        if new_content != content:
            with open(IOS_INFO_PLIST, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"[OK] Added AdMob iOS App ID to Info.plist")
            return True
        else:
            print(f"[WARN] Could not find insertion point in Info.plist")
            return False
    except Exception as e:
        print(f"[ERROR] Error updating iOS Info.plist: {e}")
        return False


def add_admob_android(app_id: str) -> bool:
    """Add AdMob App ID to Android AndroidManifest.xml."""
    if not ANDROID_MANIFEST.exists():
        print(f"[WARN] AndroidManifest.xml not found: {ANDROID_MANIFEST}")
        return False
    
    try:
        with open(ANDROID_MANIFEST, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if already exists
        if 'com.google.android.gms.ads.APPLICATION_ID' in content:
            print(f"[WARN] AdMob App ID already configured in AndroidManifest.xml")
            return False
        
        # Find <application> tag and insert before closing tag
        pattern = r'(<application[^>]*>)'
        replacement = f'''\\1
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="{app_id}"/>'''
        new_content = re.sub(pattern, replacement, content, count=1)
        
        if new_content != content:
            with open(ANDROID_MANIFEST, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"[OK] Added AdMob Android App ID to AndroidManifest.xml")
            return True
        else:
            print(f"[WARN] Could not find <application> tag in AndroidManifest.xml")
            return False
    except Exception as e:
        print(f"[ERROR] Error updating AndroidManifest.xml: {e}")
        return False


def generate_backend_env(config: Dict) -> bool:
    """Generate backend .env file from config."""
    env_content = f"""# Supabase Configuration
SUPABASE_URL={config.get('supabase', {}).get('url', 'https://your-project.supabase.co')}
SUPABASE_ANON_KEY={config.get('supabase', {}).get('anon_key', 'your-anon-key')}
SUPABASE_SERVICE_ROLE_KEY={config.get('supabase', {}).get('service_role_key', 'your-service-role-key')}

# Stripe Configuration
STRIPE_SECRET_KEY={config.get('stripe', {}).get('secret_key', 'sk_test_...')}
STRIPE_WEBHOOK_SECRET={config.get('stripe', {}).get('webhook_secret', 'whsec_...')}

# RevenueCat Configuration
REVENUECAT_API_KEY={config.get('revenuecat', {}).get('api_key', 'your-revenuecat-api-key')}

# HuggingFace Configuration
HUGGINGFACE_API_TOKEN={config.get('huggingface', {}).get('token', 'hf_...')}

# Backend URL
BACKEND_URL={config.get('backend', {}).get('url', 'https://your-backend-url.com')}

# Sentry Configuration (Optional)
SENTRY_DSN={config.get('sentry', {}).get('dsn', '')}
SENTRY_ENVIRONMENT={config.get('sentry', {}).get('environment', 'development')}
"""
    
    try:
        BACKEND_ENV.parent.mkdir(parents=True, exist_ok=True)
        with open(BACKEND_ENV, 'w') as f:
            f.write(env_content)
        print(f"[OK] Generated backend .env file: {BACKEND_ENV}")
        return True
    except Exception as e:
        print(f"[ERROR] Error generating backend .env: {e}")
        return False


def generate_build_script(config: Dict) -> bool:
    """Generate Flutter build script with all environment variables."""
    script_content = f"""#!/bin/bash
# Dream Flow - Flutter Build Script
# Auto-generated by setup_automation.py

flutter build apk --release \\
  --dart-define=SUPABASE_URL={config.get('supabase', {}).get('url', 'https://your-project.supabase.co')} \\
  --dart-define=SUPABASE_ANON_KEY={config.get('supabase', {}).get('anon_key', 'your-anon-key')} \\
  --dart-define=BACKEND_URL={config.get('backend', {}).get('url', 'https://your-backend-url.com')} \\
  --dart-define=REVENUECAT_API_KEY={config.get('revenuecat', {}).get('api_key', 'appl_...')} \\
  --dart-define=STRIPE_PUBLISHABLE_KEY={config.get('stripe', {}).get('publishable_key', 'pk_test_...')} \\
  --dart-define=STRIPE_PREMIUM_MONTHLY_PRICE_ID={config.get('stripe', {}).get('premium_monthly_price_id', 'price_...')} \\
  --dart-define=STRIPE_PREMIUM_ANNUAL_PRICE_ID={config.get('stripe', {}).get('premium_annual_price_id', 'price_...')} \\
  --dart-define=STRIPE_FAMILY_MONTHLY_PRICE_ID={config.get('stripe', {}).get('family_monthly_price_id', 'price_...')} \\
  --dart-define=STRIPE_FAMILY_ANNUAL_PRICE_ID={config.get('stripe', {}).get('family_annual_price_id', 'price_...')} \\
  --dart-define=ADMOB_BANNER_AD_UNIT_ID={config.get('admob', {}).get('banner_ad_unit_id', 'ca-app-pub-...')} \\
  --dart-define=ADMOB_INTERSTITIAL_AD_UNIT_ID={config.get('admob', {}).get('interstitial_ad_unit_id', 'ca-app-pub-...')} \\
  --dart-define=ADMOB_IOS_APP_ID={config.get('admob', {}).get('ios_app_id', 'ca-app-pub-...')} \\
  --dart-define=ADMOB_ANDROID_APP_ID={config.get('admob', {}).get('android_app_id', 'ca-app-pub-...')} \\
  --dart-define=ADSENSE_PUBLISHER_ID={config.get('adsense', {}).get('publisher_id', 'pub-...')} \\
  --dart-define=SENTRY_DSN={config.get('sentry', {}).get('dsn', '')} \\
  --dart-define=ENVIRONMENT={config.get('environment', 'production')}
"""
    
    script_path = PROJECT_ROOT / "frontend_flutter" / "build.sh"
    try:
        with open(script_path, 'w') as f:
            f.write(script_content)
        # Make executable on Unix systems
        os.chmod(script_path, 0o755)
        print(f"[OK] Generated build script: {script_path}")
        return True
    except Exception as e:
        print(f"[ERROR] Error generating build script: {e}")
        return False


def generate_keystore(config: Dict) -> bool:
    """Generate Android keystore with prompts."""
    keystore_config = config.get('android_keystore', {})
    
    if not keystore_config.get('generate', False):
        print("[SKIP] Skipping keystore generation (set android_keystore.generate to true)")
        return True
    
    keystore_path = Path(keystore_config.get('path', '~/dream-flow-keystore.jks')).expanduser()
    alias = keystore_config.get('alias', 'dream-flow-key')
    storepass = keystore_config.get('store_password', '')
    keypass = keystore_config.get('key_password', '')
    
    if not storepass or not keypass:
        print("[WARN] Keystore passwords not provided in config")
        print("[TIP] Please generate keystore manually or add passwords to config.json")
        return False
    
    if keystore_path.exists():
        print(f"[WARN] Keystore already exists: {keystore_path}")
        response = input("Overwrite? (y/N): ").strip().lower()
        if response != 'y':
            return False
    
    try:
        cmd = [
            'keytool',
            '-genkey',
            '-v',
            '-keystore', str(keystore_path),
            '-keyalg', 'RSA',
            '-keysize', '2048',
            '-validity', '10000',
            '-alias', alias,
            '-storepass', storepass,
            '-keypass', keypass,
            '-dname', keystore_config.get('dname', 'CN=Dream Flow, OU=Development, O=Your Company, L=City, ST=State, C=US')
        ]
        
        subprocess.run(cmd, check=True)
        print(f"[OK] Generated keystore: {keystore_path}")
        
        # Generate key.properties
        key_props_content = f"""storePassword={storepass}
keyPassword={keypass}
keyAlias={alias}
storeFile={keystore_path}
"""
        ANDROID_KEY_PROPERTIES.parent.mkdir(parents=True, exist_ok=True)
        with open(ANDROID_KEY_PROPERTIES, 'w') as f:
            f.write(key_props_content)
        print(f"[OK] Generated key.properties: {ANDROID_KEY_PROPERTIES}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Error generating keystore: {e}")
        return False
    except Exception as e:
        print(f"[ERROR] Error: {e}")
        return False


def generate_localization() -> bool:
    """Run Flutter localization generation."""
    flutter_dir = PROJECT_ROOT / "frontend_flutter"
    if not flutter_dir.exists():
        print(f"[WARN] Flutter directory not found: {flutter_dir}")
        return False
    
    try:
        result = subprocess.run(
            ['flutter', 'gen-l10n'],
            cwd=flutter_dir,
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print("[OK] Generated localization files")
            return True
        else:
            print(f"[WARN] Localization generation had warnings: {result.stderr}")
            return False
    except FileNotFoundError:
        print("[ERROR] Flutter not found in PATH. Make sure Flutter SDK is installed.")
        return False
    except Exception as e:
        print(f"[ERROR] Error generating localization: {e}")
        return False


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Automate Dream Flow app setup')
    parser.add_argument(
        '--config',
        type=Path,
        default=PROJECT_ROOT / 'config.json',
        help='Path to configuration JSON file (default: config.json)'
    )
    parser.add_argument(
        '--skip-keystore',
        action='store_true',
        help='Skip keystore generation'
    )
    parser.add_argument(
        '--skip-localization',
        action='store_true',
        help='Skip localization generation'
    )
    
    args = parser.parse_args()
    
    print("Dream Flow - Automated Setup")
    print("=" * 50)
    
    # Load configuration
    config = load_config(args.config)
    
    # Get app identifiers
    bundle_id = config.get('app', {}).get('bundle_id', 'com.yourcompany.dreamflow')
    package_name = config.get('app', {}).get('package_name', bundle_id)
    
    print(f"\n[INFO] App Configuration:")
    print(f"   Bundle ID (iOS): {bundle_id}")
    print(f"   Package Name (Android): {package_name}")
    
    # Update bundle IDs
    print("\n[INFO] Updating app identifiers...")
    update_bundle_id_ios(bundle_id)
    update_package_name_android(package_name)
    
    # AdMob configuration
    admob_config = config.get('admob', {})
    if admob_config.get('ios_app_id'):
        print("\n[INFO] Configuring AdMob for iOS...")
        add_admob_ios(admob_config['ios_app_id'])
    
    if admob_config.get('android_app_id'):
        print("\n[INFO] Configuring AdMob for Android...")
        add_admob_android(admob_config['android_app_id'])
    
    # Generate environment files
    print("\n[INFO] Generating environment files...")
    generate_backend_env(config)
    generate_build_script(config)
    
    # Keystore generation
    if not args.skip_keystore:
        print("\n[INFO] Generating Android keystore...")
        generate_keystore(config)
    else:
        print("\n[SKIP] Skipping keystore generation")
    
    # Localization
    if not args.skip_localization:
        print("\n[INFO] Generating localization files...")
        generate_localization()
    else:
        print("\n[SKIP] Skipping localization generation")
    
    print("\n" + "=" * 50)
    print("[OK] Setup complete!")
    print("\n[INFO] Next steps:")
    print("   1. Review generated files (.env, build.sh)")
    print("   2. Complete manual steps in MANUAL_SETUP_STEPS.md")
    print("   3. Test the build: cd frontend_flutter && ./build.sh")


if __name__ == '__main__':
    main()

