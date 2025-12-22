import os
import json
from datetime import datetime
from collections import defaultdict, Counter

import requests
import psycopg
from flask import Flask, render_template, request, redirect, url_for, flash
from pathlib import Path
from dotenv import load_dotenv

ENV_PATH = Path(__file__).with_name(".env")
load_dotenv(dotenv_path=ENV_PATH)
print("dotenv path:", ENV_PATH, "exists:", ENV_PATH.exists())
print("OPENWEATHER_API_KEY:", "OK" if os.getenv("OPENWEATHER_API_KEY") else "MISSING")


OPENWEATHER_BASE_URL = "https://api.openweathermap.org/data/2.5/forecast"


def create_app() -> Flask:
    app = Flask(__name__)
    app.secret_key = os.getenv("FLASK_SECRET_KEY", "dev-secret-change-me")

    @app.get("/health")
    def health():
        return {"status": "ok"}

    @app.get("/")
    def index():
        return render_template("index.html")

    @app.post("/forecast")
    def forecast():
        user_name = (request.form.get("user_name") or "").strip()
        city = (request.form.get("city") or "").strip()

        if not user_name or not city:
            flash("Please enter both name and city.", "danger")
            return redirect(url_for("index"))

        api_key = os.getenv("OPENWEATHER_API_KEY")
        if not api_key:
            flash("Server is missing OPENWEATHER_API_KEY configuration.", "danger")
            return redirect(url_for("index"))

        try:
            raw = fetch_openweather_forecast(city=city, api_key=api_key)
            summary = summarize_forecast(raw)
        except OpenWeatherError as e:
            flash(str(e), "danger")
            return redirect(url_for("index"))
        except Exception:
            flash("Unexpected error while fetching forecast.", "danger")
            return redirect(url_for("index"))

        # We store a compact summary (not the full raw payload) to keep the Save payload small.
        forecast_json_str = json.dumps(summary, ensure_ascii=False)

        return render_template(
            "forecast.html",
            user_name=user_name,
            city=summary.get("city", city),
            country=summary.get("country"),
            days=summary.get("days", []),
            forecast_json_str=forecast_json_str,
        )

    @app.post("/save")
    def save():
        user_name = (request.form.get("user_name") or "").strip()
        city = (request.form.get("city") or "").strip()
        forecast_json_str = request.form.get("forecast_json") or ""

        if not user_name or not city or not forecast_json_str:
            flash("Missing data to save.", "danger")
            return redirect(url_for("index"))

        database_url = os.getenv("DATABASE_URL")
        if not database_url:
            flash("Server is missing DATABASE_URL configuration.", "danger")
            return redirect(url_for("index"))

        try:
            forecast_obj = json.loads(forecast_json_str)
        except json.JSONDecodeError:
            flash("Invalid forecast data received.", "danger")
            return redirect(url_for("index"))

        try:
            ensure_schema(database_url)
            insert_saved_forecast(
                database_url=database_url,
                user_name=user_name,
                city=city,
                forecast_obj=forecast_obj,
            )
        except Exception:
            flash("Failed to save forecast to the database.", "danger")
            return redirect(url_for("index"))

        flash("Saved successfully ✅", "success")
        return redirect(url_for("saved"))

    @app.get("/saved")
    def saved():
        database_url = os.getenv("DATABASE_URL")
        if not database_url:
            flash("Server is missing DATABASE_URL configuration.", "danger")
            return redirect(url_for("index"))

        try:
            ensure_schema(database_url)
            rows = fetch_saved_forecasts(database_url, limit=20)
        except Exception:
            flash("Failed to read saved forecasts from the database.", "danger")
            return redirect(url_for("index"))

        return render_template("saved.html", rows=rows)

    return app


class OpenWeatherError(Exception):
    pass


def fetch_openweather_forecast(city: str, api_key: str) -> dict:
    params = {
        "q": city,
        "appid": api_key,
        "units": "metric",  # metric/imperial/standard supported broadly
        "lang": "en",
    }
    try:
        resp = requests.get(OPENWEATHER_BASE_URL, params=params, timeout=12)
    except requests.RequestException:
        raise OpenWeatherError("Network error while calling OpenWeatherMap.")

    if resp.status_code == 404:
        raise OpenWeatherError(f"City '{city}' was not found. Try adding country code (e.g. London,GB).")
    if resp.status_code == 401:
        raise OpenWeatherError("OpenWeatherMap API key is invalid/unauthorized.")
    if resp.status_code >= 400:
        raise OpenWeatherError(f"OpenWeatherMap error: HTTP {resp.status_code}")

    return resp.json()


def summarize_forecast(raw: dict) -> dict:
    """
    Convert OpenWeather 5-day/3-hour forecast response to a compact per-day summary:
    - date
    - min/max temp
    - representative description + icon
    """
    city_info = raw.get("city") or {}
    city_name = city_info.get("name")
    country = city_info.get("country")

    items = raw.get("list") or []
    by_date = defaultdict(list)

    for it in items:
        dt_txt = it.get("dt_txt")  # 'YYYY-MM-DD HH:MM:SS'
        main = it.get("main") or {}
        weather = (it.get("weather") or [{}])[0]

        if not dt_txt:
            continue

        date_str = dt_txt.split(" ")[0]
        hour_str = dt_txt.split(" ")[1].split(":")[0] if " " in dt_txt else None

        by_date[date_str].append({
            "dt_txt": dt_txt,
            "hour": int(hour_str) if hour_str is not None else None,
            "temp": main.get("temp"),
            "temp_min": main.get("temp_min"),
            "temp_max": main.get("temp_max"),
            "description": weather.get("description"),
            "icon": weather.get("icon"),
        })

    days_out = []
    for date_str in sorted(by_date.keys()):
        entries = by_date[date_str]
        temps = [e["temp"] for e in entries if isinstance(e.get("temp"), (int, float))]
        if not temps:
            continue

        # Choose a representative entry around 12:00 if possible, else first
        rep = pick_representative_entry(entries)

        descs = [e.get("description") for e in entries if e.get("description")]
        desc = rep.get("description") or (Counter(descs).most_common(1)[0][0] if descs else "N/A")

        days_out.append({
            "date": date_str,
            "weekday": weekday_name(date_str),
            "temp_min": round(min(temps), 1),
            "temp_max": round(max(temps), 1),
            "description": desc,
            "icon": rep.get("icon"),
        })

    return {
        "city": city_name or "",
        "country": country,
        "days": days_out[:6],  # typically up to 5 days, sometimes spills into 6 dates
        "source": "OpenWeatherMap 5 day / 3 hour forecast",
        "generated_at_utc": datetime.utcnow().isoformat() + "Z",
    }


def pick_representative_entry(entries: list[dict]) -> dict:
    # Prefer 12:00; if not available prefer 15:00; else first entry
    for preferred in (12, 15, 9):
        for e in entries:
            if e.get("hour") == preferred:
                return e
    return entries[0]


def weekday_name(date_str: str) -> str:
    try:
        d = datetime.strptime(date_str, "%Y-%m-%d")
        return d.strftime("%A")  # English weekday
    except Exception:
        return ""


SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS saved_forecasts (
  id BIGSERIAL PRIMARY KEY,
  user_name TEXT NOT NULL,
  city TEXT NOT NULL,
  forecast_json JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_saved_forecasts_created_at
  ON saved_forecasts (created_at DESC);
"""


def ensure_schema(database_url: str) -> None:
    with psycopg.connect(database_url) as conn:
        with conn.cursor() as cur:
            cur.execute(SCHEMA_SQL)
        conn.commit()


def insert_saved_forecast(database_url: str, user_name: str, city: str, forecast_obj: dict) -> None:
    with psycopg.connect(database_url) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO saved_forecasts (user_name, city, forecast_json)
                VALUES (%s, %s, %s::jsonb)
                """,
                (user_name, city, json.dumps(forecast_obj, ensure_ascii=False)),
            )
        conn.commit()


def fetch_saved_forecasts(database_url: str, limit: int = 20) -> list[dict]:
    with psycopg.connect(database_url) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, user_name, city, forecast_json, created_at
                FROM saved_forecasts
                ORDER BY created_at DESC
                LIMIT %s
                """,
                (limit,),
            )
            rows = cur.fetchall()

    out = []
    for (id_, user_name, city, forecast_json, created_at) in rows:
        out.append({
            "id": id_,
            "user_name": user_name,
            "city": city,
            "forecast_json": forecast_json,
            "created_at": created_at,
        })
    return out


app = create_app()

if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=True)