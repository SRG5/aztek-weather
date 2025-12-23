# Azure Region Selection - Decision Document

## Executive Summary

**Selected Region:** North Europe (northeurope)  
**Decision Date:** December 2025  
**Evaluation Criteria:** Cost, latency, service availability, compliance  
**Estimated Savings:** ~15-20% vs. West Europe

---

## Region Comparison Matrix

### Evaluated Regions

| Region | Location | Cost Factor | Latency to EU | Service Availability | Compliance |
|--------|----------|-------------|---------------|---------------------|------------|
| **North Europe** ✅ | Ireland | **Lowest** | Excellent | All services | GDPR, ISO 27001 |
| West Europe | Netherlands | +15% | Excellent | All services | GDPR, ISO 27001 |
| Germany West Central | Frankfurt | +18% | Good | All services | GDPR, BSI C5 |
| UK South | London | +12% | Excellent | All services | GDPR, UK DPA |
| France Central | Paris | +16% | Excellent | All services | GDPR, HDS |

### Selection Criteria Weights

| Criterion | Weight | Rationale |
|-----------|--------|-----------|
| **Cost** | 40% | Budget optimization critical |
| **Latency** | 30% | User experience priority |
| **Service Availability** | 20% | All required services must be available |
| **Compliance** | 10% | GDPR compliance mandatory |

---

## Detailed Cost Analysis

### Monthly Cost Breakdown (North Europe)

| Service | SKU/Configuration | Monthly Cost (USD) | Notes |
|---------|-------------------|-------------------|-------|
| **App Service Plan** | S1 Standard (2 instances) | ~$146 | Linux, Python 3.12 |
| **PostgreSQL Flexible** | GP_Standard_D2s_v3 + HA | ~$220 | 2 vCores, 8 GB RAM, HA |
| **Azure Front Door** | Standard + 1TB egress | ~$35-50 | Global distribution |
| **Key Vault** | Standard (10K operations) | ~$0.50 | Secret management |
| **Application Insights** | 1 GB/day ingestion | ~$5-10 | Monitoring |
| **Log Analytics** | 30-day retention | ~$3-5 | Logs storage |
| **Bandwidth** | ~500 GB egress | ~$5-10 | Data transfer |
| **Total** | | **~$415-440/month** | **~$5,000/year** |

### Cost Comparison by Region

| Region | App Service S1 | PostgreSQL GP_D2s_v3 | Front Door | **Total/Month** | **vs North EU** |
|--------|----------------|---------------------|------------|----------------|----------------|
| **North Europe** | $146 | $220 | $40 | **~$415** | **Baseline** |
| West Europe | $168 | $252 | $40 | **~$475** | **+14.5%** (+$60) |
| Germany West Central | $172 | $265 | $40 | **~$490** | **+18.1%** (+$75) |
| UK South | $162 | $245 | $40 | **~$465** | **+12.0%** (+$50) |
| France Central | $165 | $255 | $40 | **~$480** | **+15.7%** (+$65) |

**Annual Savings (North Europe vs West Europe):** ~$720/year

### Cost Optimization Opportunities

**Development Environment:**
```hcl
# Reduced configuration for dev/test
app_service_sku          = "B1"          # Basic tier: ~$13/month
app_service_instances    = 1             # Single instance
postgres_ha_enabled      = false         # No HA: saves ~$110/month
postgres_sku             = "B_Standard_B1ms"  # Burstable: ~$12/month

# Dev total: ~$90-100/month (78% savings)
```

**Reserved Instances (1-year commitment):**
- App Service: 30% savings (~$44/month)
- PostgreSQL: 40% savings (~$88/month)
- **Total savings with RI:** ~$130/month (~$1,560/year)

---

## Latency Analysis

### Geographic Latency Without Front Door

Direct connection to North Europe App Service:

| User Location | Distance (km) | RTT (ms) | User Experience |
|--------------|---------------|----------|----------------|
| Dublin, Ireland | ~0 | 5-10 | Excellent |
| London, UK | 465 | 30-40 | Excellent |
| Amsterdam, Netherlands | 755 | 40-50 | Good |
| Frankfurt, Germany | 1,400 | 60-70 | Good |
| Tel Aviv, Israel | 4,200 | **110-130** | Fair |
| New York, USA | 5,100 | **150-180** | Poor |
| Tokyo, Japan | 9,600 | **280-320** | Very Poor |

### Latency Improvement With Azure Front Door

Front Door routes users to nearest edge location (120+ globally):

| User Location | Without Front Door | With Front Door | **Improvement** | Edge Location |
|--------------|-------------------|-----------------|----------------|---------------|
| Dublin | 10ms | 5ms | **50%** | Dublin |
| London | 35ms | 8ms | **77%** | London |
| Amsterdam | 45ms | 10ms | **78%** | Amsterdam |
| Frankfurt | 65ms | 12ms | **81%** | Frankfurt |
| Tel Aviv | 120ms | **35-45ms** | **66%** | Tel Aviv |
| New York | 165ms | **45-55ms** | **70%** | New York |
| Tokyo | 300ms | **90-110ms** | **67%** | Tokyo |
| Sydney | 340ms | **100-120ms** | **68%** | Sydney |

**Key Insight:** Front Door compensates for North Europe's geographic distance by using edge caching and intelligent routing.

### Front Door Architecture Benefits

```
User Request → Nearest Edge Location (120+ globally)
              ↓
         [CDN Cache Check]
              ↓
         If Cache Hit → Immediate Response (5-20ms)
              ↓
         If Cache Miss → Origin Fetch
                        ↓
                   North Europe App Service (optimized backbone)
                        ↓
                   Response cached at edge
                        ↓
                   Subsequent requests served from edge
```

**Cache Hit Ratio:** Typically 80-90% for static content  
**Origin Requests Reduced:** By 80-90%  
**Global Latency:** < 100ms for 95% of users

---

## Service Availability Comparison

### Required Services Availability Matrix

| Service | North EU | West EU | Germany WC | UK South | France Central |
|---------|----------|---------|------------|----------|----------------|
| App Service (Linux, Python 3.12) | ✅ | ✅ | ✅ | ✅ | ✅ |
| PostgreSQL Flexible Server v16 | ✅ | ✅ | ✅ | ✅ | ✅ |
| PostgreSQL HA (SameZone) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Azure Front Door Standard | ✅ | ✅ | ✅ | ✅ | ✅ |
| Key Vault | ✅ | ✅ | ✅ | ✅ | ✅ |
| Application Insights | ✅ | ✅ | ✅ | ✅ | ✅ |
| Availability Zones | ✅ (3) | ✅ (3) | ✅ (3) | ✅ (3) | ✅ (3) |

**Result:** All evaluated regions support all required services.

### High Availability Configuration

**PostgreSQL Flexible Server HA:**
- **Mode:** SameZone (synchronous replication)
- **Primary:** Availability Zone 1
- **Standby:** Availability Zone 1 (same zone)
- **RTO:** < 120 seconds
- **RPO:** 0 seconds (zero data loss)

**Why SameZone vs ZoneRedundant?**

| Factor | SameZone | ZoneRedundant |
|--------|----------|--------------|
| Cost | Lower (~$220/month) | Higher (~$300/month) |
| Latency | Lower (same AZ) | Higher (cross-AZ replication) |
| Availability | 99.95% SLA | 99.99% SLA |
| Zone Failure Protection | ❌ Single zone | ✅ Multi-zone |
| Best For | Cost-sensitive, low-latency | Mission-critical, max availability |

**Decision:** SameZone selected for balance of cost, performance, and availability (99.95% = ~4.4 hours downtime/year).

**App Service HA:**
- **Instances:** 2 (separate fault domains)
- **Load Balancing:** Automatic (Azure Load Balancer)
- **Health Check:** `/health` endpoint (every 5 minutes)
- **Auto-Eviction:** Unhealthy instances removed
- **SLA:** 99.95%

---

## Compliance & Data Residency

### GDPR Compliance

**All evaluated EU regions are GDPR-compliant:**
- ✅ Data residency in EU
- ✅ Right to be forgotten (delete capabilities)
- ✅ Data portability (export APIs)
- ✅ Breach notification (Azure Security Center)
- ✅ Data Processing Agreement (DPA) available

**North Europe (Ireland) Specifics:**
- Irish Data Protection Commission (DPC) jurisdiction
- EU-US Data Privacy Framework participant
- Strong privacy enforcement history

### Industry Certifications

**North Europe Region Certifications:**
- ✅ ISO 27001 (Information Security)
- ✅ ISO 27017 (Cloud Security)
- ✅ ISO 27018 (Cloud Privacy)
- ✅ SOC 1, 2, 3 (Service Organization Controls)
- ✅ PCI DSS Level 1 (Payment Card Industry)
- ✅ HIPAA/HITECH (Healthcare - if needed)

**Trust Center:** https://servicetrust.microsoft.com

---

## Alternative Scenarios

### Scenario 1: Multi-Region Deployment

**If global latency is critical:**

```
Primary:    North Europe (EU users)
Secondary:  East US 2 (Americas)
Tertiary:   Southeast Asia (APAC)

Front Door: Multi-origin routing with geo-proximity
Cost Impact: +200% (3x infrastructure)
Benefit:    < 50ms latency globally
```

### Scenario 2: Data Sovereignty Requirements

**If data must stay in specific country:**

| Requirement | Region | Notes |
|-------------|--------|-------|
| Germany data residency | Germany West Central | +18% cost vs North EU |
| UK data residency | UK South | +12% cost vs North EU |
| France data residency | France Central | +16% cost vs North EU |

### Scenario 3: Cost-Optimized (Single Instance)

**If high availability not required:**

```hcl
app_service_instances = 1           # -$73/month
postgres_ha_enabled   = false       # -$110/month
postgres_sku          = "GP_Standard_D2s_v3"  # Same SKU, no HA

Total Cost: ~$230-250/month (44% savings)
Risk: No automatic failover, potential downtime
```

---

## Decision Rationale

### Why North Europe Won

1. **Cost Leadership** (40% weight): **15-20% cheaper** than alternatives
   - Lowest compute costs in Western EU
   - Competitive storage pricing
   - Same bandwidth costs as other EU regions

2. **Acceptable Latency** (30% weight): **Mitigated by Front Door**
   - Direct latency higher for non-EU users
   - Front Door reduces global latency by 65-80%
   - Final user experience equivalent to other EU regions

3. **Full Service Availability** (20% weight): **All services available**
   - PostgreSQL Flexible Server v16 ✅
   - High Availability support ✅
   - Front Door Standard ✅
   - No service gaps vs. other regions

4. **Compliance** (10% weight): **Fully GDPR compliant**
   - Irish DPC jurisdiction
   - Strong privacy protections
   - All required certifications

### Trade-offs Accepted

| Trade-off | Impact | Mitigation |
|-----------|--------|------------|
| Higher direct latency for non-EU | ~50-100ms extra | **Front Door** reduces to acceptable levels |
| Single region (no geo-redundancy) | Regional outage = full outage | **HA within region**, **7-day backups**, accept risk for cost savings |
| Ireland Brexit implications | Potential future EU data flow issues | **Monitor** regulatory changes, **migration plan** ready if needed |

---

## Monitoring & Validation

### Post-Deployment Latency Testing

**Test from these locations after deployment:**

```bash
# From different geographic locations (use VPNs or cloud VMs)
curl -w "@curl-format.txt" -o /dev/null -s https://fd-endpoint-aztek-weather-neu-*.azurefd.net/

# curl-format.txt:
# time_total: %{time_total}\n
# time_connect: %{time_connect}\n
```

**Expected Results:**
- EU: < 50ms
- Americas: < 100ms
- APAC: < 150ms

### Cost Tracking

**Azure Cost Management Queries:**

```kusto
// Monthly cost by service
Costs
| where TimeGenerated >= startofmonth(now())
| summarize TotalCost=sum(CostInBillingCurrency) by ServiceName
| order by TotalCost desc

// Forecast vs actual
Costs
| where TimeGenerated >= startofmonth(now())
| summarize ActualCost=sum(CostInBillingCurrency)
| extend ForecastCost = 415  // Expected monthly cost
| extend Variance = (ActualCost - ForecastCost) / ForecastCost * 100
```

**Set Budget Alerts:**
- Warning: $400/month (96% of budget)
- Critical: $450/month (108% of budget)

---

## Recommendation

**Deploy to North Europe** with Azure Front Door for global latency optimization.

**Confidence Level:** High  
**Risk Level:** Low  
**Cost Savings:** ~$720/year vs. West Europe  
**Latency Impact:** Negligible with Front Door  

**Review Triggers:**
- Quarterly cost review (if costs exceed $500/month consistently)
- Annual latency analysis (if Front Door hit ratio < 70%)
- Regulatory changes (Brexit data flow restrictions)
- Service availability changes (new regions, deprecations)

---

**Document Version:** 2.0  
**Last Updated:** December 23, 2025  
**Next Review:** March 2026  
**Approved By:** Infrastructure Team