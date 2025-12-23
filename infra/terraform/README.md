# Terraform - Aztek Weather (infra)

Creates:
- Resource Group (North Europe)
- App Service Plan (Linux) + Linux Web App (Python)
- Azure Database for PostgreSQL Flexible Server + DB (HA Zone Redundant)
- Application Insights + Log Analytics
- PostgreSQL firewall rule to allow Azure services (0.0.0.0-0.0.0.0)
- **Azure Front Door** with WAF protection (global CDN endpoint)

## Architecture

```
Users → Azure Front Door (WAF) → App Service → PostgreSQL
         ↓
     Edge Locations
     (Global CDN)
```

## Run from Azure Cloud Shell

```bash
cd infra/terraform
terraform -version

export TF_VAR_openweather_api_key="..."
export TF_VAR_flask_secret_key="..."
export TF_VAR_postgres_admin_password="..."

terraform init
terraform plan
terraform apply