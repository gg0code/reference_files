"""Builds the app: settings, logging, security, error pages, static files and feature routes.
REQ-IDs: none - starter app
"""

from typing import Annotated

from fastapi import Depends, FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from app.config import Settings, get_settings
from app.features.notes.routes import router as notes_router
from app.shared.db import database_ok
from app.shared.errors import install_error_handlers
from app.shared.logging import RequestLogMiddleware, setup_logging
from app.shared.security import RateLimitMiddleware, SecurityHeadersMiddleware
from app.shared.ui import APP_DIR, render


def init_error_tracking(settings: Settings) -> None:
    """Send unexpected errors to Sentry when SENTRY_DSN is set (checklist O4); otherwise do nothing.

    Calls: none
    """
    if not settings.sentry_dsn:
        return
    import sentry_sdk  # noqa: PLC0415  # imported only when error tracking is switched on

    sentry_sdk.init(
        dsn=settings.sentry_dsn,
        environment=settings.environment,
        release=settings.version,
        send_default_pii=False,
        traces_sample_rate=0.0,
    )


def create_app() -> FastAPI:
    """Assemble the app. Middleware order: request log outermost, then rate limit, then headers.

    Calls: get_settings:config.py:src/app, setup_logging:logging.py:src/app/shared,
           init_error_tracking:main.py:src/app, install_error_handlers:errors.py:src/app/shared
    """
    settings = get_settings()
    setup_logging(settings.log_level)
    init_error_tracking(settings)
    app = FastAPI(title=settings.app_name, docs_url=None, redoc_url=None, openapi_url=None)
    app.add_middleware(SecurityHeadersMiddleware, https_only=settings.is_production)
    app.add_middleware(RateLimitMiddleware, per_minute=settings.rate_limit_per_minute)
    app.add_middleware(RequestLogMiddleware)
    install_error_handlers(app)
    app.mount("/static", StaticFiles(directory=APP_DIR / "static"), name="static")
    app.include_router(notes_router)

    @app.get("/", response_class=HTMLResponse)
    def home(request: Request) -> HTMLResponse:
        """The start page.

        Calls: render:ui.py:src/app/shared
        """
        return render(request, "pages/home.html")

    @app.get("/health")
    def health(settings: Annotated[Settings, Depends(get_settings)]) -> JSONResponse:
        """For uptime checks and deploys: 200 when app and database are up, else 503 (O2).

        Calls: database_ok:db.py:src/app/shared
        """
        ok = database_ok()
        body = {
            "status": "ok" if ok else "degraded",
            "database": "ok" if ok else "down",
            "version": settings.version,
        }
        return JSONResponse(body, status_code=200 if ok else 503)

    return app


app = create_app()
