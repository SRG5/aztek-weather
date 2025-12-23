# Aztek Weather – Runbook (Local + Azure)

This runbook is intentionally short and focused on the home-assignment workflow.

## 1) Local development

### Prerequisites
- Python 3.12+
- An OpenWeatherMap API key
- Optional: PostgreSQL (only required for the **Save** and **Saved** pages)

### Setup
```bash
cd app
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
```

Edit `app/.env` (do **not** commit it):
```env
OPENWEATHER_API_KEY=<OPENWEATHER_API_KEY>
FLASK_SECRET_KEY=<FLASK_SECRET_KEY>

# Optional (only needed for /save and /saved):
DATABASE_URL=postgresql://<user>:<password>@<host>:5432/<db>?sslmode=disable
```

Run:
```bash
python app.py
```

Verify:
- `http://127.0.0.1:5000/`
- `http://127.0.0.1:5000/health`

### Database notes
- The app creates the table automatically on first use (`/save` or `/saved`).
- Schema is also available in `app/db/schema.sql`.

---

## 2) Azure deployment (Terraform)

### Prerequisites
- Azure CLI (`az`) installed + authenticated (`az login`)
- Terraform v1.6+

### Deploy
```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with placeholders (do **not** commit secrets):
```hcl
openweather_api_key     = "<OPENWEATHER_API_KEY>"
flask_secret_key        = "<FLASK_SECRET_KEY>"
postgres_admin_password = "<POSTGRES_ADMIN_PASSWORD>"
```

Then:
```bash
terraform init
terraform apply
```

### Outputs
```bash
terraform output
terraform output -raw frontdoor_endpoint_url
terraform output -raw web_app_url
terraform output -raw resource_group
terraform output -raw web_app_name
```

### Redeploy application code only
```bash
terraform apply -target=null_resource.deploy_app
```

### View logs
```bash
RG=$(terraform output -raw resource_group)
APP=$(terraform output -raw web_app_name)

az webapp log tail -g "$RG" -n "$APP"
```

### Destroy everything
```bash
terraform destroy
```
