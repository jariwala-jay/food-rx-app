"""Domain-ownership verification for Android App Links / iOS Universal
Links — see AndroidManifest.xml's autoVerify intent-filter and
Runner.entitlements' associated-domains entry.

Kept out of app/main.py (which pulls in chromadb via the chatbot router)
so this stays cheap to import and test.
"""

from fastapi import APIRouter
from fastapi.responses import JSONResponse

from app.config import settings

router = APIRouter()


@router.get("/.well-known/assetlinks.json")
async def android_asset_links():
    """Empty list until ANDROID_SHA256_CERT_FINGERPRINTS is set (see backend/.env.example)."""
    fingerprints = [
        f.strip() for f in settings.android_sha256_cert_fingerprints.split(",") if f.strip()
    ]
    if not fingerprints:
        return []
    return [
        {
            "relation": ["delegate_permission/common.handle_all_urls"],
            "target": {
                "namespace": "android_app",
                "package_name": settings.android_package_name,
                "sha256_cert_fingerprints": fingerprints,
            },
        }
    ]


@router.get("/.well-known/apple-app-site-association")
async def apple_app_site_association():
    """Empty applinks config until APPLE_TEAM_ID is set (see backend/.env.example)."""
    if not settings.apple_team_id:
        return JSONResponse(content={"applinks": {"apps": [], "details": []}})
    return JSONResponse(
        content={
            "applinks": {
                "apps": [],
                "details": [
                    {
                        "appID": f"{settings.apple_team_id}.{settings.apple_bundle_id}",
                        "paths": ["/auth/reset-password/open*"],
                    }
                ],
            }
        }
    )
