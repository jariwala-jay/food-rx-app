"""Google identity verification for Google Sign-In.

Verifies a Google-issued ID token (JWT) and checks its `aud` claim against
this app's own OAuth client IDs (_ALLOWED_AUDIENCES) — that's what binds
the token to this app specifically. An OAuth access token can't be checked
this way: Google's userinfo endpoint will resolve any access token that has
basic profile/email scope, regardless of which app it was issued to.
"""

import asyncio

from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

# MyFoodRx's OAuth client IDs (android/app/google-services.json,
# ios/Runner/GoogleService-Info.plist). Only tokens audienced to one of
# these are accepted.
_ALLOWED_AUDIENCES = {
    # iOS (GoogleService-Info.plist: CLIENT_ID)
    "609996001749-rnhqhjpga61ghu4ein71ogrg7pmfoss7.apps.googleusercontent.com",
    # Android (google-services.json: oauth_client, client_type 1)
    "609996001749-dvbq9k9no2fmrba2rvgd32tkug77258f.apps.googleusercontent.com",
    # Auto-created web client (google-services.json: oauth_client, client_type
    # 3) — the default audience google_sign_in's Android implementation uses
    # unless a serverClientId is explicitly configured.
    "609996001749-8hsat17p0d38d5m7buel45t639e59jt8.apps.googleusercontent.com",
}

# Reused across requests: verify_oauth2_token fetches (and caches) Google's
# public signing certs over HTTP via this transport.
_request = google_requests.Request()


async def verify_google_id_token(id_token_str: str) -> dict:
    """
    Verify a Google Sign-In ID token (JWT).

    Validates the cryptographic signature against Google's published certs
    and standard claims (issuer, expiry — handled by google-auth), then
    checks the audience against this app's own OAuth client IDs and that
    the email is verified.

    Returns the decoded claims (email, email_verified, name, picture, sub, ...).

    Raises:
        ValueError: token is invalid, expired, wrong audience, or email unverified.
    """
    if not id_token_str:
        raise ValueError("ID token required")

    try:
        # Network call under the hood (cert fetch/refresh) — off the event
        # loop so it doesn't block other requests.
        claims = await asyncio.to_thread(
            google_id_token.verify_oauth2_token, id_token_str, _request
        )
    except ValueError as exc:
        raise ValueError("Invalid or expired Google ID token") from exc

    if claims.get("aud") not in _ALLOWED_AUDIENCES:
        raise ValueError("Google ID token was not issued for this app")

    if not claims.get("email_verified"):
        raise ValueError("Google account email is not verified")

    return claims
