# syntax=docker/dockerfile:1.4

### ===== Etap 1: Budowanie (builder stage) =====
FROM python:3.10-slim as builder

WORKDIR /app_builder

# Wymagane do klonowania i curl do healthchecka
RUN apt-get update && apt-get install -y --no-install-recommends \
    git openssh-client curl && \
    rm -rf /var/lib/apt/lists/*

# Klon repozytorium prywatnie przez GitHub Token (przez GitHub secret)
RUN --mount=type=secret,id=github_token \
    git clone https://$(cat /run/secrets/github_token)@github.com/CrimsonGabriel/zadanie_1.git /app_src

WORKDIR /app_src

# Wirtualne środowisko + poprawki na podatności (fix na Trivy)
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip==25.1.1 setuptools==78.1.1 && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

### ===== Etap 2: Runtime (docelowy kontener) =====
FROM python:3.10-slim

LABEL org.opencontainers.image.authors="Gabriel Piątek <gabriel.piatek.biznes@gmail.com>"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_APP=app.py \
    PORT=8080 \
    WEATHER_API_KEY=""

WORKDIR /app

# Kopiuj venv z zależnościami
COPY --from=builder /opt/venv /opt/venv

# Kopiuj źródła aplikacji
COPY --from=builder /app_src /app

# Użytkownik nie-root
RUN useradd --create-home appuser && \
    chown -R appuser:appuser /app /opt/venv
USER appuser

EXPOSE ${PORT}

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:${PORT}/health || exit 1

CMD ["/opt/venv/bin/python", "app.py"]
