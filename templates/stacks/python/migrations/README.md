# migrations

Alembic database migrations, one file per schema change, applied in order (`uv run alembic upgrade head`).
Never edit a migration that has run in production; add a new one. Test upgrade and downgrade on a copy of real data (checklist O5).
