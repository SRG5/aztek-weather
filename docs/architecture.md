# Aztek Weather – Architecture (Home Assignment)

## Overview

Aztek Weather is a small Flask application deployed on Azure.
It lets users search a city’s weather forecast via **OpenWeatherMap** and optionally save forecast snapshots to **PostgreSQL**.

**Runtime:** Python 3.12 (Flask + Gunicorn)  
**IaC:** Terraform (AzureRM provider)

## High-level diagram

```
Users
  │ HTTPS
  ▼
Azure Front Door (Standard)
  │ HTTPS
  ▼
Azure App Service (Linux, Python 3.12 / Gunicorn)
  │            │
  │            ├── OpenWeatherMap API (forecast)
  │
  ├── Azure Key Vault (secrets via Key Vault references + Managed Identity)
  │
  └── Azure Database for PostgreSQL Flexible Server (save / list saved forecasts)
```

## Components

### 1) Azure Front Door (Standard)

**Purpose:** A single HTTPS entry point in front of the App Service.

**What it does in this project:**
- HTTPS routing to the App Service origin
- HTTP→HTTPS redirect

> Notes:
> - No WAF rules are configured in Terraform for this assignment (WAF can be added later if required).
> - No explicit caching rules are defined; the app is treated as a dynamic origin.

### 2) Azure App Service (Linux)

**Purpose:** Hosts the Flask application.

**Key settings (as deployed by Terraform):**
- Linux Web App + App Service Plan (SKU and instance count are configurable via variables)
- `always_on`, HTTP/2 enabled, minimum TLS 1.2
- System-assigned Managed Identity enabled

**Application responsibilities:**
- `POST /forecast` calls OpenWeatherMap and renders a multi-day forecast UI
- `POST /save` writes a forecast snapshot (JSON) to PostgreSQL
- `GET /saved` lists the latest saved items
- `GET /health` returns a simple `{ "status": "ok" }` (used by deployment verification)

### 3) Azure Key Vault

**Purpose:** Stores secrets without committing them to the repository.

**Secrets stored:**
- OpenWeather API key
- Flask secret key
- PostgreSQL admin password

**How the Web App reads secrets:**
- Terraform configures **Key Vault references** in App Service settings.
- The App Service Managed Identity is granted `get/list` permissions on secrets.

### 4) PostgreSQL Flexible Server

**Purpose:** Stores saved forecast snapshots.

**Notes (assignment-oriented):**
- Database access is enabled via public network access with firewall rules:
  - Allow “Azure services” (`0.0.0.0/0.0.0.0`) so the App Service can connect.
  - Optional rule to allow a specific IP for local `psql` debugging.
- HA is configurable via Terraform (`postgres_ha_enabled`).

**Schema:**
- `saved_forecasts` table (JSON payload stored in `jsonb`)  
  See: `app/db/schema.sql`

### 5) Observability

Terraform provisions:
- Log Analytics workspace
- Application Insights resource
- App Service has an App Insights connection string set

> The Flask app does not include custom telemetry/instrumentation code by default.
> For deeper tracing/metrics, add explicit OpenTelemetry/Azure Monitor instrumentation as a future enhancement.

## Security notes

- HTTPS-only at the edge and at the Web App
- Secrets are stored in Key Vault (not in source code)
- The DB is reachable via public endpoint for simplicity (tighten with Private Endpoints/VNet integration in a production setup)
