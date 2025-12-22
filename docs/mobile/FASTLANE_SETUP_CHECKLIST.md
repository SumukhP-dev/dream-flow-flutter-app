# Fastlane Setup Checklist

Use this checklist to ensure all required configuration is complete before your first release.

## Pre-Setup

- [ ] Apple Developer Account enrolled ($99/year)
- [ ] Google Play Developer Account created ($25 one-time)
- [ ] App created in App Store Connect
- [ ] App created in Google Play Console

## iOS Configuration

### App Store Connect
- [ ] App ID created: `com.example.dreamFlow` (update if different)
- [ ] App registered in App Store Connect
- [ ] Required app information completed

### Code Signing
- [ ] Private Git repository created for certificates
- [ ] `ios/fastlane/Matchfile` updated with:
  - [ ] `git_url` pointing to certificates repo
  - [ ] `app_identifier` set correctly
  - [ ] `username` set to your Apple ID
- [ ] `ios/fastlane/Appfile` updated with:
  - [ ] `app_identifier` set correctly
  - [ ] `apple_id` set to your Apple ID email

### GitHub Secrets (iOS)
- [ ] `MATCH_PASSWORD` - Passphrase for Match encryption
- [ ] `MATCH_GIT_BASIC_AUTHORIZATION` - Base64 `username:token` for certificates repo
- [ ] `APPLE_ID` - Your Apple ID email
- [ ] `APPLE_APP_SPECIFIC_PASSWORD` - App-specific password (or use API keys below)

### App Store Connect API (Optional, Recommended)
- [ ] API key created in App Store Connect
- [ ] `APP_STORE_CONNECT_API_KEY_ID` - Key ID
- [ ] `APP_STORE_CONNECT_ISSUER_ID` - Issuer ID
- [ ] `APP_STORE_CONNECT_API_KEY_CONTENT` - .p8 file contents

### Initial Setup Commands
```bash
cd frontend_flutter/ios
bundle install
fastlane match_init  # Run once to create certificates
```

## Android Configuration

### Google Play Console
- [ ] App created in Play Console
- [ ] Package name: `com.example.dream_flow` (update if different)
- [ ] Store listing information completed

### Signing Key
- [ ] Keystore file generated (`dream-flow-keystore.jks`)
- [ ] Keystore password saved securely
- [ ] Key alias noted (`dream-flow-key` or similar)
- [ ] Key password saved securely
- [ ] **BACKUP**: Keystore file backed up securely (cannot be recovered if lost!)

### Google Play Service Account
- [ ] Google Cloud project created
- [ ] Google Play Android Developer API enabled
- [ ] Service account created
- [ ] Service account linked in Play Console
- [ ] "Release Manager" role granted to service account
- [ ] JSON key file downloaded

### GitHub Secrets (Android)
- [ ] `ANDROID_KEYSTORE_BASE64` - Base64-encoded keystore file
- [ ] `ANDROID_KEYSTORE_PASSWORD` - Keystore password
- [ ] `ANDROID_KEY_ALIAS` - Key alias
- [ ] `ANDROID_KEY_PASSWORD` - Key password
- [ ] `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` - Full JSON key file contents

### Fastlane Configuration
- [ ] `android/fastlane/Appfile` updated with:
  - [ ] `package_name` set correctly
  - [ ] `json_key_file` path verified

### Initial Setup Commands
```bash
cd frontend_flutter/android
bundle install
```

## Build Configuration

### iOS
- [ ] Xcode project bundle identifier matches `com.example.dreamFlow`
- [ ] Version and build number configured in `pubspec.yaml`

### Android
- [ ] `android/app/build.gradle.kts` has signing configuration
- [ ] Package name in `build.gradle.kts` matches Play Console
- [ ] Version and version code configured in `pubspec.yaml`

## Testing

### Local Testing
- [ ] iOS: `cd frontend_flutter/ios && fastlane build` succeeds
- [ ] Android: `cd frontend_flutter/android && fastlane build_apk` succeeds

### CI/CD Testing
- [ ] GitHub Actions workflow runs successfully
- [ ] TestFlight upload works (iOS)
- [ ] Internal Testing upload works (Android)

## First Release

### Before First Release
- [ ] All app store metadata prepared (screenshots, descriptions, etc.)
- [ ] Privacy policy URL ready
- [ ] App icons and assets prepared
- [ ] Version number set appropriately

### Release Process
1. [ ] Update version in `pubspec.yaml`
2. [ ] Commit and push changes
3. [ ] Trigger GitHub Actions workflow manually
4. [ ] Monitor build and upload process
5. [ ] Verify app appears in TestFlight/Play Console

## Important Notes

⚠️ **Security**
- Never commit keystores, certificates, or passwords
- Store all secrets in GitHub Secrets
- Keep backups of signing keys in secure location

⚠️ **Bundle Identifiers**
- iOS: Currently set to `com.example.dreamFlow` - update if needed
- Android: Currently set to `com.example.dream_flow` - update if needed
- These must match your App Store Connect and Play Console apps

⚠️ **Version Management**
- Always increment version before release
- iOS uses CFBundleVersion (build number)
- Android uses versionCode (must increment each release)

## Need Help?

See [FASTLANE_RELEASE.md](./FASTLANE_RELEASE.md) for detailed documentation and troubleshooting.

