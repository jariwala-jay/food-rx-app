"""Shared slowapi rate limiter, keyed by client IP.

In-memory storage: state resets per process restart and isn't shared across
Cloud Run replicas, so this is a best-effort throttle rather than a hard
guarantee. It still meaningfully raises the cost of scripted brute-forcing
and account enumeration on top of the existing per-account lockout (see
LOCK_THRESHOLD in routers/auth.py). Requires uvicorn's --proxy-headers flag
(see Dockerfile) so get_remote_address reads the real client IP from
X-Forwarded-For instead of Cloud Run's internal proxy IP.
"""

from fastapi import Request
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)


async def rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    """Same shape as every other error response in this API ({"detail": ...}).
    slowapi's built-in handler uses {"error": ...} instead, which the Flutter
    client's error parsing (ApiClient._throwFromResponse, keyed on "detail")
    doesn't recognize — callers would see a generic fallback message instead
    of an explanation."""
    response = JSONResponse(
        {"detail": "Too many requests. Please try again in a minute."},
        status_code=429,
    )
    return request.app.state.limiter._inject_headers(response, request.state.view_rate_limit)
