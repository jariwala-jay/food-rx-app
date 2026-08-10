"""
Tests for the App Links / Universal Links verification endpoints
(app.routers.well_known): safe no-op when unconfigured, correct shape once
ANDROID_SHA256_CERT_FINGERPRINTS / APPLE_TEAM_ID are set.

Run:
    cd backend && python3 -m unittest tests.test_well_known_app_links -v
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

from fastapi import FastAPI
from fastapi.testclient import TestClient

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.config import settings  # noqa: E402
from app.routers import well_known  # noqa: E402


def _client() -> TestClient:
    app = FastAPI()
    app.include_router(well_known.router)
    return TestClient(app)


class TestWellKnownAppLinks(unittest.TestCase):
    def setUp(self) -> None:
        # Save/restore so these tests can't leak config into others.
        self._orig_android = settings.android_sha256_cert_fingerprints
        self._orig_team = settings.apple_team_id

    def tearDown(self) -> None:
        settings.android_sha256_cert_fingerprints = self._orig_android
        settings.apple_team_id = self._orig_team

    def test_assetlinks_empty_when_unconfigured(self) -> None:
        settings.android_sha256_cert_fingerprints = ""
        resp = _client().get("/.well-known/assetlinks.json")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json(), [])

    def test_assetlinks_populated_when_configured(self) -> None:
        settings.android_sha256_cert_fingerprints = "AA:BB:CC, DD:EE:FF"
        resp = _client().get("/.well-known/assetlinks.json")
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(len(body), 1)
        target = body[0]["target"]
        self.assertEqual(target["namespace"], "android_app")
        self.assertEqual(target["package_name"], "com.shield.myfoodrx")
        self.assertEqual(target["sha256_cert_fingerprints"], ["AA:BB:CC", "DD:EE:FF"])
        self.assertIn("delegate_permission/common.handle_all_urls", body[0]["relation"])

    def test_apple_app_site_association_empty_when_unconfigured(self) -> None:
        settings.apple_team_id = ""
        resp = _client().get("/.well-known/apple-app-site-association")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json(), {"applinks": {"apps": [], "details": []}})

    def test_apple_app_site_association_populated_when_configured(self) -> None:
        settings.apple_team_id = "ABCDE12345"
        resp = _client().get("/.well-known/apple-app-site-association")
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        detail = body["applinks"]["details"][0]
        self.assertEqual(detail["appID"], "ABCDE12345.com.shield.myfoodrx")
        self.assertEqual(detail["paths"], ["/auth/reset-password/open*"])


if __name__ == "__main__":
    unittest.main()
