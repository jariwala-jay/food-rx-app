# Xcode Cloud (Flutter iOS)

This repo includes **`ios/ci_scripts/ci_post_clone.sh`**, which Xcode Cloud runs after cloning the repository and **before** archiving. It:

1. Installs the **Flutter SDK** (not bundled on Apple’s CI images).
2. Runs **`flutter precache --ios`**, **`flutter pub get`**, and **`flutter build ios --config-only`** so **`ios/Flutter/Generated.xcconfig`** exists (fixes missing `Generated.xcconfig` / Pods `*.xcfilelist` errors).
3. Runs **`pod install`** under **`ios/`**.

## Environment file (`.env`)

`pubspec.yaml` includes **`.env`** as an asset. The real **`.env`** is **gitignored** (secrets), so Xcode Cloud clones do not contain it unless we create it.

**`ci_post_clone.sh`** copies **`.env.example`** → **`.env`** when `.env` is missing so **`flutter build`** can bundle assets. Production API keys are **not** in `.env.example`; for release builds you should still configure real values via your normal process (e.g. a filled `.env` only on secure builders, or future `--dart-define` migration).

Locally: `cp .env.example .env` and edit.

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

Flutter / Apple expect **`ci_scripts`** next to the Xcode workspace. For this app, that is **`ios/ci_scripts/`** (same folder as **`Runner.xcworkspace`**). See [Flutter — Xcode Cloud](https://docs.flutter.dev/deployment/cd#xcode-cloud).

## Troubleshooting: `PhaseScriptExecution failed with a nonzero exit code`

That message is **generic**. Xcode runs several shell-script phases; the one that failed is usually one of these:

| Build phase name (in logs) | What it runs |
|----------------------------|----------------|
| **Run Script** | `$FLUTTER_ROOT/.../xcode_backend.sh` **`build`** (compiles Dart / prepares the app) |
| **Thin Binary** | `xcode_backend.sh` **`embed_and_thin`** (embeds Flutter, thins frameworks) |
| **[CP] Check Pods Manifest.lock** | Fails if `Podfile.lock` ≠ `Pods/Manifest.lock` (run `cd ios && pod install` locally, commit **`Podfile.lock`**) |
| **[CP] Copy Pods Resources** | CocoaPods resource copy script |

**What to do**

1. In the Xcode Cloud log, open the failed **`xcodebuild archive`** step and search for **`error:`** or the phase name above — the **first real error is usually 10–40 lines above** `PhaseScriptExecution`.
2. Confirm **`ci_post_clone.sh`** finished successfully and printed `ci_post_clone: OK — FLUTTER_ROOT=...`. If post-clone failed, `ios/Flutter/Generated.xcconfig` may be missing and **`FLUTTER_ROOT`** will be empty in the **Run Script** / **Thin Binary** steps.
3. This project sets **`showEnvVarsInLog = 1`** on the Flutter **Run Script** and **Thin Binary** phases so logs include **`FLUTTER_ROOT`** (verify it points at `$HOME/flutter` on the builder).
4. Reproduce locally: `flutter pub get && flutter build ios --config-only && (cd ios && pod install)` then **`flutter build ipa`** or **Archive** in Xcode.

If **`Run Script`** fails, scroll up for **Dart / Flutter** compiler output. If **`Thin Binary`** fails, look for **codesign** / **framework** messages (archive uses automatic signing; team **`DEVELOPMENT_TEAM`** must match the app).

If the log says **`No file or variants found for asset: .env`**, the clone had no **`.env`** (it is gitignored). Ensure **`.env.example`** is committed and **`ci_post_clone.sh`** runs (it copies `.env.example` → `.env` when needed).
