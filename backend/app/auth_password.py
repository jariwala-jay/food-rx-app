"""Password hashing.

New and rotated hashes use bcrypt. HMAC-SHA256 (this module's original
scheme) is still accepted so existing accounts keep working, but is never
produced for new hashes — routers/auth.py calls needs_rehash() after a
successful login and transparently re-hashes the password with bcrypt, so
every active account migrates off HMAC-SHA256 the next time its owner signs
in without a forced password reset.
"""
import base64
import hashlib
import hmac

import bcrypt

# bcrypt silently truncates input beyond 72 bytes; capping here keeps hashing
# and verification consistent instead of quietly ignoring part of long
# passwords.
_BCRYPT_MAX_PASSWORD_BYTES = 72

_BCRYPT_PREFIXES = ("$2a$", "$2b$", "$2y$")


def hash_password(password: str) -> str:
    key = password.encode("utf-8")[:_BCRYPT_MAX_PASSWORD_BYTES]
    return bcrypt.hashpw(key, bcrypt.gensalt()).decode("ascii")


def needs_rehash(stored_hash: str) -> bool:
    """True if stored_hash predates the bcrypt migration and should be
    replaced with a bcrypt hash on the caller's next successful login."""
    return not stored_hash.startswith(_BCRYPT_PREFIXES)


def verify_password(password: str, stored_hash: str) -> bool:
    if needs_rehash(stored_hash):
        return _verify_legacy_hmac(password, stored_hash)
    try:
        key = password.encode("utf-8")[:_BCRYPT_MAX_PASSWORD_BYTES]
        return bcrypt.checkpw(key, stored_hash.encode("ascii"))
    except (ValueError, TypeError):
        return False


def _verify_legacy_hmac(password: str, stored_hash: str) -> bool:
    if ":" not in stored_hash:
        return False
    parts = stored_hash.split(":", 1)
    if len(parts) != 2:
        return False
    try:
        salt = base64.b64decode(parts[0])
        stored_digest = parts[1]
        key = password.encode("utf-8")
        computed = hmac.new(key, salt, hashlib.sha256).hexdigest()
        return hmac.compare_digest(computed, stored_digest)
    except Exception:
        return False
