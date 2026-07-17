"""
Application configuration loaded from environment variables / .env file.
Uses pydantic-settings for type-safe configuration management.
"""

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Central configuration consumed throughout the application."""

    DATABASE_URL: str
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRY_HOURS: int = 4

    # Face-matching distance threshold.
    # Lower  → stricter (fewer false accepts, more false rejects).
    # Higher → looser  (more false accepts, fewer false rejects).
    # 0.6 is the well-known default in dlib/face_recognition benchmarks and
    # provides a balanced FAR/FRR tradeoff for most indoor access-control
    # scenarios.  Tune with labelled validation data for your deployment.
    MATCH_THRESHOLD: float = 0.6

    UPLOAD_DIR: str = "./uploads"
    ADMIN_EMAIL: str = "ugwuikenna299@gmail.com"
    ADMIN_PASSWORD: str = "Admin321"

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
    }


settings = Settings()
