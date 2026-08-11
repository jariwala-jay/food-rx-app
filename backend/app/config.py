from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    mongodb_url: str = ""
    secret_key: str = "change-me-in-production"
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    # Canonical origin for links we email to users (e.g. password reset).
    # Deliberately NOT derived from the request's Host header, which is
    # client-controlled and unvalidated (no TrustedHostMiddleware) — trusting
    # it would let an attacker point reset links at a domain they control.
    public_base_url: str = "https://foodrx-api-609996001749.us-central1.run.app"
    # Optional: set BROADCAST_SECRET in .env to enable POST /notifications/broadcast
    broadcast_secret: str = ""
    # Optional: set TRACKER_RESET_SECRET in .env to enable tracker reset cron endpoints
    tracker_reset_secret: str = ""
    # Firebase Admin config for FCM push notifications. Prefer
    # FIREBASE_SERVICE_ACCOUNT_B64; JSON and the legacy _BASE64 name also work.
    firebase_project_id: str = ""
    firebase_service_account_json: str = ""
    firebase_service_account_b64: str = ""
    firebase_service_account_json_base64: str = ""

    # RAG chatbot (Gemini): used for embeddings and generation
    gemini_api_key: str = ""

    # Groq: fallback generation when Gemini quota is exhausted
    groq_api_key: str = ""

    # Gmail SMTP for server-side password-reset email. Backend-only secrets —
    # set these in backend/.env (gitignored, never bundled into the Flutter
    # app), not the project-root .env, which pubspec.yaml ships inside the
    # mobile app binary.
    gmail_user: str = ""
    gmail_app_password: str = ""
    email_from_name: str = "MyFoodRx"

    # Android App Links / iOS Universal Links for the password-reset deep
    # link (see /.well-known/assetlinks.json and
    # /.well-known/apple-app-site-association in routers/well_known.py).
    # Not secrets. Unset is safe — those endpoints just no-op until these
    # are set.
    android_package_name: str = "com.shield.myfoodrx"
    # Comma-separated SHA256 cert fingerprints, colon-hex format (one per
    # signing cert — include both the debug/release cert and Play App
    # Signing's cert if applicable).
    android_sha256_cert_fingerprints: str = ""
    apple_bundle_id: str = "com.shield.myfoodrx"
    apple_team_id: str = ""

    class Config:
        # backend/.env only. The project-root .env is bundled into the
        # Flutter app binary (pubspec.yaml assets) and must never be a
        # source of backend secrets.
        env_file = ".env"
        extra = "ignore"


settings = Settings()
