FROM python:3.12-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

WORKDIR /app

COPY notebooks/ notebooks/

EXPOSE 8000

CMD ["uvx", "--with", "pyzmq", "marimo", "run", "--sandbox", "notebooks", "--port", "8000", "--no-token", "--host", "0.0.0.0"]
