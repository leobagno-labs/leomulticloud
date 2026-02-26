import os
import socket
import datetime
import requests
from flask import Flask, jsonify, render_template, request

app = Flask(__name__)

CLOUD_PROVIDER = os.environ.get("CLOUD_PROVIDER", "AWS")
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
WEATHER_API_KEY = os.environ.get("WEATHER_API_KEY", "")
APP_PORT = int(os.environ.get("APP_PORT", 5000))

PROVIDER_COLORS = {
    "AWS": "#f59e0b",
    "Azure": "#3b82f6",
}


@app.route("/health")
def health():
    return (
        jsonify(
            {
                "status": "healthy",
                "cloud_provider": CLOUD_PROVIDER,
                "app_version": APP_VERSION,
                "hostname": socket.gethostname(),
                "timestamp": _now(),
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
                "timestamp": _now(),
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
                    "temperature": 12.0,
                    "feels_like": 9.0,
                    "humidity": 60,
                    "description": "Mock weather data - API key not configured",
                    "cloud_provider": CLOUD_PROVIDER,
                    "time": _now(),
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
                    "time": _now(),
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
                    "time": _now(),
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
                    "time": _now(),
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
                    "time": _now(),
                }
            ),
            500,
        )


# UI Route
@app.route("/", methods=["GET", "POST"])
def index():
    weather = None
    error = None
    city = "Dublin"

    if request.method == "POST":
        city = request.form.get("city", "Dublin").strip()
        result = _fetch_weather(city)
        if "error" in result:
            error = result["error"]
        else:
            weather = result

    return render_template(
        "index.html",
        cloud_provider=CLOUD_PROVIDER,
        hostname=socket.gethostname(),
        version=APP_VERSION,
        color=PROVIDER_COLORS.get(CLOUD_PROVIDER, "#6b7280"),
        weather=weather,
        error=error,
    )


# Helper function to get color for cloud provider


def _now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat() + "Z"


def _fetch_weather(city):
    if not WEATHER_API_KEY:
        return {
            "city": city,
            "temperature": 12.0,
            "feels_like": 9.0,
            "humidity": 60,
            "description": "Mock weather data - API key not configured",
            "cloud_provider": CLOUD_PROVIDER,
            "time": _now(),
        }

    try:
        resp = requests.get(
            f"http://api.openweathermap.org/data/2.5/weather",
            params={"q": city, "appid": WEATHER_API_KEY, "units": "metric"},
            timeout=5,
        )
        resp.raise_for_status()
        data = resp.json()
        return {
            "city": data["name"],
            "temperature": data["main"]["temp"],
            "feels_like": data["main"]["feels_like"],
            "humidity": data["main"]["humidity"],
            "description": data["weather"][0]["description"],
            "cloud_provider": CLOUD_PROVIDER,
            "time": _now(),
        }
    except Exception as e:
        return {"error": str(e), "cloud_provider": CLOUD_PROVIDER, "time": _now()}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=APP_PORT, debug=False)
