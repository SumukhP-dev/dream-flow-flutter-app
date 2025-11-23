# Fastlane Release Guide

This guide covers setting up and using Fastlane for automated releases to the App Store and Google Play Store.

## Table of Contents

- [Prerequisites](#prerequisites)
- [iOS Setup](#ios-setup)
- [Android Setup](#android-setup)
- [CI/CD Integration](#cicd-integration)
- [Manual Releases](#manual-releases)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **Fastlane**: Install via `gem install fastlane` or `brew install fastlane`
- **Ruby**: Version 3.1 or later
- **Bundler**: `gem install bundler` (optional, for dependency management)
- **Xcode**: Latest stable version (for iOS)
- **Android SDK**: Configured via Flutter (for Android)

### Required Accounts

- **Apple Developer Account**: Active membership ($99/year)
- **Google Play Console Account**: One-time $25 registration fee

## iOS Setup

### 1. Apple Developer Account Setup

1. Enroll in the Apple Developer Program at [developer.apple.com](https://developer.apple.com)
2. Note your Apple ID email address
3. Create an App ID in the Apple Developer Portal:
   - Go to Certificates, Identifiers & Profiles
   - Create a new App ID: `com.example.dreamFlow`
   - Enable required capabilities (Push Notifications, etc.)

### 2. Code Signing with Match

Fastlane Match manages certificates and provisioning profiles securely.

#### Initial Setup

1. **Create a private Git repository** for storing certificates:
   ```bash
   # Create a new private repository (e.g., on GitHub)
   # Name it something like: certificates or ios-certificates
   ```

2. **Update Matchfile** (`ios/fastlane/Matchfile`):
   ```ruby
   git_url("https://github.com/your-org/certificates")
   app_identifier("com.example.dreamFlow")
   username("your-apple-id@example.com")
   ```

3. **Initialize Match** (run once):
   ```bash
   cd frontend_flutter/ios
   fastlane match_init
   ```
   - This will create certificates and provisioning profiles
   - You'll be prompted for a passphrase (save this securely!)
   - Certificates will be stored in your Git repository

#### Using Match

- **Sync certificates** (for CI/CD or new machines):
  ```bash
  cd frontend_flutter/ios
  fastlane match_sync
  ```

- **Add new device** (for Ad Hoc builds):
  ```bash
  fastlane match adhoc --force_for_new_devices
  ```

### 3. App Store Connect API Key (Recommended for CI/CD)

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to Users and Access → Keys
3. Create a new key with "App Manager" role
4. Download the `.p8` key file
5. Note the Key ID and Issuer ID

**Store these as GitHub Secrets:**
- `APP_STORE_CONNECT_API_KEY_ID`: Your Key ID
- `APP_STORE_CONNECT_ISSUER_ID`: Your Issuer ID
- `APP_STORE_CONNECT_API_KEY_CONTENT`: Contents of the `.p8` file

### 4. App-Specific Password (Alternative for CI/CD)

If not using API keys:

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in → App-Specific Passwords
3. Generate a new password for "Fastlane"
4. Store as GitHub Secret: `APPLE_APP_SPECIFIC_PASSWORD`

### 5. Update Fastfile Configuration

Edit `ios/fastlane/Appfile`:
```ruby
app_identifier("com.example.dreamFlow")
apple_id("your-apple-id@example.com")
```

## Android Setup

### 1. Google Play Console Setup

1. Create a Google Play Developer account at [play.google.com/console](https://play.google.com/console)
2. Pay the one-time $25 registration fee
3. Create a new app in the Play Console
4. Complete the app information and store listing

### 2. Create a Signing Key

**Important**: Keep this key secure! You cannot change it later.

```bash
# Generate a new keystore
keytool -genkey -v -keystore ~/dream-flow-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias dream-flow-key \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD
```

**Store these securely:**
- Keystore file: `dream-flow-keystore.jks`
- Store password
- Key alias: `dream-flow-key`
- Key password

### 3. Configure Signing in CI/CD

For GitHub Actions, encode your keystore as base64:

```bash
# On macOS/Linux
base64 -i dream-flow-keystore.jks | pbcopy

# On Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("dream-flow-keystore.jks"))
```

**Store as GitHub Secrets:**
- `ANDROID_KEYSTORE_BASE64`: Base64-encoded keystore
- `ANDROID_KEYSTORE_PASSWORD`: Store password
- `ANDROID_KEY_ALIAS`: Key alias (e.g., `dream-flow-key`)
- `ANDROID_KEY_PASSWORD`: Key password

### 4. Google Play Service Account

For automated uploads, create a service account:

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Enable "Google Play Android Developer API"
4. Create a Service Account:
   - IAM & Admin → Service Accounts
   - Create Service Account
   - Grant role: "Service Account User"
5. Create and download JSON key
6. Link service account in Play Console:
   - Play Console → Setup → API access
   - Link service account
   - Grant "Release Manager" permissions

**Store as GitHub Secret:**
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: Full contents of the JSON file

### 5. Update Fastfile Configuration

Edit `android/fastlane/Appfile`:
```ruby
package_name("com.example.dream_flow")
json_key_file("../../fastlane-google-play-key.json")
```

## CI/CD Integration

### GitHub Actions Workflows

Two workflows are configured:

1. **iOS Release** (`.github/workflows/ios-release.yml`)
   - Triggers: Manual dispatch or tags `ios-v*`
   - Tracks: `beta` (TestFlight) or `release` (App Store)

2. **Android Release** (`.github/workflows/android-release.yml`)
   - Triggers: Manual dispatch or tags `android-v*`
   - Tracks: `internal`, `beta`, or `release` (Production)

### Required GitHub Secrets

#### iOS Secrets
- `MATCH_PASSWORD`: Passphrase for Match (certificate encryption)
- `MATCH_GIT_BASIC_AUTHORIZATION`: Base64-encoded `username:token` for certificates repo
- `APPLE_ID`: Your Apple ID email
- `APPLE_APP_SPECIFIC_PASSWORD`: App-specific password (if not using API keys)
- `APP_STORE_CONNECT_API_KEY_ID`: (Optional) API Key ID
- `APP_STORE_CONNECT_ISSUER_ID`: (Optional) Issuer ID
- `APP_STORE_CONNECT_API_KEY_CONTENT`: (Optional) API Key content

#### Android Secrets
- `ANDROID_KEYSTORE_BASE64`: Base64-encoded keystore file
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password
- `ANDROID_KEY_ALIAS`: Key alias
- `ANDROID_KEY_PASSWORD`: Key password
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: Service account JSON

### Triggering Releases

#### Manual Release (Recommended)

1. Go to Actions → iOS Release or Android Release
2. Click "Run workflow"
3. Select the track (beta/release)
4. Click "Run workflow"

#### Tag-Based Release

```bash
# iOS
git tag ios-v1.0.0
git push origin ios-v1.0.0

# Android
git tag android-v1.0.0
git push origin android-v1.0.0
```

## Manual Releases

### iOS

#### Build for TestFlight
```bash
cd frontend_flutter/ios
fastlane beta
```

#### Build for App Store
```bash
cd frontend_flutter/ios
fastlane release
```

#### Development Build
```bash
cd frontend_flutter/ios
fastlane development
```

### Android

#### Build APK
```bash
cd frontend_flutter/android
fastlane build_apk
```

#### Upload to Internal Testing
```bash
cd frontend_flutter/android
fastlane internal
```

#### Upload to Beta
```bash
cd frontend_flutter/android
fastlane beta
```

#### Upload to Production
```bash
cd frontend_flutter/android
fastlane release
```

## Troubleshooting

### iOS Issues

#### "No provisioning profile found"
- Run `fastlane match_sync` to sync certificates
- Ensure Matchfile has correct `git_url` and `app_identifier`

#### "Invalid bundle identifier"
- Verify `app_identifier` in `Appfile` matches Xcode project
- Check App ID exists in Apple Developer Portal

#### "Authentication failed"
- Verify `APPLE_ID` and `APPLE_APP_SPECIFIC_PASSWORD` are correct
- For API keys, ensure all three secrets are set correctly

### Android Issues

#### "Keystore file not found"
- Ensure `key.properties` exists in `android/` directory
- Verify keystore path in `key.properties` is correct

#### "Upload failed: Authentication error"
- Verify `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` is valid
- Check service account has "Release Manager" permissions
- Ensure API is enabled in Google Cloud Console

#### "Version code already exists"
- Increment version in `pubspec.yaml`
- Run `flutter pub version patch` or manually update version

### General Issues

#### "Fastlane not found"
```bash
gem install fastlane
# or
brew install fastlane
```

#### "Flutter build failed"
- Ensure Flutter is up to date: `flutter upgrade`
- Clean build: `flutter clean && flutter pub get`
- Check for platform-specific issues

## Best Practices

1. **Version Management**: Always increment version numbers before release
2. **Testing**: Test builds locally before CI/CD deployment
3. **Security**: Never commit keystores, certificates, or passwords
4. **Backup**: Keep secure backups of all signing keys
5. **Documentation**: Update changelogs in `android/fastlane/metadata/`
6. **Staging**: Use beta/internal tracks for testing before production

## Additional Resources

- [Fastlane Documentation](https://docs.fastlane.tools)
- [iOS Code Signing Guide](https://docs.fastlane.tools/codesigning/getting-started/)
- [Android Deployment Guide](https://docs.fastlane.tools/getting-started/android/setup/)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [Google Play Developer API](https://developers.google.com/android-publisher)

