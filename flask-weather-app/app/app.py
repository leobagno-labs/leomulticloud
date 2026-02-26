import os
import socket
import datetime
import requests
from flask import Flask, jsonify, render_template, request

app = Flask(__name__)

CLOUD_PROVIDER = os.environ.get("CLOUD_PROVIDER", "Local")
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
WEATHER_API_KEY = os.environ.get("WEATHER_API_KEY", "")
APP_PORT = int(os.environ.get("APP_PORT", 5000))


@app.route("/health")
def health():
    return (
        jsonify(
            {
                "status": "healthy",
                "cloud_provider": CLOUD_PROVIDER,
                "app_version": APP_VERSION,
                "hostname": socket.gethostname(),
                "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat()
                + "Z",
            }
        ),
        200,
    )


@app.route("/cloud")
def cloud_info():
    return (
        jsonify(
            {
                "cloud_provider": CLOUD_PROVIDER,
                "hostname": socket.gethostname(),
                "version": APP_VERSION,
                "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat()
                + "Z",
                "message": f"Running on {CLOUD_PROVIDER} cloud environment",
            }
        ),
        200,
    )


@app.route("/weather/<city>")  # type: ignore
def get_weather(city):
    if not WEATHER_API_KEY:
        return (
            jsonify(
                {
                    "city": city,
                    "temperature": 14.0,
                    "feels_like": 10.0,
                    "humidity": 72,
                    "description": "Mock weather data - API key not configured",
                    "cloud_provider": CLOUD_PROVIDER,
                    "time": datetime.datetime.now(datetime.timezone.utc).isoformat()
                    + "Z",
                }
            ),
            200,
        )

    try:
        resp = requests.get(
            f"http://api.openweathermap.org/data/2.5/weather",
            params={"q": city, "appid": WEATHER_API_KEY, "units": "metric"},
            timeout=5,
        )
        resp.raise_for_status()
        data = resp.json()
        return (
            jsonify(
                {
                    "city": data["name"],
                    "temperature": data["main"]["temp"],
                    "feels_like": data["main"]["feels_like"],
                    "humidity": data["main"]["humidity"],
                    "description": data["weather"][0]["description"],
                    "cloud_provider": CLOUD_PROVIDER,
                    "time": datetime.datetime.now(datetime.timezone.utc).isoformat()
                    + "Z",
                }
            ),
            200,
        )
    except requests.exceptions.Timeout:
        return (
            jsonify(
                {
                    "error": "Weather API request timed out",
                    "cloud_provider": CLOUD_PROVIDER,
                    "time": datetime.datetime.now(datetime.timezone.utc).isoformat()
                    + "Z",
                }
            ),
            503,
        )
    except requests.exceptions.HTTPError as e:
        return (
            jsonify(
                {
                    "error": f"Weather API error: {str(e)}",
                    "cloud_provider": CLOUD_PROVIDER,
                    "time": datetime.datetime.now(datetime.timezone.utc).isoformat()
                    + "Z",
                }
            ),
            502,
        )
    except Exception as e:
        return (
            jsonify(
                {
                    "error": f"Internal error: {str(e)}",
                    "cloud_provider": CLOUD_PROVIDER,
                    "time": datetime.datetime.now(datetime.timezone.utc).isoformat()
                    + "Z",
                }
            ),
            500,
        )


@app.route("/")
def index():
    color = "#f59e0b" if CLOUD_PROVIDER == "AWS" else "#3b82f6"
    hostname = socket.gethostname()
    html = f"""<!DOCTYPE html>
        <html lang="en">
            <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Weather App - {CLOUD_PROVIDER}</title>
                <style>
                    body {{
                        font-family: monospace;
                        background-color: #0f172a;
                        color: #e2e8f0;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        height: 100vh;
                        margin: 0;
                    }}
                    .card {{
                        background-color: #1e293b;
                        padding: 40px 60px;
                        border-radius: 12px;
                        text-align: center;
                        border: 2px solid {color};
                    }}
                    .cloud-provider {{
                        font-size: 48px;
                        color: {color};
                        font-weight: 900;
                    }}
                </style>
            </head>
            <body>
                <div class="card">
                   <div class="cloud-provider">{CLOUD_PROVIDER}</div> 
                   <h1> Welcome to Leonardo's Weather App </h1>
                   <p>
                   Running on <span style="color: {color}; font-weight:900;">{CLOUD_PROVIDER}</span> cloud environment.
                   </p> 
                   <p>Multi-Cloud DR - TU Dublin | Leonardo Bagno</p>
                   <p class="muted">Version: {APP_VERSION} | Host: {hostname}</p>
                </div>
            </body>
        </html>
        """
    return html, 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=APP_PORT, debug=False)
