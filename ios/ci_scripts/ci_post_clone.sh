#!/bin/sh
# Xcode Cloud: run after clone, before archive.
# See: https://docs.flutter.dev/deployment/cd#xcode-cloud
set -e

cd "${CI_PRIMARY_REPOSITORY_PATH:?CI_PRIMARY_REPOSITORY_PATH is not set}"

# Install Flutter SDK (not present on Xcode Cloud images by default).
# If `stable` clone fails (rare GitHub issue), set FLUTTER_VERSION to a tag e.g. 3.27.4 in Xcode Cloud env.
FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$HOME/flutter"
fi
export FLUTTER_ROOT="$HOME/flutter"
export PATH="$PATH:$FLUTTER_ROOT/bin"

flutter --version
flutter precache --ios
flutter pub get

# Creates ios/Flutter/Generated.xcconfig (contains FLUTTER_ROOT for Xcode Run Script phases).
flutter build ios --config-only

# CocoaPods: many images include `pod`; install only if missing (do not ignore failures).
if ! command -v pod >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
fi

( cd ios && pod install )

# If this file is missing or FLUTTER_ROOT is unset, "Run Script" / "Thin Binary" fail with PhaseScriptExecution.
if [ ! -f ios/Flutter/Generated.xcconfig ]; then
  echo "error: ios/Flutter/Generated.xcconfig missing after flutter build ios --config-only" >&2
  exit 1
fi
if ! grep -q "^FLUTTER_ROOT=" ios/Flutter/Generated.xcconfig; then
  echo "error: FLUTTER_ROOT not set in ios/Flutter/Generated.xcconfig" >&2
  exit 1
fi

echo "ci_post_clone: OK — $(grep '^FLUTTER_ROOT=' ios/Flutter/Generated.xcconfig | head -1)"

exit 0
