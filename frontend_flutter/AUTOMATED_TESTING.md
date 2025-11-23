# Automated Testing Guide for Dream Flow

## Overview

This guide explains how to run automated tests for the Dream Flow Flutter application. The test suite includes unit tests, widget tests, and integration tests.

## Test Structure

```
frontend_flutter/
├── test/
│   ├── widget_test.dart          # Basic widget tests
│   └── session_screen_test.dart   # SessionScreen specific tests
├── integration_test/
│   ├── app_test.dart              # App launch and basic navigation
│   ├── auth_test.dart             # Authentication flow tests
│   ├── session_screen_test.dart   # Session screen functionality
│   └── home_screen_test.dart      # Home screen form tests
└── run_integration_tests.ps1      # PowerShell test runner
```

## Prerequisites

1. **Flutter SDK** installed and in PATH
2. **Android Emulator** running (or physical device connected)
3. **Backend Server** running on http://localhost:8080
4. **Dependencies** installed: `flutter pub get`

## Running Tests

### Option 1: Run All Tests (PowerShell)

```powershell
cd frontend_flutter
.\run_integration_tests.ps1
```

### Option 2: Run Individual Test Files

```powershell
# Unit/Widget Tests
flutter test test/session_screen_test.dart

# Integration Tests (requires device)
flutter test integration_test/app_test.dart `
  --dart-define=SUPABASE_URL=https://dbpvmfglduprtbpaygmo.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=sb_secret_f7om8DHi_eeV89aYbwVJXQ_uc546iWP `
  --dart-define=BACKEND_URL=http://10.0.2.2:8080
```

### Option 3: Run Tests on Specific Device

```powershell
flutter test integration_test/app_test.dart -d emulator-5554 `
  --dart-define=SUPABASE_URL=https://dbpvmfglduprtbpaygmo.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=sb_secret_f7om8DHi_eeV89aYbwVJXQ_uc546iWP `
  --dart-define=BACKEND_URL=http://10.0.2.2:8080
```

## Test Categories

### 1. Unit Tests (`test/` directory)

**session_screen_test.dart**
- Tests audio status string interpolation
- Verifies SessionScreen widget builds correctly
- Validates ternary operator syntax

**Run:**
```powershell
flutter test test/session_screen_test.dart
```

### 2. Integration Tests (`integration_test/` directory)

**app_test.dart**
- App launch verification
- Login screen display
- Navigation to sign up
- Color API fixes verification

**auth_test.dart**
- Complete sign up flow
- Sign in with credentials
- Invalid credentials error handling

**session_screen_test.dart**
- Story content display
- Audio status text interpolation
- Frames gallery rendering
- Video card display

**home_screen_test.dart**
- Form field accessibility
- Profile form filling
- Story prompt input

## Automated Test Script

### Quick Test Runner

Create a simple batch script for Windows:

```powershell
# quick_test.ps1
$env:SUPABASE_URL = "https://dbpvmfglduprtbpaygmo.supabase.co"
$env:SUPABASE_ANON_KEY = "sb_secret_f7om8DHi_eeV89aYbwVJXQ_uc546iWP"
$env:BACKEND_URL = "http://10.0.2.2:8080"

Write-Host "Running unit tests..." -ForegroundColor Cyan
flutter test test/

Write-Host "`nRunning integration tests..." -ForegroundColor Cyan
flutter test integration_test/ `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY `
  --dart-define=BACKEND_URL=$env:BACKEND_URL
```

## Test Configuration

### Environment Variables

Tests require these environment variables (passed via `--dart-define`):

- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Your Supabase anonymous key
- `BACKEND_URL`: Backend API URL (use `http://10.0.2.2:8080` for Android emulator)

### Test Data

Tests use dynamic test data to avoid conflicts:
- Email: `autotest_<timestamp>@example.com`
- Password: `TestPassword123!`

## Continuous Integration

### GitHub Actions Example

```yaml
name: Flutter Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.7'
      - run: cd frontend_flutter && flutter pub get
      - run: cd frontend_flutter && flutter test
      - run: cd frontend_flutter && flutter test integration_test/ \
          --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
          --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }} \
          --dart-define=BACKEND_URL=http://localhost:8080
```

## Troubleshooting

### Issue: "Flutter failed to delete a directory"

**Solution:** Close any IDEs or processes using the build directory, then:
```powershell
flutter clean
flutter pub get
```

### Issue: "Device not found"

**Solution:** 
1. Check emulator is running: `flutter devices`
2. Start emulator: `flutter emulators --launch <emulator-id>`
3. Wait for emulator to fully boot

### Issue: "Tests timeout"

**Solution:** Increase timeout in test files:
```dart
await tester.pumpAndSettle(const Duration(seconds: 10));
```

### Issue: "Supabase connection failed"

**Solution:**
1. Verify Supabase credentials are correct
2. Check network connectivity
3. Ensure Supabase project is active

## Test Coverage

Current test coverage includes:

- ✅ App launch and initialization
- ✅ Authentication flows (sign up, sign in)
- ✅ Session screen rendering
- ✅ Audio status text interpolation
- ✅ Form field interactions
- ✅ Color API fixes verification
- ✅ Navigation flows

## Adding New Tests

### Creating a New Test File

1. Create file in `integration_test/` or `test/` directory
2. Import required packages:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
```
3. Write test cases using `testWidgets()`
4. Add to test runner script

### Example Test Structure

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dream_flow/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Feature Name', () {
    testWidgets('Test description', (WidgetTester tester) async {
      // Arrange
      app.main();
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Button'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Expected Result'), findsOneWidget);
    });
  });
}
```

## Best Practices

1. **Use descriptive test names** that explain what is being tested
2. **Keep tests independent** - each test should be able to run alone
3. **Use `pumpAndSettle()`** to wait for animations and async operations
4. **Clean up test data** to avoid conflicts between test runs
5. **Mock external dependencies** when possible for faster tests
6. **Test error cases** as well as success cases

## Next Steps

- [ ] Add more comprehensive integration tests
- [ ] Set up CI/CD pipeline
- [ ] Add performance tests
- [ ] Add accessibility tests
- [ ] Generate test coverage reports

