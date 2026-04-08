from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Environment-driven configuration."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "classmate-api"
    debug: bool = False
    api_prefix: str = "/api"

    # Max upload size (bytes) — enforce in route as well
    max_upload_bytes: int = 15 * 1024 * 1024

    # Comma-separated origins, or "*" for any (dev only)
    cors_origins: str = "*"

    # Gemini extraction settings
    gemini_api_key: str | None = None
    gemini_model: str = "gemini-3.1-flash-lite-preview"
    use_gemini_holiday_extraction: bool = False


@lru_cache
def get_settings() -> Settings:
    return Settings()
