"""Alembic environment: uses the app's DATABASE_URL and model metadata.
REQ-IDs: none - starter app
"""

from alembic import context
from sqlmodel import SQLModel

import app.features.notes.models  # noqa: F401  # registers the tables Alembic compares against
from app.shared.db import get_engine

target_metadata = SQLModel.metadata


def run_migrations() -> None:
    """Run the migrations against the configured database.

    Calls: get_engine:db.py:src/app/shared
    """
    with get_engine().connect() as connection:
        context.configure(
            connection=connection, target_metadata=target_metadata, render_as_batch=True
        )
        with context.begin_transaction():
            context.run_migrations()


run_migrations()
