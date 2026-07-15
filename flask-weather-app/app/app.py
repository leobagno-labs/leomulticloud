import os
import socket
import datetime
import httpx
import psutil
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, HTMLResponse
from fastapi.templating import Jinja2Templates

app = FastAPI(title="leomulticloud weather app")

templates = Jinja2Templates(
    directory=os.path.join(os.path.dirname(__file__), "templates")
)

CLOUD_PROVIDER = os.environ.get("CLOUD_PROVIDER", "AWS")
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
WEATHER_API_KEY = os.environ.get("WEATHER_API_KEY", "")
APP_PORT = int(os.environ.get("APP_PORT", 5000))

CPU_OVERLOAD_THRESHOLD = int(os.environ.get("CPU_OVERLOAD_THRESHOLD", 90))

PROVIDER_COLORS = {
    "AWS": "#f59e0b",
    "Azure": "#3b82f6",
}


def _now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat() + "Z"


@app.get("/health")
def health():
    # Sync route on purpose: psutil.cpu_percent blocks for 0.1s,
    # FastAPI runs sync routes in a threadpool so the event loop stays free.
    cpu = psutil.cpu_percent(interval=0.1)
    payload = {
        "status": "healthy",
        "cloud_provider": CLOUD_PROVIDER,
        "app_version": APP_VERSION,
        "hostname": socket.gethostname(),
        "cpu_percent": cpu,
        "timestamp": _now(),
    }
    if cpu >= CPU_OVERLOAD_THRESHOLD:
        payload["status"] = "overloaded"
        return JSONResponse(content=payload, status_code=503)
    return JSONResponse(content=payload, status_code=200)


@app.get("/cloud")
def cloud_info():
    return JSONResponse(
        content={
            "cloud_provider": CLOUD_PROVIDER,
            "hostname": socket.gethostname(),
            "version": APP_VERSION,
            "timestamp": _now(),
            "message": f"Running on {CLOUD_PROVIDER} cloud environment",
        },
        status_code=200,
    )


async def _fetch_weather(city: str) -> dict:
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

    async with httpx.AsyncClient(timeout=5) as client:
        resp = await client.get(
            "http://api.openweathermap.org/data/2.5/weather",
            params={"q": city, "appid": WEATHER_API_KEY, "units": "metric"},
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


@app.get("/weather/{city}")
async def get_weather(city: str):
    try:
        result = await _fetch_weather(city)
        return JSONResponse(content=result, status_code=200)
    except httpx.TimeoutException:
        return JSONResponse(
            content={
                "error": "Weather API request timed out",
                "cloud_provider": CLOUD_PROVIDER,
                "time": _now(),
            },
            status_code=503,
        )
    except httpx.HTTPStatusError as e:
        return JSONResponse(
            content={
                "error": f"Weather API error: {str(e)}",
                "cloud_provider": CLOUD_PROVIDER,
                "time": _now(),
            },
            status_code=502,
        )
    except Exception as e:
        return JSONResponse(
            content={
                "error": f"Internal error: {str(e)}",
                "cloud_provider": CLOUD_PROVIDER,
                "time": _now(),
            },
            status_code=500,
        )


@app.get("/", response_class=HTMLResponse)
async def index_get(request: Request):
    return templates.TemplateResponse(
        request,
        "index.html",
        {
            "cloud_provider": CLOUD_PROVIDER,
            "hostname": socket.gethostname(),
            "version": APP_VERSION,
            "color": PROVIDER_COLORS.get(CLOUD_PROVIDER, "#6b7280"),
            "weather": None,
            "error": None,
        },
    )


@app.post("/", response_class=HTMLResponse)
async def index_post(request: Request):
    form = await request.form()
    city = str(form.get("city", "Dublin")).strip()

    weather = None
    error = None
    try:
        result = await _fetch_weather(city)
        weather = result
    except Exception as e:
        error = str(e)

    return templates.TemplateResponse(
        request,
        "index.html",
        {
            "cloud_provider": CLOUD_PROVIDER,
            "hostname": socket.gethostname(),
            "version": APP_VERSION,
            "color": PROVIDER_COLORS.get(CLOUD_PROVIDER, "#6b7280"),
            "weather": weather,
            "error": error,
        },
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=APP_PORT)
