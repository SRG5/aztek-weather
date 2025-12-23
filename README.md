# Aztek Weather

A small **Flask** web application built for the Aztek Technologies home assignment.

Users enter **name** + **city**, the app fetches a **multi‑day forecast** from **OpenWeatherMap (free plan)**, renders it in a simple UI, and can **save a forecast snapshot** into **PostgreSQL**.

## Repository structure

- `app/` — Flask app (UI + OpenWeather + PostgreSQL save)
- `infra/terraform/` — Azure infrastructure (Terraform) + automated zip deployment
- `docs/` — Architecture / runbook / region choice / troubleshooting
- `ai/` — AI prompts log (step 10 requirement)

## High-level architecture

- **Azure App Service (Linux, Python 3.12)** hosts the Flask app
- **Azure Database for PostgreSQL Flexible Server** stores saved forecasts
- **Azure Front Door Standard** provides a single global HTTPS entry point
- **Azure Key Vault** stores secrets (OpenWeather, Flask secret, Postgres admin password)
- **Application Insights + Log Analytics** for monitoring

See: `docs/architecture.md`

## Run locally

### Prerequisites

- Python 3.12+
- OpenWeatherMap API key
- Optional: PostgreSQL (required only for the **Save** and **Saved** pages)

### Steps

```bash
cd app
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
# edit app/.env with your values (do not commit)

python app.py
```

Open:
- `http://127.0.0.1:5000/`
- `http://127.0.0.1:5000/health`

## Deploy to Azure (Terraform)

### Prerequisites

- Azure subscription + permissions to create resources
- Azure CLI authenticated (`az login`)
- Terraform v1.6+

### Steps

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars

# Fill placeholders in terraform.tfvars (NO real secrets should be committed)

terraform init
terraform apply
```

Terraform will:
1. Provision Azure resources.
2. Package `app/` as a zip (`archive_file`).
3. Deploy the zip using Azure CLI (`az webapp deploy`) during `terraform apply`.

### Outputs

```bash
terraform output -raw frontdoor_endpoint_url
terraform output -raw web_app_url
```

### Clean up

```bash
terraform destroy
```

## AI usage log (Step 10)

The required prompts/instructions log is here:
- `ai/prompts.md`

## Notes (assignment-oriented)

- The database uses public network access + firewall rules for simplicity in this assignment.
- Multi-region active/active is not implemented; Front Door is used as a stable global entry point.
