# Aztek Weather ☁️

Modern weather forecast application with global distribution and enterprise-grade cloud architecture.

## 🌍 Overview

5-day weather forecasts for cities worldwide, powered by:
- ✅ **Azure Front Door** - Global distribution with 120+ edge locations
- ✅ **High Availability** - Multi-instance app service with database HA
- ✅ **Security Hardening** - Managed Identity + Key Vault
- ✅ **Infrastructure as Code** - Full Terraform automation

## ✨ Features

- 🔍 City search (global coverage)
- 📅 5-day forecast with detailed metrics
- 💾 Save and view forecast history
- ⚡ < 50ms latency worldwide
- 🔒 HTTPS everywhere with zero secrets in code

## 🛠️ Technology Stack

**Backend:** Python 3.12 | Flask 3.0+ | Gunicorn  
**Database:** PostgreSQL 16 Flexible Server  
**Cloud:** Microsoft Azure  
**IaC:** Terraform 1.6+  
**CDN:** Azure Front Door Standard  
**APIs:** OpenWeather API

---

## 🚀 Quick Start

### Local Development
```bash
cd app
python -m venv venv
source venv/bin/activate  # Windows: .\venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

📖 **[Complete Setup Guide](docs/runbook.md#local-development)**

### Azure Deployment
```bash
cd infra/terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

📖 **[Full Deployment Guide](docs/runbook.md#azure-deployment)**

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **[Architecture](docs/architecture.md)** | System design, components, data flow, security architecture |
| **[Runbook](docs/runbook.md)** | Deployment steps, troubleshooting, monitoring, maintenance |
| **[Region Choice](docs/region-choice.md)** | Azure region selection, cost analysis, latency optimization |

---

## 📝 Project Info

**Version:** 1.0.0  
**Status:** Production Ready  
**Cost:** ~$410-440/month  
**Location:** North Europe (northeurope)
