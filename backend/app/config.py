from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    mongodb_url: str = ""
    secret_key: str = "change-me-in-production"
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    # Optional: set BROADCAST_SECRET in .env to enable POST /notifications/broadcast
    broadcast_secret: str = ""
    # Optional: set TRACKER_RESET_SECRET in .env to enable tracker reset cron endpoints
    tracker_reset_secret: str = ""
    # Optional: Firebase Admin config for sending tray push notifications via FCM.
    # Preferred:
    # - FIREBASE_SERVICE_ACCOUNT_B64 (base64-encoded service account JSON)
    # Also supported:
    # - FIREBASE_SERVICE_ACCOUNT_JSON (raw JSON string)
    # Backward compatibility:
    # - FIREBASE_SERVICE_ACCOUNT_JSON_BASE64 (legacy name)
    firebase_project_id: str = ""
    firebase_service_account_json: str = ""
    firebase_service_account_b64: str = ""
    firebase_service_account_json_base64: str = ""

    class Config:
        env_file = "../.env"  # Read from project root .env (shared with Flutter)
        extra = "ignore"


settings = Settings()
