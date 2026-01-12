#!/bin/bash
set -e  # Exit on error

echo "🚀 Starting Flutter Web Build for Vercel..."

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "📂 Script directory: $SCRIPT_DIR"

# Change to the Flutter app directory
cd "$SCRIPT_DIR"
echo "📂 Working directory: $(pwd)"

# Define Flutter installation directory
FLUTTER_DIR="/vercel/.local/flutter"

# Install Flutter if not already cached
if [ ! -d "$FLUTTER_DIR" ]; then
    echo "📦 Installing Flutter SDK..."
    mkdir -p /vercel/.local
    cd /vercel/.local
    git clone https://github.com/flutter/flutter.git -b stable --depth 1
    echo "✅ Flutter SDK installed"
    # Return to app directory
    cd "$SCRIPT_DIR"
else
    echo "✅ Flutter SDK found (cached)"
fi

# Add Flutter to PATH
export PATH="$PATH:$FLUTTER_DIR/bin"

# Verify Flutter installation
echo "🔍 Flutter version:"
flutter --version

# Enable web support
echo "🌐 Enabling Flutter web..."
flutter config --enable-web

# Get dependencies
echo "📚 Getting dependencies..."
flutter pub get

# Build web app with environment variables
echo "🏗️  Building Flutter web app..."
flutter build web \
    --release \
    --dart-define=BACKEND_URL="${BACKEND_URL}" \
    --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
    --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
    --dart-define=SENTRY_DSN="${SENTRY_DSN:-}" \
    --dart-define=ENVIRONMENT="${ENVIRONMENT:-production}"

echo "✅ Build completed successfully!"
echo "📁 Output directory: $SCRIPT_DIR/build/web"
