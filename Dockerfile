# syntax=docker/dockerfile:1.4

FROM python:3.10-slim as builder

WORKDIR /app_builder

# 1. Pakiety do git clone i curl do healthchecka
RUN apt-get update && apt-get install -y --no-install-recommends \
    git openssh-client curl && \
    rm -rf /var/lib/apt/lists/*

# 2. Wypierdziel podatne setuptools z globalnego Pythona
RUN pip uninstall --yes setuptools

# 3. Klon repozytorium prywatnie przez GitHub Token
RUN --mount=type=secret,id=github_token \
    git clone https://$(cat /run/secrets/github_token)@github.com/CrimsonGabriel/zadanie_1.git /app_src

WORKDIR /app_src

# 4. Virtualenv z fixami na Trivy
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip==25.1.1 setuptools==78.1.1 && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# === Stage 2 ===
FROM python:3.10-slim

LABEL org.opencontainers.image.authors="Gabriel Piątek <gabriel.piatek.biznes@gmail.com>"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_APP=app.py \
    PORT=8080 \
    WEATHER_API_KEY=""

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app_src /app

RUN useradd --create-home appuser && \
    chown -R appuser:appuser /app /opt/venv
USER appuser

EXPOSE ${PORT}

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:${PORT}/health || exit 1

CMD ["/opt/venv/bin/python", "app.py"]
