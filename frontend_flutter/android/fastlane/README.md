# Android Fastlane

This directory contains Fastlane configuration for Android releases.

## Quick Start

1. **Initial Setup** (one-time):
   ```bash
   cd frontend_flutter/android
   bundle install
   ```

2. **Build APK**:
   ```bash
   fastlane build_apk
   ```

3. **Upload to Internal Testing**:
   ```bash
   fastlane internal
   ```

4. **Upload to Beta**:
   ```bash
   fastlane beta
   ```

5. **Upload to Production**:
   ```bash
   fastlane release
   ```

## Available Lanes

- `build`: Build the Android app bundle
- `build_apk`: Build APK for testing
- `internal`: Build and upload to Internal Testing track
- `beta`: Build and upload to Beta track
- `release`: Build and upload to Production track
- `increment_version_code`: Increment version code

For detailed documentation, see [FASTLANE_RELEASE.md](../FASTLANE_RELEASE.md).

