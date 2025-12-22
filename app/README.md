# Aztek Weather App (Exercise)

A small public web application built for the Aztek Technologies home assignment.

## What the app does
The application:
1. Uses the **OpenWeatherMap (free plan)** API to retrieve a **multi-day forecast** for a given city.
2. Displays a **web page** where the user enters:
   - **Name**
   - **City**
3. Shows the forecast in a **clean UI** (cards/table).
4. On **Save**, stores the user's **name** + the **forecast snapshot** in a **PostgreSQL** database.

---

## User Flow
1. Open the home page.
2. Enter **name** and **city**.
3. Click **Get Forecast**.
4. View the forecast results.
5. Click **Save** to persist the forecast to PostgreSQL.

---

## Endpoints (minimal)
- `GET /`  
  Home page with form (name + city)

- `POST /forecast`  
  Calls OpenWeatherMap and renders the forecast results

- `POST /save`  
  Saves `{ user_name, city, forecast_json }` into PostgreSQL

- `GET /saved` *(optional but recommended)*  
  Lists recently saved forecasts (useful to verify DB writes)

---

## Data stored in the database
Table: `saved_forecasts`

Saved fields:
- `user_name` (text)
- `city` (text)
- `forecast_json` (jsonb) – forecast snapshot at save time
- `created_at` (timestamptz)

Why JSONB?
- Keeps the saved snapshot consistent with what the user saw.
- Avoids frequent schema changes while iterating.

---

## Configuration (Environment Variables)
- `OPENWEATHER_API_KEY` – your OpenWeatherMap API key
- `DATABASE_URL` – PostgreSQL connection string  
  Example: `postgresql://user:pass@host:5432/dbname`

---

## Run locally (high level)
1. Create and activate a virtual environment.
2. Install requirements.
3. Set `OPENWEATHER_API_KEY` and `DATABASE_URL`.
4. Run the app.

> Exact commands will be added once the code skeleton is generated.

---

## Notes
- This project is designed to be deployed to **Azure App Service** (Python runtime).
- PostgreSQL is intended to run on **Azure Database for PostgreSQL Flexible Server**.