# Xcode Cloud (Flutter iOS)

This repo includes **`ios/ci_scripts/ci_post_clone.sh`**, which Xcode Cloud runs after cloning the repository and **before** archiving. It:

1. Installs the **Flutter SDK** (not bundled on Apple’s CI images).
2. Runs **`flutter precache --ios`**, **`flutter pub get`**, and **`flutter build ios --config-only`** so **`ios/Flutter/Generated.xcconfig`** exists (fixes missing `Generated.xcconfig` / Pods `*.xcfilelist` errors).
3. Runs **`pod install`** under **`ios/`**.

## Requirements

- Workflow uses an **Xcode** version compatible with your Flutter channel (see [Flutter docs](https://docs.flutter.dev/deployment/cd#xcode-cloud)).

## Optional: pin Flutter version

If cloning `stable` fails in CI, set an environment variable in the Xcode Cloud workflow:

- **`FLUTTER_VERSION`** = a Flutter git tag (e.g. `3.27.4`).

## Manual check locally

From the repo root:

```bash
flutter pub get
flutter build ios --config-only
cd ios && pod install
```

Then open **`ios/Runner.xcworkspace`** and **Archive**.

## Script location

Apple expects **`ci_scripts`** next to the Xcode project. For this app, that is **`ios/ci_scripts/`** (same folder as **`Runner.xcworkspace`**).
