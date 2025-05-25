import os
import logging
from datetime import datetime
from flask import Flask, render_template, request, jsonify
import requests
from dotenv import load_dotenv # Do wczytania klucza API z .env

load_dotenv() # Wczytaj zmienne środowiskowe z pliku .env

# Konfiguracja Aplikacji
app = Flask(__name__)
PORT = int(os.getenv('PORT', 8080)) # Pobierz port z zmiennej środowiskowej lub użyj 8080
AUTHOR_NAME = "Gabriel Piątek" 
WEATHER_API_KEY = os.getenv('WEATHER_API_KEY') # Pobierz klucz API

# Konfiguracja Logowania
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Przykładowa predefiniowana lista miast
PREDEFINED_LOCATIONS = {
    "Poland": ["Warsaw", "Krakow", "Gdansk", "Wroclaw","Lublin","Pulawy","Opole Lubelskie","Laziska","Janiszów"],
    "Germany": ["Berlin", "Munich", "Hamburg"],
}

@app.route('/', methods=['GET', 'POST'])
def index():
    weather_data = None
    error_message = None
    selected_country = request.form.get('country')
    selected_city = request.form.get('city')

    if request.method == 'POST':
        if not selected_country or not selected_city:
             error_message = "Proszę wybrać kraj i miasto."
        elif not WEATHER_API_KEY:
            error_message = "Brak klucza API do serwisu pogodowego."
            logging.error("WEATHER_API_KEY is not set.")
        else:
            try:
                # Zapytanie do API OpenWeatherMap
                base_url = "http://api.openweathermap.org/data/2.5/weather"
                params = {
                    'q': f'{selected_city},{selected_country}',
                    'appid': WEATHER_API_KEY,
                    'units': 'metric', 
                    'lang': 'pl'      
                }
                response = requests.get(base_url, params=params)
                response.raise_for_status() # Rzuć wyjątkiem dla złych odpowiedzi (4xx lub 5xx)
                data = response.json()

                # Przetwarzanie danych pogodowych
                weather_data = {
                    'city': data['name'],
                    'country': data['sys']['country'],
                    'temp': data['main']['temp'],
                    'description': data['weather'][0]['description'],
                    'humidity': data['main']['humidity'],
                    'pressure': data['main']['pressure'],
                    'icon': data['weather'][0]['icon'] # Kod ikony pogody
                }
            except requests.exceptions.RequestException as e:
                logging.error(f"Błąd API pogody: {e}")
                error_message = f"Nie można pobrać pogody dla {selected_city}. Sprawdź nazwę lub spróbuj później."
            except KeyError as e:
                 logging.error(f"Błąd przetwarzania danych API: brak klucza {e}")
                 error_message = "Wystąpił błąd podczas przetwarzania danych pogodowych."

    return render_template('index.html',
                           locations=PREDEFINED_LOCATIONS,
                           weather=weather_data,
                           error=error_message,
                           selected_country=selected_country,
                           selected_city=selected_city)

@app.route('/health')
def health_check():
    # Prosty endpoint dla HEALTHCHECK Dockera
    return "OK", 200

if __name__ == '__main__':
    # Logowanie informacji przy starcie
    startup_log_message = (
        f"Aplikacja uruchomiona {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}. "
        f"Autor: {AUTHOR_NAME}. Nasłuchiwanie na porcie TCP: {PORT}"
    )
    logging.info(startup_log_message)
    # Uruchomienie serwera Flask
    # Użyj host='0.0.0.0' dostępny z zewnątrz kontenera
    app.run(host='0.0.0.0', port=PORT, debug=False) # Wyłącz debug w produkcji/kontenerze
