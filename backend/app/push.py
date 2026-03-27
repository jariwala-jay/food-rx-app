import base64
import json
from typing import Any

import firebase_admin
from firebase_admin import credentials, messaging

from app.config import settings


_firebase_initialized = False


def _init_firebase_if_needed() -> bool:
    """
    Initialize Firebase Admin SDK if configured.
    Returns True if initialized (or already initialized), False if not configured.
    """
    global _firebase_initialized
    if _firebase_initialized:
        return True

    sa_json = (settings.firebase_service_account_json or "").strip()
    if not sa_json:
        # Prefer new concise name, then fall back to legacy name.
        b64 = (
            (settings.firebase_service_account_b64 or "").strip()
            or (settings.firebase_service_account_json_base64 or "").strip()
        )
        if b64:
            try:
                sa_json = base64.b64decode(b64).decode("utf-8")
            except Exception:
                sa_json = ""

    if sa_json:
        try:
            info = json.loads(sa_json)
            cred = credentials.Certificate(info)
            firebase_admin.initialize_app(
                cred,
                {"projectId": settings.firebase_project_id} if settings.firebase_project_id else None,
            )
            _firebase_initialized = True
            return True
        except Exception:
            return False

    # Keyless fallback for environments like Cloud Run where ADC is available
    # and org policy disallows downloadable service account keys.
    try:
        firebase_admin.initialize_app(
            options={"projectId": settings.firebase_project_id}
            if settings.firebase_project_id
            else None
        )
        _firebase_initialized = True
        return True
    except Exception:
        return False


async def send_push_to_fcm_token(
    *,
    token: str,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> dict[str, Any]:
    """
    Send a push notification via FCM to a single device token.
    Returns { ok, messageId? }.
    """
    if not token:
        return {"ok": False, "error": "missing_token"}
    if not _init_firebase_if_needed():
        return {"ok": False, "error": "fcm_not_configured"}

    msg = messaging.Message(
        token=token,
        notification=messaging.Notification(title=title, body=body),
        data=data or None,
    )
    try:
        message_id = messaging.send(msg)
        return {"ok": True, "messageId": message_id}
    except Exception as e:
        return {"ok": False, "error": str(e)}

