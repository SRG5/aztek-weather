# Terraform – Aztek Weather (infra)

This folder provisions the Azure infrastructure and deploys the application using Terraform.

## What it creates

- Resource Group in `var.location` (default: **North Europe**)  
- App Service Plan (Linux) + Linux Web App (Python 3.12 / Gunicorn)
- Azure Database for PostgreSQL Flexible Server + DB
  - High Availability is **configurable** (`var.postgres_ha_enabled`)
  - When enabled, it uses **zone-redundant HA** (primary + standby in different AZs)
- Key Vault (stores OpenWeather / Flask secret / Postgres password)
- Application Insights + Log Analytics
- PostgreSQL firewall rule allowing Azure services (`0.0.0.0-0.0.0.0`) for simplicity in this assignment
- Azure Front Door Standard as a **global HTTPS entry point**
  - **No WAF policy is configured** in this Terraform (can be added later if required)

## High-level flow

```
Users → Azure Front Door → App Service → PostgreSQL
                    │
                    └→ Key Vault (secrets via Key Vault references)
```

## Run (Cloud Shell or local)

### Prerequisites

- Terraform v1.6+
- Azure CLI authenticated (`az login`)

### Configure variables

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and provide values (do **not** commit secrets):

```hcl
openweather_api_key     = "<OPENWEATHER_API_KEY>"
flask_secret_key        = "<FLASK_SECRET_KEY>"
postgres_admin_password = "<POSTGRES_ADMIN_PASSWORD>"
```

### Deploy

```bash
terraform init
terraform plan
terraform apply
```

### Outputs

```bash
terraform output
terraform output -raw frontdoor_endpoint_url
terraform output -raw web_app_url
```

### Destroy

```bash
terraform destroy
```
