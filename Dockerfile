# Użyj rozszerzonego frontendu buildkit
# syntax=docker/dockerfile:1.4

# Etap 1: Budowanie zależności (Build Stage)
# Użyj obrazu Python do zainstalowania zależności, aby warstwa była cache'owana
FROM python:3.10-slim as builder

# Ustaw katalog roboczy
WORKDIR /app_builder

# Upewnij się, że git i ssh są dostępne
RUN apt-get update && apt-get install -y --no-install-recommends git openssh-client && rm -rf /var/lib/apt/lists/*

# Pobierz kod z publicznego repozytorium GitHub używając mount=ssh
# Założono, że SSH agent forwarding jest skonfigurowany na hoście
RUN --mount=type=ssh \
    mkdir -p -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git clone git@github.com:CrimsonGabriel/zadanie_1.git /app_src

WORKDIR /app_src
COPY requirements.txt . 
# Skopiuj requirements.txt z pobranego kodu (jeśli jest w repo)

# Zainstaluj zależności (bez zapisywania cache pip i bez plików .pyc)
# Użyj virtualenv dla lepszej izolacji
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip==23.3 setuptools==70.0.0 && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# ---
# Etap 2: Obraz wynikowy (Runtime Stage)
# Użyj minimalnego obrazu Python
FROM python:3.10-slim

# Metadane OCI - Informacje o autorze
LABEL org.opencontainers.image.authors="Gabriel Piątek <gabriel.piatek.biznes@gmail.com>"

# Ustaw zmienne środowiskowe
ENV PYTHONDONTWRITEBYTECODE 1 
# Nie twórz plików .pyc
ENV PYTHONUNBUFFERED 1        
# Logi od razu na stdout/stderr
ENV FLASK_APP=app.py         
# Wskazanie aplikacji Flask (choć uruchamiamy bezpośrednio)
ENV PORT=8080               
# Domyślny port w kontenerze
ENV WEATHER_API_KEY=""     
# Pusta wartość - zostanie przekazana przy `docker run`

# Ustaw katalog roboczy
WORKDIR /app

# Skopiuj wirtualne środowisko z zależnościami z etapu budowania
COPY --from=builder /opt/venv /opt/venv

# Skopiuj kod aplikacji pobrany w etapie builder
COPY --from=builder /app_src /app
# Uwaga: Plik .env NIE jest kopiowany (i dobrze!), klucz API podano przez zmienną środowiskową przy uruchamianiu

# Uruchom aplikację jako użytkownik nie-root dla bezpieczeństwa
RUN useradd --create-home appuser && \
    chown -R appuser:appuser /app /opt/venv
USER appuser

# Wystaw port, na którym nasłuchuje aplikacja w kontenerze
EXPOSE ${PORT}

# Sprawdzenie stanu kontenera (Healthcheck)
# Sprawdza co 30s, timeout 5s, 3 próby zanim oznaczy jako niezdrowy
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:${PORT}/health || exit 1
# Uwaga: curl musi być dostępny w obrazie bazowym (python:slim go zawiera)

# Komenda uruchamiająca aplikację przy starcie kontenera
# Użyto venv/bin/python do uruchomienia, aby użyć zainstalowanych pakietów
CMD ["/opt/venv/bin/python", "app.py"]

