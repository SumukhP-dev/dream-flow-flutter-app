# Flutter Frontend Structure

## Overview

The Flutter app is organized with clear separation between:
- **Core services** (`core/`) - Essential app functionality (auth, story, audio, video)
- **Shared services** (`shared/`) - Cross-cutting utilities and features
- **Screens** (`screens/`) - UI screens/pages
- **Widgets** (`widgets/`) - Reusable UI components
- **Models** (`models/`) - Data models (for future use)
- **Localization** (`l10n/`) - Translation files

## Directory Structure

```
frontend_flutter/lib/
│
├── 📄 main.dart                # App entry point
│
├── 📁 core/                    # 🔑 Core App Services
│   ├── auth_service.dart      # Authentication
│   ├── story_service.dart     # Story generation API
│   ├── audio_service.dart     # Audio playback
│   └── video_service.dart     # Video playback
│
├── 📁 shared/                  # 🔧 Shared Services & Utilities
│   ├── accessibility_service.dart
│   ├── feedback_service.dart
│   ├── notification_service.dart
│   ├── payment_service.dart
│   ├── preferences_service.dart
│   ├── sentry_service.dart
│   ├── session_asset_service.dart
│   ├── story_card_service.dart
│   └── subscription_service.dart
│
├── 📁 screens/                 # 📱 UI Screens
│   ├── accessibility_settings_screen.dart
│   ├── analytics_screen.dart
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── session_screen.dart
│   ├── signup_screen.dart
│   └── subscription_screen.dart
│
├── 📁 widgets/                 # 🧩 Reusable Widgets
│   └── feedback_modal.dart
│
├── 📁 models/                  # 📦 Data Models (for future use)
│
└── 📁 l10n/                    # 🌐 Localization
    ├── app_en.arb
    └── app_es.arb
```

## Key Benefits

✅ **Clear Organization**: Core vs shared services are separated  
✅ **Consistent Structure**: All folders at the same level - easy to scan  
✅ **Scalable**: Easy to add new screens, widgets, or services  
✅ **Maintainable**: Related code grouped together

## Import Examples

### From core (essential services)
```dart
import 'package:dream_flow/core/auth_service.dart';
import 'package:dream_flow/core/story_service.dart';
import 'package:dream_flow/core/audio_service.dart';
```

### From shared (utilities)
```dart
import 'package:dream_flow/shared/accessibility_service.dart';
import 'package:dream_flow/shared/preferences_service.dart';
import 'package:dream_flow/shared/subscription_service.dart';
```

### From screens
```dart
import 'package:dream_flow/screens/home_screen.dart';
import 'package:dream_flow/screens/session_screen.dart';
```

### From widgets
```dart
import 'package:dream_flow/widgets/feedback_modal.dart';
```

## Service Categories

### Core Services
Essential functionality required for the app to function:
- **auth_service**: User authentication and session management
- **story_service**: Story generation API calls
- **audio_service**: Audio playback and control
- **video_service**: Video playback and control

### Shared Services
Cross-cutting concerns and optional features:
- **accessibility_service**: Accessibility settings
- **feedback_service**: User feedback submission
- **notification_service**: Push notifications
- **payment_service**: Payment processing
- **preferences_service**: User preferences storage
- **sentry_service**: Error tracking
- **session_asset_service**: Session asset management
- **story_card_service**: Story card UI logic
- **subscription_service**: Subscription management

