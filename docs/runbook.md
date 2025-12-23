# Aztek Weather - Deployment Runbook

## Quick Reference Card

```
┌─────────────────────────────────────────────────────┐
│  DEPLOYMENT TIME:  ~15-20 minutes (first deploy)    │
│  ENVIRONMENT:      Azure (North Europe)             │
│  TOOL:             Terraform >= 1.6.0               │
│  RUNTIME:          Python 3.12                      │
│  COST:             ~$410-435/month                  │
└─────────────────────────────────────────────────────┘
```

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Development Setup](#local-development-setup)
3. [Azure Deployment](#azure-deployment)
4. [Verification & Testing](#verification--testing)
5. [Troubleshooting](#troubleshooting)
6. [Maintenance Operations](#maintenance-operations)
7. [Rollback Procedures](#rollback-procedures)
8. [Emergency Contacts](#emergency-contacts)

---

## Prerequisites

### Required Tools

Install the following before starting:

#### 1. Azure CLI

**Windows:**
```powershell
# Download and install from:
# https://aka.ms/installazurecliwindows

# Verify installation
az --version
# Expected: azure-cli 2.50.0 or newer
```

**Linux/Mac:**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az --version
```

#### 2. Terraform

**Windows (Chocolatey):**
```powershell
choco install terraform

# Verify installation
terraform version
# Expected: Terraform v1.6.0 or newer
```

**Manual Installation:**
1. Download from: https://www.terraform.io/downloads
2. Extract to `C:\terraform`
3. Add to PATH: `$env:PATH += ";C:\terraform"`
4. Verify: `terraform version`

#### 3. Python 3.12

**Windows:**
```powershell
# Download from https://www.python.org/downloads/
# During installation, check "Add Python to PATH"

# Verify installation
python --version
# Expected: Python 3.12.x
```

#### 4. OpenWeather API Key

1. Sign up at: https://openweathermap.org/api
2. Navigate to: **Account → My API Keys**
3. Copy your API key (starts with `a`, 32 characters)
4. Save for later use in deployment

### Required Permissions

**Azure Subscription:**
- **Contributor** role at subscription or resource group level
- Ability to create service principals
- Access to create resources in North Europe region

**Verify permissions:**
```bash
az login
az account show
# Note your subscription ID

az role assignment list --assignee $(az account show --query user.name -o tsv) --all
# Should show "Contributor" or "Owner" role
```

---

## Local Development Setup

### Step 1: Clone Repository

```bash
# Clone the project
git clone https://github.com/your-org/aztek-weather.git
cd aztek-weather
```

### Step 2: Set Up Python Environment

**Create virtual environment:**

```bash
# Windows
cd app
python -m venv venv
.\venv\Scripts\activate

# Linux/Mac
cd app
python3 -m venv venv
source venv/bin/activate
```

**Install dependencies:**

```bash
pip install -r requirements.txt
```

Expected packages:
- Flask
- psycopg2-binary
- requests
- azure-monitor-opentelemetry

### Step 3: Configure Local Environment

**Create `.env` file in `app/` directory:**

```bash
# app/.env
OPENWEATHER_API_KEY=your_api_key_here
FLASK_SECRET_KEY=your_random_secret_key_here
DATABASE_URL=sqlite:///local.db  # For local testing
```

**Generate Flask secret key:**

```python
python -c "import secrets; print(secrets.token_hex(32))"
# Copy output to FLASK_SECRET_KEY
```

### Step 4: Initialize Database

```bash
# From app/ directory
sqlite3 local.db < db/schema.sql

# Verify table creation
sqlite3 local.db "SELECT name FROM sqlite_master WHERE type='table';"
# Expected: saved_forecasts
```

### Step 5: Run Locally

```bash
# Development server
python app.py

# Output:
#  * Running on http://127.0.0.1:5000
#  * Debug mode: on
```

**Test locally:**
```bash
# Open browser to: http://localhost:5000
# Try searching for: Tel Aviv, London, New York
```

---

## Azure Deployment

### Phase 1: Prepare Terraform Configuration

#### Step 1: Navigate to Infrastructure Directory

```bash
cd infra/terraform
```

#### Step 2: Create `terraform.tfvars`

```bash
# Copy example file
copy terraform.tfvars.example terraform.tfvars

# Edit with your values
notepad terraform.tfvars  # or vim, code, etc.
```

**Required configuration:**

```hcl
# terraform.tfvars
project_name              = "aztek-weather"
environment               = "prod"
location                  = "northeurope"
location_short            = "neu"

# Your OpenWeather API key (from Prerequisites)
openweather_api_key       = "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"

# Generate with: python -c "import secrets; print(secrets.token_hex(32))"
flask_secret_key          = "your_64_character_hex_string_here"

# Strong password for PostgreSQL (min 8 chars, must include uppercase, lowercase, number)
postgres_admin_password   = "ComplexP@ssw0rd123!"

# Front Door configuration
frontdoor_sku_name       = "Standard_AzureFrontDoor"
```

**Security Note:** ⚠️ **Never commit `terraform.tfvars` to git!** (already in `.gitignore`)

#### Step 3: Initialize Terraform

```bash
terraform init

# Expected output:
# Terraform has been successfully initialized!
```

**What this does:**
- Downloads Azure provider plugins
- Initializes backend state file
- Validates configuration syntax

### Phase 2: Deploy Infrastructure

#### Step 1: Plan Deployment

```bash
terraform plan -out=tfplan

# Review output carefully:
# Plan: 15 to add, 0 to change, 0 to destroy
```

**What will be created:**
- Resource Group
- App Service + Service Plan
- PostgreSQL Flexible Server (with HA)
- Azure Front Door (Profile, Endpoint, Origin, Route)
- Key Vault + Secrets
- Application Insights + Log Analytics Workspace

**Estimated cost:** ~$410-435/month (see [architecture.md](architecture.md) for breakdown)

#### Step 2: Apply Infrastructure

```bash
terraform apply tfplan

# This will take approximately 10-15 minutes
# Progress indicators will show each resource being created
```

**Timeline:**
- Resource Group: ~30 seconds
- App Service: ~2 minutes
- PostgreSQL (with HA): ~5-8 minutes ⏰ *Longest step*
- Front Door: ~3-4 minutes
- Key Vault: ~1 minute
- Application Insights: ~1 minute

**Critical messages to watch for:**
```
✅ azurerm_resource_group.rg: Creation complete
✅ azurerm_postgresql_flexible_server.db: Creation complete
✅ azurerm_cdn_frontdoor_profile.fd: Creation complete
```

#### Step 3: Capture Outputs

After successful deployment:

```bash
terraform output

# Save these values:
# app_service_url         = "https://web-aztek-weather-neu-abc123.azurewebsites.net"
# frontdoor_endpoint_url  = "https://fd-endpoint-aztek-weather-neu-abc123.azurefd.net"
# postgres_server_fqdn    = "psql-aztek-weather-neu-abc123.postgres.database.azure.com"
# key_vault_name          = "kv-aztek-abc123"
```

**Save outputs to file:**
```bash
terraform output > deployment-info.txt
```

### Phase 3: Deploy Application Code

#### Automatic Deployment (Terraform)

```bash
# Already included in terraform apply
# But if you need to redeploy code only:

cd infra/terraform
terraform apply -target=null_resource.deploy_app

# This will:
# 1. Zip app/ directory
# 2. Deploy to App Service
# 3. Wait for health check (max 5 minutes)
```

#### Manual Deployment (Azure CLI)

```bash
# From project root
cd app

# Create deployment package
tar -a -c -f deploy.zip *

# Get app name from terraform output
$APP_NAME = (terraform output -raw app_service_name)

# Deploy
az webapp deploy `
  --resource-group rg-aztek-weather-neu `
  --name $APP_NAME `
  --src-path deploy.zip `
  --type zip `
  --async true

# Check deployment status
az webapp log tail --resource-group rg-aztek-weather-neu --name $APP_NAME
```

### Phase 4: Front Door Propagation

⏰ **IMPORTANT:** Front Door deployment requires global propagation time.

```bash
# Check Front Door deployment status
az afd endpoint show \
  --resource-group rg-aztek-weather-neu \
  --profile-name fd-aztek-weather-neu-* \
  --endpoint-name fd-endpoint-aztek-weather-neu-* \
  --query deploymentStatus

# Possible values:
# - "NotStarted": Deployment queued (0-10 minutes)
# - "InProgress": Propagating to edge locations (10-30 minutes)
# - "Succeeded": Ready to use
```

**Expected Timeline:**
- Immediate (0-5 min): Front Door resource created, may show "NotStarted"
- Short wait (5-15 min): Status changes to "InProgress"
- Full propagation (15-45 min): Status changes to "Succeeded"

**During propagation:**
- App Service URL works immediately ✅
- Front Door URL may show errors or 404 ⏳
- **This is normal** - wait for "Succeeded" status

---

## Verification & Testing

### Health Check Validation

#### 1. App Service Direct Access

```bash
# Get App Service URL
$APP_URL = (terraform output -raw app_service_url)

# Test health endpoint
curl $APP_URL/health

# Expected response:
# {"status": "healthy", "database": "connected"}
```

#### 2. Front Door Access

```bash
# Get Front Door URL
$FD_URL = (terraform output -raw frontdoor_endpoint_url)

# Wait for propagation (if recently deployed)
Start-Sleep -Seconds 300  # Wait 5 minutes

# Test through Front Door
curl $FD_URL/health

# Expected response:
# {"status": "healthy", "database": "connected"}
```

#### 3. Database Connectivity

```bash
# Test from App Service logs
az webapp log tail --resource-group rg-aztek-weather-neu --name $APP_NAME | Select-String "database"

# Should show:
# ✅ "Database connection established"
# ✅ "Health check passed: database connected"
```

### Functional Testing

#### Test 1: Search Weather Forecast

1. Open Front Door URL in browser: `https://fd-endpoint-aztek-weather-neu-*.azurefd.net/`
2. Enter city name: **Tel Aviv**
3. Click **Get Forecast**

**Expected result:**
```
✅ 5-day forecast displayed
✅ Temperature, description, humidity shown
✅ Weather icons loaded
✅ Page loads in < 2 seconds
```

#### Test 2: Save Forecast

1. After searching for a city
2. Enter your name in **Your Name** field: **Test User**
3. Click **Save Forecast**

**Expected result:**
```
✅ Success message: "Forecast saved successfully!"
✅ Redirect to saved forecasts page
✅ Your saved forecast appears in list
```

#### Test 3: View Saved Forecasts

1. Navigate to: `/saved` endpoint
2. Verify saved forecast appears

**Expected data:**
- User name: Test User
- City: Tel Aviv
- Saved timestamp (recent)
- Forecast data (JSON)

#### Test 4: Database Persistence

```bash
# Connect to PostgreSQL (requires firewall rule - see Troubleshooting)
$PG_HOST = (terraform output -raw postgres_server_fqdn)

psql -h $PG_HOST -U pgadmin -d weatherdb

# Query saved forecasts
SELECT id, user_name, city, saved_at FROM saved_forecasts ORDER BY saved_at DESC LIMIT 5;

# Should show your test data
```

### Performance Testing

#### Latency Test (Global)

```bash
# Test from multiple regions (use VPN or online tools)
# Example using curl timing

curl -w "@curl-format.txt" -o /dev/null -s $FD_URL

# curl-format.txt:
# time_namelookup:  %{time_namelookup}\n
# time_connect:     %{time_connect}\n
# time_total:       %{time_total}\n
```

**Expected results:**
| Location | Direct App Service | via Front Door | Improvement |
|----------|-------------------|----------------|-------------|
| Israel   | ~120ms            | ~40ms          | 66%         |
| US East  | ~180ms            | ~50ms          | 72%         |
| Europe   | ~80ms             | ~30ms          | 62%         |

#### Load Test (Apache Bench)

```bash
# Install Apache Bench (ab)
# Windows: Download from Apache Lounge
# Linux: sudo apt-get install apache2-utils

# Run load test (100 requests, 10 concurrent)
ab -n 100 -c 10 $FD_URL/

# Expected results:
# Requests per second:    >50
# Time per request:       <200ms
# Failed requests:        0
```

## Maintenance Operations

### Update Application Code

```bash
# 1. Make changes to app/ directory
# 2. Test locally
cd app
python app.py

# 3. Deploy to Azure
cd ../infra/terraform
terraform apply -target=null_resource.deploy_app

# 4. Verify deployment
az webapp log tail --resource-group rg-aztek-weather-neu --name web-aztek-weather-neu-*
```

### Update Secrets (Key Vault)

```bash
# Update OpenWeather API key
az keyvault secret set \
  --vault-name kv-aztek-* \
  --name openweather-api-key \
  --value "new_api_key_here"

# Update Flask secret key
az keyvault secret set \
  --vault-name kv-aztek-* \
  --name flask-secret-key \
  --value "new_secret_key_here"

# Restart app to pick up changes
az webapp restart --resource-group rg-aztek-weather-neu --name web-aztek-weather-neu-*
```

### Scale App Service

```bash
# Scale out (add instances)
az appservice plan update \
  --name asp-aztek-weather-neu-* \
  --resource-group rg-aztek-weather-neu \
  --number-of-workers 4

# Scale up (change SKU)
az appservice plan update \
  --name asp-aztek-weather-neu-* \
  --resource-group rg-aztek-weather-neu \
  --sku S2
```

### Database Backup

```bash
# Manual backup
pg_dump -h psql-aztek-weather-neu-*.postgres.database.azure.com \
        -U pgadmin \
        -d weatherdb \
        -F c \
        -f backup_$(date +%Y%m%d).dump

# Restore from backup
pg_restore -h psql-aztek-weather-neu-*.postgres.database.azure.com \
           -U pgadmin \
           -d weatherdb \
           -c \
           backup_20231223.dump
```

### Terraform State Backup

```bash
# Pull current state
terraform state pull > state_backup_$(date +%Y%m%d).tfstate

# List resources in state
terraform state list

# Remove resource from state (careful!)
terraform state rm azurerm_resource_name.example
```

---

## Rollback Procedures

### Application Rollback

```bash
# Option 1: Redeploy previous version from git
git checkout <previous_commit_hash>
cd infra/terraform
terraform apply -target=null_resource.deploy_app

# Option 2: Use Azure deployment slots (requires setup)
az webapp deployment slot swap \
  --resource-group rg-aztek-weather-neu \
  --name web-aztek-weather-neu-* \
  --slot staging \
  --target-slot production
```

### Infrastructure Rollback

```bash
# Option 1: Terraform state restore
terraform state push state_backup_20231223.tfstate
terraform plan  # Verify expected state
terraform apply

# Option 2: Destroy and recreate (data loss!)
terraform destroy -target=azurerm_resource_name.example
terraform apply
```

### Database Rollback

```bash
# Point-in-time restore (Azure Portal)
# 1. Navigate to PostgreSQL server
# 2. Click "Restore"
# 3. Select restore point (within 7 days)
# 4. Choose new server name
# 5. Update connection string in App Service

# Or via CLI:
az postgres flexible-server restore \
  --resource-group rg-aztek-weather-neu \
  --name psql-aztek-weather-neu-restored \
  --source-server psql-aztek-weather-neu-* \
  --restore-time "2023-12-22T12:00:00Z"
```

## Appendix: Common Commands Reference

### Terraform Commands
```bash
terraform init          # Initialize working directory
terraform plan          # Preview changes
terraform apply         # Apply changes
terraform destroy       # Destroy infrastructure
terraform output        # Show outputs
terraform state list    # List resources in state
terraform fmt           # Format configuration files
terraform validate      # Validate configuration
```

### Azure CLI Commands
```bash
az login                                    # Login to Azure
az account list                             # List subscriptions
az account set --subscription <ID>          # Set active subscription
az group list                               # List resource groups
az resource list --resource-group <RG>      # List resources in RG
az webapp log tail --name <NAME> --rg <RG>  # Stream app logs
az monitor metrics list                     # List metrics
```

### PostgreSQL Commands
```bash
psql -h <host> -U <user> -d <database>       # Connect to database
\l                                            # List databases
\dt                                           # List tables
\d <table>                                    # Describe table
SELECT * FROM table LIMIT 10;                 # Query data
\q                                            # Quit
```

---

**Document Version**: 1.0  
**Last Updated**: December 23, 2025  
**Maintained By**: DevOps Team
