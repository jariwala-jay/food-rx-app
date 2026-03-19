"""
Password hashing compatible with the existing Flutter app (mongo_dart).
Do not change this without a migration plan for existing users.
"""
import base64
import hashlib
import hmac
import secrets


SALT_LENGTH = 32


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(SALT_LENGTH)
    salt_b64 = base64.b64encode(salt).decode("ascii")
    key = password.encode("utf-8")
    digest = hmac.new(key, salt, hashlib.sha256).hexdigest()
    return f"{salt_b64}:{digest}"


def verify_password(password: str, stored_hash: str) -> bool:
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
