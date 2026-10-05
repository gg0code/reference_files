"""Every setting of the app, read from the environment (or .env) and checked at startup.
REQ-IDs: none - starter app (checklist O1)
"""

from functools import lru_cache
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """All configuration. A missing or invalid value stops the app at startup, saying which."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "My App"
    environment: Literal["development", "production"] = "development"
    secret_key: str = Field(min_length=16)
    database_url: str = "sqlite:///./app.db"
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"
    rate_limit_per_minute: int = Field(default=60, ge=1)
    sentry_dsn: str = ""
    version: str = "0.1.0"

    @property
    def is_production(self) -> bool:
        """True in production: secure cookies and HSTS are switched on.

        Calls: none
        """
        return self.environment == "production"


@lru_cache
def get_settings() -> Settings:
    """Load the settings once.

    Calls: Settings:config.py:src/app
    """
    return Settings()  # type: ignore[call-arg]  # values come from the environment
