# Setup Automation Guide

This guide explains how to use the automated setup script to reduce manual configuration steps.

## Overview

The `setup_automation.py` script automates the following setup tasks:

1. ✅ **Bundle ID/Package Name Updates** - Updates iOS and Android identifiers
2. ✅ **AdMob Configuration** - Injects AdMob App IDs into native configuration files
3. ✅ **Environment File Generation** - Creates `.env` and build scripts
4. ✅ **Keystore Generation** - Creates Android signing keystore (optional)
5. ✅ **Localization Generation** - Runs `flutter gen-l10n`

## Prerequisites

- Python 3.7 or higher
- Flutter SDK installed and in PATH
- Java JDK installed (for keystore generation)
- Basic understanding of your app's configuration values

## Quick Start

1. **Copy the template configuration file:**
   ```bash
   cp config.template.json config.json
   ```

2. **Edit `config.json` with your actual values:**
   - Fill in all the placeholder values (API keys, IDs, etc.)
   - Update bundle ID and package name
   - Add AdMob App IDs if you have them

3. **Run the setup script:**
   ```bash
   python setup_automation.py --config config.json
   ```

4. **Review generated files:**
   - `backend_fastapi/.env` - Backend environment variables
   - `frontend_flutter/build.sh` - Flutter build script
   - `frontend_flutter/android/key.properties` - Android signing config (if keystore generated)

## Configuration File Structure

### App Identifiers
```json
{
  "app": {
    "bundle_id": "com.yourcompany.dreamflow",
    "package_name": "com.yourcompany.dreamflow"
  }
}
```

### Supabase Configuration
```json
{
  "supabase": {
    "url": "https://your-project.supabase.co",
    "anon_key": "your-anon-key",
    "service_role_key": "your-service-role-key"
  }
}
```

### Stripe Configuration
```json
{
  "stripe": {
    "publishable_key": "pk_test_...",
    "secret_key": "sk_test_...",
    "webhook_secret": "whsec_...",
    "premium_monthly_price_id": "price_...",
    "premium_annual_price_id": "price_...",
    "family_monthly_price_id": "price_...",
    "family_annual_price_id": "price_..."
  }
}
```

### AdMob Configuration
```json
{
  "admob": {
    "ios_app_id": "ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX",
    "android_app_id": "ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX",
    "banner_ad_unit_id": "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX",
    "interstitial_ad_unit_id": "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"
  }
}
```

### Android Keystore (Optional)
```json
{
  "android_keystore": {
    "generate": true,
    "path": "~/dream-flow-keystore.jks",
    "alias": "dream-flow-key",
    "store_password": "your-secure-password",
    "key_password": "your-secure-password",
    "dname": "CN=Dream Flow, OU=Development, O=Your Company, L=City, ST=State, C=US"
  }
}
```

**⚠️ Security Warning**: Never commit `config.json` with real passwords or production keys to version control. Add it to `.gitignore`.

## Command Line Options

```bash
python setup_automation.py [OPTIONS]

Options:
  --config PATH          Path to configuration JSON file (default: config.json)
  --skip-keystore       Skip keystore generation
  --skip-localization   Skip localization file generation
```

## What Gets Modified

### iOS Files
- `ios/Runner.xcodeproj/project.pbxproj` - Bundle identifier
- `ios/Runner/Info.plist` - AdMob App ID

### Android Files
- `android/app/build.gradle.kts` - Package name (applicationId)
- `android/app/src/main/AndroidManifest.xml` - AdMob App ID
- `android/key.properties` - Keystore configuration (if generated)

### Generated Files
- `backend_fastapi/.env` - Backend environment variables
- `frontend_flutter/build.sh` - Flutter build script with all flags

## Manual Steps Still Required

The automation script handles code/configuration changes, but you still need to manually:

1. **Create accounts** (Stripe, RevenueCat, AdMob, Apple, Google)
2. **Configure dashboards** (create products, ad units, webhooks)
3. **Complete business verification**
4. **Set up app store listings** (screenshots, descriptions)
5. **Submit for review**

See `MANUAL_SETUP_STEPS.md` for the complete checklist.

## Troubleshooting

### "Config file not found"
- Make sure `config.json` exists in the project root
- Or specify path with `--config /path/to/config.json`

### "Flutter not found in PATH"
- Install Flutter SDK
- Add Flutter to your PATH: `export PATH="$PATH:/path/to/flutter/bin"`

### "keytool: command not found"
- Install Java JDK
- On macOS: `brew install openjdk`
- On Ubuntu: `sudo apt-get install openjdk-11-jdk`

### Bundle ID/Package Name not updating
- Check that the files exist
- Verify the current values in the files
- The script only updates if patterns match

### AdMob configuration not added
- Check that `Info.plist` and `AndroidManifest.xml` exist
- Verify the files have the expected structure
- The script won't overwrite existing AdMob configuration

## Security Best Practices

1. **Never commit `config.json`** - Add to `.gitignore`
2. **Use environment variables in CI/CD** - Don't store secrets in files
3. **Use test keys during development** - Only use production keys in production builds
4. **Backup keystore securely** - Store in password manager or secure vault
5. **Rotate keys regularly** - Especially if exposed or compromised

## Example Workflow

```bash
# 1. Copy template
cp config.template.json config.json

# 2. Edit config.json with your values
# (Use your preferred editor)

# 3. Run automation
python setup_automation.py --config config.json

# 4. Review generated files
cat backend_fastapi/.env
cat frontend_flutter/build.sh

# 5. Test build
cd frontend_flutter
./build.sh

# 6. Continue with manual steps from MANUAL_SETUP_STEPS.md
```

## Support

If you encounter issues:
1. Check the error messages for specific problems
2. Verify all prerequisites are installed
3. Review the generated files for correctness
4. Refer to `MANUAL_SETUP_STEPS.md` for manual alternatives

