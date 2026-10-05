# Production image: small, non-root, installs exactly what uv.lock pins (checklist O8).
FROM python:3.12-slim AS app
COPY --from=ghcr.io/astral-sh/uv:0.5 /uv /usr/local/bin/uv
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy PYTHONUNBUFFERED=1 PATH="/app/.venv/bin:$PATH"
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project
COPY src ./src
COPY migrations ./migrations
COPY alembic.ini ./
RUN useradd --create-home --uid 10001 app && chown -R app /app
USER app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health').status==200 else 1)"
# Apply migrations, then serve. Behind a proxy (HTTPS), uvicorn trusts its forwarded headers.
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --app-dir src --host 0.0.0.0 --port 8000 --proxy-headers --forwarded-allow-ips='*'"]
