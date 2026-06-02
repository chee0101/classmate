from functools import lru_cache
from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Resolve backend/.env regardless of uvicorn cwd (fixes GEMINI_API_KEY not loading from repo root).
_BACKEND_ROOT = Path(__file__).resolve().parent.parent.parent
_BACKEND_ENV = _BACKEND_ROOT / ".env"


class Settings(BaseSettings):
    """Environment-driven configuration."""

    model_config = SettingsConfigDict(
        env_file=str(_BACKEND_ENV) if _BACKEND_ENV.is_file() else ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "classmate-api"
    debug: bool = False
    api_prefix: str = "/api"

    # Max upload size (bytes) — enforce in route as well
    max_upload_bytes: int = 15 * 1024 * 1024
    extraction_job_timeout_seconds: int = 240
    pdf_pages_per_chunk: int = 4
    timetable_targeted_page_selection: bool = True
    timetable_page_following_pages: int = 3
    timetable_max_selected_pages: int = 10

    # Comma-separated origins, or "*" for any (dev only)
    cors_origins: str = "*"

    # Gemini: full academic-calendar JSON extraction when a key is set (see .env.example).
    gemini_api_key: str | None = None
    gemini_model: str = "gemini-3.1-flash-lite-preview"
    gemini_backup_models: str = "gemini-3-flash,gemini-3.5-flash,gemini-2.5-flash,gemini-2.5-flash-lite"
    use_gemini_holiday_extraction: bool = True

    @field_validator("gemini_api_key", mode="before")
    @classmethod
    def _strip_gemini_key(cls, v: object) -> object:
        if isinstance(v, str):
            s = v.strip()
            return s if s else None
        return v


@lru_cache
def get_settings() -> Settings:
    return Settings()


def reload_settings() -> Settings:
    """Reload .env into Settings (call after editing backend/.env during development)."""
    get_settings.cache_clear()
    return get_settings()
