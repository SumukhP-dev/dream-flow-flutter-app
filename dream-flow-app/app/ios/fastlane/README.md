# iOS Fastlane

This directory contains Fastlane configuration for iOS releases.

## Quick Start

1. **Initial Setup** (one-time):
   ```bash
   cd frontend_flutter/ios
   bundle install
   fastlane match_init
   ```

2. **Sync Certificates**:
   ```bash
   fastlane match_sync
   ```

3. **Build for TestFlight**:
   ```bash
   fastlane beta
   ```

4. **Build for App Store**:
   ```bash
   fastlane release
   ```

## Available Lanes

- `build`: Build the iOS app
- `beta`: Build and upload to TestFlight
- `release`: Build and upload to App Store
- `development`: Build for development
- `match_sync`: Sync certificates and provisioning profiles
- `match_init`: Initialize Match (run once)

For detailed documentation, see [FASTLANE_RELEASE.md](../FASTLANE_RELEASE.md).

