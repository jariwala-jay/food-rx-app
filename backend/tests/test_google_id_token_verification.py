"""
Unit tests for app.firebase_admin_app.verify_google_id_token. Covers the
core invariant: a validly-signed Google ID token whose `aud` claim isn't
one of MyFoodRx's own OAuth client IDs must be rejected, even though the
signature and issuer check out.

Mocks google.oauth2.id_token.verify_oauth2_token, so no network access or
real Google token is needed.

Run:
    cd backend && python3 -m unittest tests.test_google_id_token_verification -v
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import patch

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.firebase_admin_app import _ALLOWED_AUDIENCES, verify_google_id_token  # noqa: E402

_ALLOWED_AUD = next(iter(_ALLOWED_AUDIENCES))
_FOREIGN_AUD = "999999999999-someunrelatedapp.apps.googleusercontent.com"


def _claims(aud: str, email_verified: bool = True) -> dict:
    return {
        "iss": "https://accounts.google.com",
        "aud": aud,
        "sub": "1234567890",
        "email": "user@example.com",
        "email_verified": email_verified,
        "name": "Test User",
        "picture": "https://example.com/photo.jpg",
        "exp": 9999999999,
    }


class TestVerifyGoogleIdToken(unittest.IsolatedAsyncioTestCase):
    @patch("app.firebase_admin_app.google_id_token.verify_oauth2_token")
    async def test_accepts_token_with_allowed_audience(self, mock_verify):
        mock_verify.return_value = _claims(_ALLOWED_AUD)
        claims = await verify_google_id_token("valid-token")
        self.assertEqual(claims["email"], "user@example.com")
        # The raw token string must be what's passed to Google's verifier.
        self.assertEqual(mock_verify.call_args[0][0], "valid-token")

    @patch("app.firebase_admin_app.google_id_token.verify_oauth2_token")
    async def test_rejects_token_with_foreign_audience(self, mock_verify):
        """A validly-signed token minted for a different app must be
        rejected, even with a valid signature and issuer."""
        mock_verify.return_value = _claims(_FOREIGN_AUD)
        with self.assertRaises(ValueError) as ctx:
            await verify_google_id_token("token-for-another-app")
        self.assertIn("not issued for this app", str(ctx.exception))

    @patch("app.firebase_admin_app.google_id_token.verify_oauth2_token")
    async def test_rejects_unverified_email(self, mock_verify):
        mock_verify.return_value = _claims(_ALLOWED_AUD, email_verified=False)
        with self.assertRaises(ValueError) as ctx:
            await verify_google_id_token("valid-token-unverified-email")
        self.assertIn("not verified", str(ctx.exception))

    @patch("app.firebase_admin_app.google_id_token.verify_oauth2_token")
    async def test_rejects_invalid_signature_or_expired(self, mock_verify):
        mock_verify.side_effect = ValueError("Token expired")
        with self.assertRaises(ValueError) as ctx:
            await verify_google_id_token("garbage-token")
        self.assertIn("Invalid or expired", str(ctx.exception))

    async def test_rejects_empty_token_without_network_call(self):
        with self.assertRaises(ValueError):
            await verify_google_id_token("")

    def test_allowed_audiences_cover_both_platforms(self):
        # Sanity: iOS and Android/Web OAuth client IDs are all present so a
        # sign-in from either platform is accepted, and every entry looks
        # like a real Google OAuth client ID (not an arbitrary string).
        self.assertEqual(len(_ALLOWED_AUDIENCES), 3)
        for aud in _ALLOWED_AUDIENCES:
            self.assertTrue(aud.endswith(".apps.googleusercontent.com"))


if __name__ == "__main__":
    unittest.main()
