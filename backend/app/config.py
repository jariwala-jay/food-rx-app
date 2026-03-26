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

    class Config:
        env_file = "../.env"  # Read from project root .env (shared with Flutter)
        extra = "ignore"


settings = Settings()
