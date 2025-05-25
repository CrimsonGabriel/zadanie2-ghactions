# syntax=docker/dockerfile:1.4

### ===== Etap 1: Budowanie (builder stage) =====
FROM python:3.10-slim as builder

WORKDIR /app_builder

# Potrzebne narzędzia
RUN apt-get update && apt-get install -y --no-install-recommends \
    git openssh-client curl && \
    rm -rf /var/lib/apt/lists/*

# USUŃ SYSTEMOWE pip/setuptools (nie chcemy starych syfów)
RUN python3 -m pip uninstall -y pip setuptools || true

# Klon repo
RUN --mount=type=secret,id=github_token \
    git clone https://$(cat /run/secrets/github_token)@github.com/CrimsonGabriel/zadanie_1.git /app_src

WORKDIR /app_src

# Virtualenv + bezpieczne wersje
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip==25.1.1 setuptools==78.1.1 && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

### ===== Etap 2: Runtime =====
FROM python:3.10-slim

# 💀 USUŃ stare setuptools/pip z runtime'a (tu był problem)
RUN python3 -m pip uninstall -y pip setuptools || true && rm -rf /usr/local/lib/python3.10/site-packages/setuptools*

LABEL org.opencontainers.image.authors="Gabriel Piątek <gabriel.piatek.biznes@gmail.com>"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_APP=app.py \
    PORT=8080 \
    WEATHER_API_KEY=""

WORKDIR /app

# Kopiuj tylko to co potrzeba
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app_src /app

# Użytkownik nie-root
RUN useradd --create-home appuser && \
    chown -R appuser:appuser /app /opt/venv
USER appuser

EXPOSE ${PORT}

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:${PORT}/health || exit 1

CMD ["/opt/venv/bin/python", "app.py"]
