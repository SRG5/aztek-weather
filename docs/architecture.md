# Aztek Weather - System Architecture

## Executive Summary

Aztek Weather is a production-grade weather forecast application deployed on Microsoft Azure. The system demonstrates enterprise-level cloud architecture patterns including global distribution, high availability, security hardening, and observability.

**Tech Stack:**
- **Application**: Python 3.12 (Flask framework)
- **Database**: PostgreSQL 16 Flexible Server with High Availability
- **Infrastructure**: Azure (multi-service architecture)
- **IaC**: Terraform for infrastructure as code
- **Monitoring**: App Service platform logs (Application Insights configured but SDK not implemented)

---

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet Users                           │
│                    (Global Distribution)                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ HTTPS
                             ▼
                ┌────────────────────────┐
                │   Azure Front Door     │
                │   (Standard SKU)       │
                │                        │
                │  • Global CDN          │
                │  • 120+ Edge Locations │
                │  • HTTPS Enforcement   │
                │  • Health Monitoring   │
                └───────────┬────────────┘
                            │
                            │ HTTPS Only
                            │ End-to-End Encryption
                            ▼
              ┌─────────────────────────┐
              │   App Service (Linux)   │
              │   S1 Standard Plan      │
              │                         │
              │  • 2 Instances          │
              │  • Auto Load Balance    │
              │  • Health Check         │
              │  • Managed Identity     │
              │  • Python 3.12 (Flask)  │
              │  • Gunicorn WSGI        │
              └──┬──────────┬───────┬───┘
                 │          │       │
                 │          │       │
        ┌────────▼──────┐   │       │
        │  Key Vault    │   │       │
        │  (Secrets)    │   │       │
        │               │   │       │
        │ • API Keys    │   │       │
        │ • Passwords   │   │       │
        └───────────────┘   │       │
                            │       │
                   ┌────────▼────┐  │
                   │ PostgreSQL  │  │
                   │  Flexible   │  │
                   │             │  │
                   │ • HA Mode   │  │
                   │ • 2 Nodes   │  │
                   │ • Backups   │  │
                   │             │  │
                   │ (Used only  │  │
                   │  for Save/  │  │
                   │  Retrieve)  │  │
                   └─────────────┘  │
                                    │
                          ┌─────────▼─────────┐
                          │ OpenWeather API   │
                          │  (External)       │
                          │                   │
                          │ • Forecast Data   │
                          │ • Always Called   │
                          └───────────────────┘

Note: App Service communicates with both PostgreSQL (for save/retrieve)
and OpenWeather API (for every forecast request). These services do NOT
communicate with each other - all logic flows through the Flask application.
```

---

## Component Details

### Data Flow Overview

**Request Flow:**
1. User → Front Door → App Service
2. App Service → OpenWeather API (for every forecast request)
3. App Service → PostgreSQL (only when user clicks "Save Forecast" or views "/saved")
4. App Service → Key Vault (at startup to retrieve secrets via Managed Identity)

**Important Notes:**
- PostgreSQL and OpenWeather API **do not communicate directly**
- All business logic runs in the Flask application (App Service)
- Database is **optional** - app works without it for forecast-only usage
- Secrets are loaded once at app startup via Key Vault references

---

### 1. Azure Front Door (Global Entry Point)

**Purpose**: Global traffic distribution and acceleration

**Configuration:**
- **SKU**: Standard_AzureFrontDoor
- **Endpoint**: `fd-endpoint-aztek-weather-neu-*.azurefd.net`
- **Routing**: HTTPS-only with automatic HTTP→HTTPS redirect
- **Health Probe**: `/health` endpoint (HTTPS, every 100s)
- **Backend**: App Service origin with certificate validation

**Key Features:**
- 120+ global edge locations for low-latency access
- Intelligent routing to nearest healthy backend
- DDoS protection (Layer 3/4)
- SSL/TLS termination at edge
- Connection pooling and protocol optimization

**Latency Improvements:**
| User Location | Without Front Door | With Front Door | Improvement |
|--------------|-------------------|-----------------|-------------|
| Israel       | ~120ms            | ~40ms           | 66%         |
| US East      | ~180ms            | ~50ms           | 72%         |
| Japan        | ~300ms            | ~100ms          | 66%         |

---

### 2. App Service (Application Layer)

**Purpose**: Host and run the Flask web application

**Configuration:**
- **OS**: Linux (Ubuntu-based)
- **Runtime**: Python 3.12
- **Server**: Gunicorn WSGI server
- **Plan**: S1 Standard (2 instances for HA)
- **Region**: North Europe (neu)

**Scale-Out Configuration:**
```hcl
worker_count = 2  # 2 instances for zero-downtime deployments
```

**Site Configuration:**
```hcl
always_on           = true      # No cold starts
http2_enabled       = true      # Modern protocol support
minimum_tls_version = "1.2"     # Security compliance
health_check_path   = "/health" # Automated health monitoring
```

**Managed Identity:**
- **Type**: System-assigned
- **Purpose**: Passwordless authentication to Key Vault
- **Permissions**: Read secrets from Key Vault

**Application Settings** (Environment Variables):
```bash
OPENWEATHER_API_KEY=@Microsoft.KeyVault(...)  # From Key Vault
FLASK_SECRET_KEY=@Microsoft.KeyVault(...)     # From Key Vault
DATABASE_URL=postgresql://...                  # Connection string
APPLICATIONINSIGHTS_CONNECTION_STRING=...     # Monitoring
```

---

### 3. Azure Key Vault (Secrets Management)

**Purpose**: Secure storage and management of application secrets

**Configuration:**
- **Name**: `kv-aztek-*`
- **SKU**: Standard
- **Soft Delete**: 7 days retention
- **Purge Protection**: Disabled (dev environment)

**Stored Secrets:**
1. `openweather-api-key` - OpenWeather API key
2. `flask-secret-key` - Flask session encryption key
3. `postgres-admin-password` - Database admin password

**Access Policies:**

| Principal | Permissions | Purpose |
|-----------|-------------|---------|
| App Service Managed Identity | Get, List | Runtime secret retrieval |
| Terraform Service Principal | Get, List, Set, Delete | Secret management |

**Security Benefits:**
- ✅ Secrets never visible in portal or logs
- ✅ Full audit trail of all access
- ✅ Centralized secret rotation
- ✅ No credentials in application code
- ✅ Compliance-ready (GDPR, SOC2, etc.)

---

### 4. PostgreSQL Flexible Server (Data Layer)

**Purpose**: Relational database for weather forecast persistence

**Configuration:**
- **Version**: PostgreSQL 16
- **SKU**: GP_Standard_D2s_v3 (General Purpose)
- **Storage**: 32 GB (SSD)
- **High Availability**: Enabled (SameZone mode)
- **Backup Retention**: 7 days
- **Public Access**: Enabled (with firewall rules)

**High Availability Architecture:**
```
┌─────────────────┐         ┌─────────────────┐
│  Primary Node   │◄───────►│  Standby Node   │
│  (Zone 1)       │  Sync   │  (Zone 1)       │
│                 │  Repli  │                 │
│  Active R/W     │  cation │  Hot Standby    │
└─────────────────┘         └─────────────────┘
         │
         │ Auto Failover (< 120s)
         ▼
┌─────────────────┐
│   Application   │
└─────────────────┘
```

**Failover Behavior:**
- **RTO**: < 120 seconds (Recovery Time Objective)
- **RPO**: ~0 seconds (Recovery Point Objective - sync replication)
- **Automatic**: No manual intervention required
- **Detection**: Azure monitors health every 30 seconds

**Database Schema:**
```sql
CREATE TABLE saved_forecasts (
    id SERIAL PRIMARY KEY,
    user_name VARCHAR(255),
    city VARCHAR(255),
    forecast_data JSONB,
    saved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Firewall Rules:**
- Allow Azure Services: `0.0.0.0` (for App Service connectivity)
- Optional: Allow specific IP for debugging

---

### 5. Application Insights (Infrastructure Component)

**Purpose**: Application performance monitoring and diagnostics

**Configuration:**
- **Type**: Web application
- **Workspace**: Log Analytics workspace
- **Retention**: 30 days
- **Status**: ⚠️ **Configured but not actively used**

**Current State:**
- ✅ Application Insights resource created via Terraform
- ✅ Connection string configured in App Service environment variables
- ❌ **Application code does not import or use Azure Monitor SDK**
- ❌ No telemetry collection implemented in Python code
- ⚠️ **Only infrastructure-level metrics available** (CPU, memory, HTTP status codes from App Service platform)

**Available Data (Platform-Level Only):**
- **HTTP Requests**: Basic request counts and response codes (from App Service, not app code)
- **Performance Counters**: CPU, memory, disk (infrastructure metrics)
- **App Service Logs**: stdout/stderr if logging enabled

**To Enable Full Telemetry (Future Enhancement):**
```python
# Add to requirements.txt:
# azure-monitor-opentelemetry

# Add to app.py:
from azure.monitor.opentelemetry import configure_azure_monitor
configure_azure_monitor(connection_string=os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"))
```

**Sample Platform-Level Queries (Limited Data):**

```kusto
// HTTP status codes from App Service platform
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| summarize count() by ScStatus
| order by count_ desc

// Resource consumption
AzureMetrics
| where ResourceProvider == "MICROSOFT.WEB"
| where TimeGenerated > ago(24h)
| summarize avg(Average) by MetricName
```

**Note:** The application currently relies on basic health checks (`/health` endpoint) and Flask's default logging only. Application Insights provides infrastructure monitoring but **application-level telemetry (custom events, dependencies, exceptions) is not implemented**.

---

## Security Architecture

### Defense in Depth

```
┌──────────────────────────────────────────┐
│  Layer 1: Network (Front Door)          │
│  • DDoS Protection                       │
│  • TLS 1.2+ Encryption                   │
│  • HTTPS Enforcement                     │
└──────────────────────────────────────────┘
              ▼
┌──────────────────────────────────────────┐
│  Layer 2: Application (App Service)      │
│  • Managed Identity (No credentials)     │
│  • Environment Isolation                 │
│  • Health Monitoring                     │
└──────────────────────────────────────────┘
              ▼
┌──────────────────────────────────────────┐
│  Layer 3: Secrets (Key Vault)            │
│  • RBAC Access Control                   │
│  • Audit Logging                         │
│  • Encryption at Rest                    │
└──────────────────────────────────────────┘
              ▼
┌──────────────────────────────────────────┐
│  Layer 4: Data (PostgreSQL)              │
│  • Encryption in Transit (SSL)           │
│  • Encryption at Rest                    │
│  • Firewall Rules                        │
│  • Automated Backups                     │
└──────────────────────────────────────────┘
```

### Security Features

| Feature | Implementation | Benefit |
|---------|----------------|---------|
| **HTTPS Everywhere** | Front Door + App Service | Data encryption in transit |
| **Managed Identity** | System-assigned | Zero credentials in code |
| **Key Vault** | Secret references | Centralized secret management |
| **TLS 1.2+** | Enforced minimum version | Modern encryption standards |
| **Network Isolation** | Firewall rules | Controlled access |
| **Audit Logging** | Key Vault + App Insights | Compliance & forensics |

---

## High Availability & Disaster Recovery

### Availability Design

**SLA Targets:**
- **Front Door**: 99.99% (4 nines)
- **App Service (2 instances)**: 99.95%
- **PostgreSQL (HA)**: 99.95%
- **Combined System**: ~99.90%

**Redundancy Levels:**

1. **Application Layer**:
   - 2 instances in same region
   - Automatic load balancing
   - Health check every 5 minutes
   - Auto-eviction of unhealthy instances

2. **Database Layer**:
   - Primary + Standby (synchronous replication)
   - Automatic failover (< 120s)
   - Daily automated backups (7-day retention)
   - Point-in-time recovery available

3. **Global Layer**:
   - 120+ Front Door edge locations
   - Automatic routing to healthy origins
   - Connection pooling and retry logic

### Failure Scenarios

| Scenario | Detection Time | Recovery Time | Data Loss | User Impact |
|----------|---------------|---------------|-----------|-------------|
| **Single App Instance Failure** | 5 minutes | Immediate | None | None (load balanced) |
| **Database Primary Failure** | 30 seconds | < 120 seconds | None (sync replication) | Brief connection errors |
| **Region-wide Issue** | Immediate | Manual failover required | None (if backups) | Full outage |
| **Front Door Edge Failure** | Immediate | Automatic (DNS) | None | None (multi-edge) |

### Backup Strategy

**Automated Backups:**
- **Frequency**: Daily (automated by Azure)
- **Retention**: 7 days
- **Type**: Full database backup
- **Storage**: Geo-redundant (within region)

**Manual Backup Process:**
```bash
# Export database
pg_dump -h <server>.postgres.database.azure.com \
        -U pgadmin -d weatherdb > backup.sql

# Restore if needed
psql -h <server>.postgres.database.azure.com \
     -U pgadmin -d weatherdb < backup.sql
```

---

## Performance & Scalability

### Performance Optimizations

1. **CDN Caching** (Front Door):
   - Static assets served from edge
   - ~50ms latency globally
   - Reduced origin load

2. **Connection Pooling** (Database):
   - Persistent connections
   - Reduced connection overhead
   - Better throughput

3. **HTTP/2** (App Service):
   - Multiplexed streams
   - Header compression
   - Faster page loads

### Scalability Patterns

**Horizontal Scaling** (Current: 2 instances):
```bash
# Scale to 4 instances
az appservice plan update \
  --name asp-aztek-weather-neu-* \
  --resource-group rg-aztek-weather-neu \
  --number-of-workers 4
```

**Vertical Scaling** (Current: S1):
```bash
# Scale to S2 (more CPU/RAM)
az appservice plan update \
  --name asp-aztek-weather-neu-* \
  --resource-group rg-aztek-weather-neu \
  --sku S2
```

**Database Scaling**:
- Current: GP_Standard_D2s_v3 (2 vCores, 8 GB RAM)
- Can scale up to D64s_v3 (64 vCores, 256 GB RAM)
- Storage can scale to 16 TB

---

## Cost Analysis

### Monthly Cost Breakdown (North Europe)

| Service | SKU/Configuration | Monthly Cost (USD) |
|---------|-------------------|-------------------|
| **App Service Plan** | S1 Standard (2 instances) | ~$146 |
| **PostgreSQL** | GP_Standard_D2s_v3 + HA | ~$220 |
| **Front Door** | Standard + traffic | ~$35-50 |
| **Key Vault** | Standard (10K ops) | ~$0.50 |
| **Application Insights** | 1 GB/day ingestion | ~$5-10 |
| **Log Analytics** | 30-day retention | ~$3-5 |
| **Total Estimated** | | **~$410-$435/month** |

*Prices subject to change and actual usage*

### Cost Optimization Strategies

**For Development:**
```hcl
# Reduce costs by ~60%
app_service_worker_count = 1      # Single instance
postgres_ha_enabled = false       # No HA
frontdoor_sku_name = "Standard"   # Keep Standard
```
**Estimated Dev Cost**: ~$160-180/month

**For Production:**
- Keep current configuration
- Consider Reserved Instances (1-3 year commitments)
- Potential savings: 30-50% with reservations

---

## Technology Choices & Rationale

### Why Azure?
- ✅ Enterprise-grade services
- ✅ Strong compliance certifications
- ✅ Global presence (60+ regions)
- ✅ Integrated monitoring (App Insights)
- ✅ Terraform support (azurerm provider)

### Why North Europe?
- ✅ Lowest cost among comparable EU regions
- ✅ Excellent connectivity to major markets
- ✅ All required services available
- ✅ Front Door compensates for geographic distance

### Why Front Door over Traffic Manager?
- ✅ Modern CDN capabilities
- ✅ Better global performance
- ✅ DDoS protection included
- ✅ Simpler configuration

### Why PostgreSQL over SQL Database?
- ✅ Open-source (no vendor lock-in)
- ✅ Lower cost for similar performance
- ✅ JSONB support (flexible schema)
- ✅ Strong HA capabilities

### Why Managed Identity over Credentials?
- ✅ Zero secrets in code
- ✅ Automatic credential rotation
- ✅ Better security posture
- ✅ Simpler operations

---

## Compliance & Governance

### Security Standards Met:
- ✅ **Encryption in Transit**: TLS 1.2+ everywhere
- ✅ **Encryption at Rest**: Azure Storage encryption
- ✅ **Secret Management**: Azure Key Vault
- ✅ **Audit Logging**: All access logged
- ✅ **Network Security**: Firewall rules
- ✅ **Identity Management**: Managed Identity (Azure AD)

### Compliance Certifications (Azure):
- ISO 27001, 27017, 27018
- SOC 1, 2, 3
- GDPR compliant
- HIPAA (if required)
- PCI DSS Level 1

## References

- [Azure Front Door Documentation](https://learn.microsoft.com/azure/frontdoor/)
- [App Service Best Practices](https://learn.microsoft.com/azure/app-service/app-service-best-practices)
- [PostgreSQL Flexible Server](https://learn.microsoft.com/azure/postgresql/flexible-server/)
- [Key Vault Best Practices](https://learn.microsoft.com/azure/key-vault/general/best-practices)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

---

**Document Version**: 1.0  
**Last Updated**: December 23, 2025  
**Author**: Infrastructure Team
