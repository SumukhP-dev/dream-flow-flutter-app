#!/bin/bash
# Bash script to run Flutter integration tests
# Usage: ./run_integration_tests.sh [device-id]

DEVICE_ID=${1:-"emulator-5554"}

echo "=== Dream Flow Integration Tests ==="
echo ""

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "Error: Flutter is not in PATH"
    exit 1
fi

# Check if device is available
echo "Checking for device: $DEVICE_ID"
if ! flutter devices | grep -q "$DEVICE_ID"; then
    echo "Warning: Device $DEVICE_ID not found. Available devices:"
    flutter devices
    echo ""
    echo "Attempting to continue anyway..."
fi

# Set environment variables
export SUPABASE_URL="https://dbpvmfglduprtbpaygmo.supabase.co"
export SUPABASE_ANON_KEY="sb_secret_f7om8DHi_eeV89aYbwVJXQ_uc546iWP"
export BACKEND_URL="http://10.0.2.2:8080"

echo "Configuration:"
echo "  SUPABASE_URL: $SUPABASE_URL"
echo "  BACKEND_URL: $BACKEND_URL"
echo ""

# Test files
TEST_FILES=(
    "integration_test/app_test.dart"
    "integration_test/auth_test.dart"
    "integration_test/session_screen_test.dart"
    "integration_test/home_screen_test.dart"
)

PASSED=0
FAILED=0
ERRORS=0
SKIPPED=0

for test_file in "${TEST_FILES[@]}"; do
    if [ -f "$test_file" ]; then
        echo "Running: $test_file"
        echo "----------------------------------------"
        
        if flutter test \
            --dart-define=SUPABASE_URL="$SUPABASE_URL" \
            --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
            --dart-define=BACKEND_URL="$BACKEND_URL" \
            "$test_file"; then
            echo "✓ PASSED: $test_file"
            ((PASSED++))
        else
            echo "✗ FAILED: $test_file"
            ((FAILED++))
        fi
        echo ""
    else
        echo "⚠ SKIPPED: $test_file (not found)"
        ((SKIPPED++))
    fi
done

# Summary
echo "=== Test Summary ==="
echo "Passed:  $PASSED"
echo "Failed:  $FAILED"
echo "Skipped: $SKIPPED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "All tests completed successfully!"
    exit 0
else
    echo "Some tests failed. Check output above."
    exit 1
fi

