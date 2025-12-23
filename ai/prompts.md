# AI Prompts / Instructions Log (Aztek Weather)

This document lists the **prompts/instructions** (and the **relevant model outputs**) used with AI tools while building this project, plus what was **verified/changed manually**.

> **Security guardrail:** This file contains **no real secrets**. Any sensitive values are replaced with placeholders like `<OPENWEATHER_API_KEY>`, `<DATABASE_URL>`, `<SUBSCRIPTION_ID>`.

## AI tools used

1) **ChatGPT (OpenAI)**
   - Used mainly for: end‑to‑end planning, Flask/OpenWeather implementation guidance, PostgreSQL persistence approach, Terraform architecture decisions, deployment troubleshooting, and documentation cleanup.

2) **GitHub Copilot Chat (VS Code)**
   - Used mainly for: **small Terraform (Front Door) refactors** and **quick code review** (formatting, naming, minor edits).
   - Not used for building the Flask app or the database layer.

## How AI was used (short)

- AI was used to **accelerate** implementation and troubleshooting (ideas, examples, edge cases).
- Every AI output was treated as a **draft** and then verified:
  - locally (`python app.py`, basic UI flows),
  - on Azure (`terraform plan/apply`, App Service logs, Kudu deployment logs),
  - security review (no secrets committed; placeholders only).

---

# 1) Application (Flask + UI + OpenWeather) — ChatGPT

## 1.1 App structure + endpoints

**Prompt (ChatGPT):**
> Build a small Flask app: a form (name + city), fetch OpenWeather (free plan) forecast, render results in HTML, and add `/health`. Provide a minimal repo structure and files.

**Relevant model output (summary):**
- Suggested endpoints: `GET /`, `POST /forecast`, `GET /health`.
- Recommended using environment variables: `OPENWEATHER_API_KEY`, `FLASK_SECRET_KEY`.
- Proposed a simple templates layout (`templates/base.html`, `index.html`, `forecast.html`).
- Recommended handling invalid city/API failures with user‑friendly errors (no stack traces).

**What I verified/changed manually:**
- Implemented the routes and tested in browser:
  - `/health` returns 200 and a small JSON payload.
  - Submitting a city renders a multi‑day forecast page.
- Added defensive error handling for missing env vars and API errors.

## 1.2 OpenWeather details (free plan constraints)

**Prompt (ChatGPT):**
> OpenWeather free plan gives a 5‑day / 3‑hour forecast. How should I present this as “multi‑day forecast” in a simple UI?

**Relevant model output (summary):**
- Suggested grouping the 3‑hour entries by **date** and showing:
  - temperature range,
  - representative weather description/icon,
  - optional “next hours” list for the current day.

**What I verified/changed manually:**
- Ensured the UI clearly communicates the forecast is based on 3‑hour intervals.
- Validated the grouping logic visually (multiple cities).

---

# 2) Persistence (PostgreSQL) — ChatGPT

## 2.1 Minimal DB design

**Prompt (ChatGPT):**
> I need to “save the forecast to Postgres”. Propose a minimal schema that’s fast to implement and easy to verify.

**Relevant model output (summary):**
- Recommended a single table like `saved_forecasts` with:
  - `id` (PK),
  - `user_name`,
  - `city`,
  - `forecast_json` (store snapshot as JSON/JSONB),
  - `created_at`.

**What I verified/changed manually:**
- Implemented the schema (SQL file) and validated inserts/selects.
- Ensured parameterized SQL is used (no string concatenation).

## 2.2 DB connection + safe configuration

**Prompt (ChatGPT):**
> Best practice for `DATABASE_URL` parsing and safe defaults in a small Flask assignment?

**Relevant model output (summary):**
- Keep configuration via env vars only (no hardcoded credentials).
- Fail fast with clear error messages if `DATABASE_URL` is missing/invalid.

**What I verified/changed manually:**
- Confirmed the app still works without DB enabled (when `DATABASE_URL` is not set).
- Confirmed saving works when DB is configured.

---

# 3) Terraform infrastructure — ChatGPT (+ small Copilot refactor)

## 3.1 Azure architecture selection

**Prompt (ChatGPT):**
> Suggest an Azure architecture for: Flask on App Service, Postgres, monitoring, Key Vault, and a global entry point. Keep it reasonable for a home assignment.

**Relevant model output (summary):**
- App hosting: **Linux App Service** (Python 3.12).
- Database: **Azure Database for PostgreSQL Flexible Server**.
- Secrets: **Key Vault** (+ Managed Identity for the Web App).
- Monitoring: **Application Insights + Log Analytics**.
- Global entry: **Azure Front Door Standard**.
- Noted tradeoffs (public DB vs. private networking) and to document them.

**What I verified/changed manually:**
- Implemented Terraform across separate files (`main.tf`, `postgres.tf`, `keyvault.tf`, `frontdoor.tf`, etc.).
- Validated `terraform plan` matches the architecture and `terraform apply` provisions successfully.

## 3.2 Front Door Terraform refactor (Copilot)

**Prompt (Copilot Chat):**
> Refactor `frontdoor.tf`: improve readability (resource naming, split logical blocks), keep behavior identical, and ensure outputs are clear.

**Relevant model output (summary):**
- Suggested small renames and formatting for clarity.
- Suggested clearer outputs (Front Door endpoint).

**What I verified/changed manually:**
- Confirmed Front Door still routes to the Web App correctly.
- Verified `/health` works through Front Door URL.

---

# 4) Deploy automation (Terraform‑driven zip deploy) — ChatGPT

## 4.1 Zip packaging + deploy hook

**Prompt (ChatGPT):**
> In Terraform: zip the `app/` folder and deploy it to Azure App Service during `terraform apply`. Re-deploy only when the app content changes.

**Relevant model output (summary):**
- Use `archive_file` to build a zip artifact.
- Use `null_resource` + `local-exec` to run `az webapp deploy` (zip deploy).
- Use the archive hash (e.g., `output_sha`) as a trigger for idempotent redeploys.

**What I verified/changed manually:**
- Ensured build artifacts and virtualenv folders are excluded from the zip.
- Confirmed a content change in `app/` triggers a new deploy.

## 4.2 Terraform + curl `%{http_code}` escaping bug

**Prompt (ChatGPT):**
> Terraform fails with `Invalid template control keyword` on a line using `curl -w "%{http_code}"`. How to fix?

**Relevant model output (summary):**
- Terraform treats `%{...}` as template syntax.
- Fix by escaping: `%%{http_code}` (so the shell receives `%{http_code}`).

**What I verified/changed manually:**
- Applied the escape fix and re-ran `terraform init/plan/apply` successfully.

## 4.3 Deployment stability: SCM/Kudu readiness

**Prompt (ChatGPT):**
> Zip deploy sometimes fails because the SCM/Kudu endpoint is not ready right after provisioning. Add a safe readiness check.

**Relevant model output (summary):**
- Add a short delay (`time_sleep`) and retry logic to wait until the SCM endpoint responds before triggering deploy.

**What I verified/changed manually:**
- Tuned retry count/timeouts to avoid flaky applies.
- Confirmed the final flow consistently completes.

---

## Final notes

- AI outputs were used as guidance; the final implementation was validated by running the app locally and in Azure.
- No secrets are included in this document or committed in the repository.

**Last updated:** 2025-12-24
