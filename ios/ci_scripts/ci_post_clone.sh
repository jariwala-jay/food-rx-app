#!/bin/sh
# Xcode Cloud: run after clone, before archive.
# See: https://docs.flutter.dev/deployment/cd#xcode-cloud
set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Install Flutter SDK (not present on Xcode Cloud images by default).
# If `stable` clone fails (rare GitHub issue), set FLUTTER_VERSION to a tag e.g. 3.27.4 in Xcode Cloud env.
FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$HOME/flutter"
fi
export PATH="$PATH:$HOME/flutter/bin"

flutter --version
flutter precache --ios
flutter pub get

# Creates ios/Flutter/Generated.xcconfig and prepares iOS build (fixes "could not find Generated.xcconfig").
flutter build ios --config-only

# CocoaPods (Flutter may invoke this; explicit install keeps Podfile + xcfilelists in sync).
HOMEBREW_NO_AUTO_UPDATE=1
brew install cocoapods 2>/dev/null || true

cd ios
pod install

exit 0
