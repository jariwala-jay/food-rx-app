"""Google identity verification for Google Sign-In.

Verifies a Google OAuth access token by calling Google's userinfo endpoint.
No Firebase Admin SDK or service account credentials required.
"""

import httpx


async def verify_google_access_token(access_token: str) -> dict:
    """
    Verify a Google OAuth access token by calling Google's userinfo API.
    Returns a dict with at least: email, email_verified, name, picture, sub.

    Raises:
        ValueError: token is invalid, expired, or email is unverified.
        httpx.HTTPError: network error contacting Google.
    """
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(
            "https://www.googleapis.com/oauth2/v3/userinfo",
            headers={"Authorization": f"Bearer {access_token}"},
        )

    if resp.status_code != 200:
        raise ValueError("Invalid or expired Google access token")

    data = resp.json()

    if not data.get("email_verified"):
        raise ValueError("Google account email is not verified")

    return data
