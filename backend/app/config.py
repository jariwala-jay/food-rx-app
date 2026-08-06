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

    class Config:
        env_file = "../.env"  # Read from project root .env (shared with Flutter)
        extra = "ignore"


settings = Settings()
