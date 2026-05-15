from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# from app.api.routes import extract, health
from app.api.routes import gemini, health
from app.core.config import get_settings, reload_settings


def _cors_allow_origins(cors_origins: str) -> list[str]:
    raw = cors_origins.strip()
    if raw == "*":
        return ["*"]
    return [o.strip() for o in raw.split(",") if o.strip()]


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    # Clear cached Settings so backend/.env is re-read (cwd-independent path in config.py).
    reload_settings()
    yield
    # Shutdown


def create_app() -> FastAPI:
    settings = get_settings()
    application = FastAPI(
        title=settings.app_name,
        lifespan=lifespan,
    )
    origins = _cors_allow_origins(settings.cors_origins)
    application.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    application.include_router(health.router, prefix=settings.api_prefix, tags=["health"])
    application.include_router(gemini.router, prefix=settings.api_prefix, tags=["gemini"])
    return application


app = create_app()
