#!/bin/bash
# Simple script to install Flutter on Vercel build environment
set -e

FLUTTER_VERSION="stable"
FLUTTER_DIR="/tmp/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
    echo "Installing Flutter $FLUTTER_VERSION..."
    git clone https://github.com/flutter/flutter.git -b $FLUTTER_VERSION --depth 1 $FLUTTER_DIR
fi

export PATH="$PATH:$FLUTTER_DIR/bin"
flutter config --enable-web
flutter doctor -v
