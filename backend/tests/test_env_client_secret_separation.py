"""
Tests for the backend-secret / client-safe config split (pubspec.yaml
`assets:` vs backend/app/config.py). Only reads the tracked .env.example
files and config.py's Config class — never the real .env files — so these
never touch real secret values.

Run:
    cd backend && python3 -m unittest tests.test_env_client_secret_separation -v
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_ROOT.parent
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

# Keys that must never appear in the Flutter-bundled root .env / .env.example.
BACKEND_ONLY_KEYS = {
    "SECRET_KEY",
    "MONGODB_URL",
    "TRACKER_RESET_SECRET",
    "GEMINI_API_KEY",
    "GROQ_API_KEY",
    "API_HOST",
    "API_PORT",
    "FIREBASE_PROJECT_ID",
    "GMAIL_USER",
    "GMAIL_APP_PASSWORD",
}

# Keys the client genuinely needs at runtime (see dotenv.env[...] reads under
# lib/) — these are expected to stay in the bundled root .env.
CLIENT_REQUIRED_KEYS = {
    "API_BASE_URL",
    "DEBUG",
    "RAPID_API_KEY",
    "SHOW_SCALING_CONVERSION",
    "SHOW_TOUR_DEBUG_BUTTON",
    "MANDATORY_PLAN_VIDEO",
    "DASH_VIDEO_URL",
    "DASH_VIDEO_URL_FULL",
    "MYPLATE_VIDEO_URL",
    "MYPLATE_VIDEO_URL_FULL",
    "DIABETES_PLATE_VIDEO_URL",
    "DIABETES_PLATE_VIDEO_URL_FULL",
}


def _keys_in_file(path: Path) -> set[str]:
    keys = set()
    for line in path.read_text().splitlines():
        s = line.strip().lstrip("#").strip()
        if "=" in s:
            keys.add(s.split("=", 1)[0].strip())
    return keys


class TestClientBackendSecretSeparation(unittest.TestCase):
    def test_root_env_example_has_no_backend_only_keys(self):
        keys = _keys_in_file(REPO_ROOT / ".env.example")
        leaked = keys & BACKEND_ONLY_KEYS
        self.assertFalse(
            leaked,
            f"Backend-only keys must not appear in the Flutter-bundled .env.example: {leaked}",
        )

    def test_root_env_example_still_has_client_required_keys(self):
        # Guards against over-correcting and accidentally stripping a key the
        # client genuinely reads via dotenv.env[...] at runtime.
        keys = _keys_in_file(REPO_ROOT / ".env.example")
        missing = CLIENT_REQUIRED_KEYS - keys
        self.assertFalse(missing, f".env.example is missing client-required keys: {missing}")

    def test_backend_env_example_documents_the_moved_keys(self):
        keys = _keys_in_file(BACKEND_ROOT / ".env.example")
        missing = BACKEND_ONLY_KEYS - keys
        self.assertFalse(missing, f"backend/.env.example is missing: {missing}")

    def test_pubspec_still_bundles_a_client_config_file(self):
        # Sanity: we intentionally keep bundling a slimmed-down, client-safe
        # `.env` (see .env.example's banner) rather than removing config
        # entirely, since RAPID_API_KEY/API_BASE_URL/feature flags/video URLs
        # are genuinely needed client-side and Xcode Cloud's ci_post_clone.sh
        # already expects this exact filename.
        pubspec = (REPO_ROOT / "pubspec.yaml").read_text()
        self.assertIn("- .env", pubspec)

    def test_config_py_only_reads_backend_env(self):
        # Architectural enforcement, not just convention: the backend must
        # not be able to read secrets from the Flutter-bundled root .env,
        # even if one is mistakenly reintroduced there in the future.
        from app.config import Settings

        self.assertEqual(Settings.Config.env_file, ".env")


if __name__ == "__main__":
    unittest.main()
