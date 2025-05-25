# 🐳 Zadanie 2 na bazie zadanie1_app – CI/CD Pipeline z GitHub Actions


---

## 📦 Cel zadania

Opracować łańcuch (pipeline) w GitHub Actions, który:
- buduje obraz kontenera na podstawie kodu z prywatnego repozytorium GitHub,
- obsługuje architektury `linux/amd64` oraz `linux/arm64`,
- wykorzystuje caching BuildKit z `registry` jako backendem (`mode=max`),
- wykonuje skan podatności CVE (Trivy),
- publikuje obraz do publicznego rejestru `ghcr.io`.

---

## 🚀 Wdrożenie i konfiguracja

### 📂 Struktura workflow

Plik: `.github/workflows/build.yml`

![image](https://github.com/user-attachments/assets/ed579b32-1055-42d1-86da-610c5935dc07)
![image](https://github.com/user-attachments/assets/da62f0eb-fe42-4479-a3c9-a521e31b9baf)



#### 🔧 Etapy pipeline:

1. **Checkout repozytorium**
2. **Logowanie do DockerHub i GHCR (przez sekrety)**
3. **Konfiguracja QEMU i Docker Buildx** (dla multi-arch)
4. **Build obrazu Dockera z cache registry (BuildKit)**
5. **Tagowanie obrazu przez `docker/metadata-action`**
6. **Push do `ghcr.io`**
7. **Skan podatności przez Trivy**
   - Pipeline kończy się błędem (`exit-code: 1`), jeśli wykryto luki `HIGH` lub `CRITICAL`.

---

## 🐍 Dockerfile – bezpieczeństwo i zgodność

W celu zapewnienia bezpieczeństwa środowiska uruchomieniowego oraz przejścia testu Trivy:

- W etapie budowania **usuwane są fabryczne `setuptools` i `pip`** z obrazu `python:3.10-slim`.
- Następnie instalowane są **jawnie wersje wolne od podatności**:
  ```dockerfile
  RUN pip uninstall -y setuptools pip
  RUN /opt/venv/bin/pip install --no-cache-dir --upgrade pip==25.1.1 setuptools==78.1.1
Aplikacja instalowana jest w osobnym venv w /opt/venv, który jest później kopiowany do docelowego obrazu.

Użyto wieloetapowego buildu i użytkownika nie-root (appuser).

## 🛡️ Test podatności CVE (Trivy)
W celu weryfikacji bezpieczeństwa obrazu wykorzystano Trivy, a nie Docker Scout, ponieważ:

Trivy działa niezależnie od Dockera Desktop (Scout wymaga konta Docker),

Oferuje szczegółowe raporty z podziałem na OS i paczki,

Pozwala łatwo wymusić przerwanie pipeline'u w razie wykrycia luk o statusie HIGH/CRITICAL.
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ghcr.io/crimsongabriel/zadanie1-app:latest
    format: table
    exit-code: 1
    severity: CRITICAL,HIGH
    ignore-unfixed: true
## 🏷️ Tagowanie obrazów i cache
Obrazy:
Użyto docker/metadata-action, który automatycznie taguje obrazy jako:

latest – główny tag,

sha-<skrót> – skrót commita (GITHUB_SHA),

vX.Y.Z – jeśli commit zawiera wersjonowany tag w formacie semver.

Cache:
BuildKit zapisuje cache w systemie GitHub Actions (type=gha) – dzięki temu kolejne buildy są szybsze i bardziej efektywne:
cache-from: type=gha
cache-to: type=gha,mode=max
✅ Przykład działania
Ostatnie zakończone poprawnie uruchomienie workflow:

Obraz opublikowany do:
ghcr.io/crimsongabriel/zadanie1-app:latest

Przeszedł skan Trivy z wynikiem: 0 podatności HIGH/CRITICAL
![image](https://github.com/user-attachments/assets/f690880c-16d5-4d95-821a-69bb05c4ca4b)
![image](https://github.com/user-attachments/assets/76ef2ef4-9577-4da9-af28-9c99ecf471d6)
![image](https://github.com/user-attachments/assets/9b56e319-2a02-42cd-9f52-4957a1352839)

![WORK](https://github.com/user-attachments/assets/264737d5-4032-4351-b741-cdfaedce69c2)


## 🧪 Debug i testy
W trakcie implementacji napotkano następujące trudności:

🔥 Trivy wykrywał podatne paczki z systemowego Pythona – rozwiązano przez pip uninstall przed konfiguracją venv.

⚠️ Domyślny pip i setuptools w obrazie python:3.10-slim zawierały CVE – wymuszono bezpieczne wersje.

🐌 Cache początkowo nie działał – wymagana była poprawna konfiguracja BuildKit (--no-cache=false, cache-from/to).

