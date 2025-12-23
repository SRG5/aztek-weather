## Troubleshooting

### Issue 1: Front Door Returns 404 or 5xx Errors

**Symptoms:**
- Front Door URL shows "Origin not found" or 404
- App Service URL works fine
- Just deployed infrastructure

**Diagnosis:**
```bash
# Check Front Door deployment status
az afd endpoint show \
  --resource-group rg-aztek-weather-neu \
  --profile-name fd-aztek-weather-neu-* \
  --endpoint-name fd-endpoint-aztek-weather-neu-* \
  --query deploymentStatus
```

**Solution:**
```
If deploymentStatus is "NotStarted" or "InProgress":
  → Wait 15-45 minutes for global propagation
  → This is NORMAL behavior for Front Door
  → App Service URL works during this time

If deploymentStatus is "Succeeded" but still errors:
  → Check origin health:
    az afd origin show \
      --resource-group rg-aztek-weather-neu \
      --profile-name fd-aztek-weather-neu-* \
      --origin-group-name og-aztek-weather \
      --origin-name app-service \
      --query healthProbeSettings

  → Verify App Service is responding to /health endpoint
```

### Issue 2: Database Connection Failures

**Symptoms:**
- App logs show "could not connect to server"
- `/health` endpoint returns `{"database": "disconnected"}`
- 500 errors when saving forecasts

**Diagnosis:**
```bash
# Check PostgreSQL server status
az postgres flexible-server show \
  --resource-group rg-aztek-weather-neu \
  --name psql-aztek-weather-neu-* \
  --query state

# Should be: "Ready"
```

**Solution:**

**A) Firewall Rules:**
```bash
# Verify Azure services can access
az postgres flexible-server firewall-rule list \
  --resource-group rg-aztek-weather-neu \
  --name psql-aztek-weather-neu-*

# Should show rule with startIpAddress=0.0.0.0, endIpAddress=0.0.0.0
# If missing, add:
az postgres flexible-server firewall-rule create \
  --resource-group rg-aztek-weather-neu \
  --name psql-aztek-weather-neu-* \
  --rule-name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

**B) Connection String:**
```bash
# Verify DATABASE_URL in App Service settings
az webapp config appsettings list \
  --resource-group rg-aztek-weather-neu \
  --name web-aztek-weather-neu-* \
  | Select-String "DATABASE_URL"

# Should contain: postgresql://pgadmin@<server>:...
```

**C) Admin Password:**
```bash
# Verify Key Vault secret
az keyvault secret show \
  --vault-name kv-aztek-* \
  --name postgres-admin-password \
  --query value

# If incorrect, update:
az keyvault secret set \
  --vault-name kv-aztek-* \
  --name postgres-admin-password \
  --value "YourNewComplexPassword123!"

# Restart app
az webapp restart --resource-group rg-aztek-weather-neu --name web-aztek-weather-neu-*
```

### Issue 3: Key Vault Access Denied

**Symptoms:**
- App logs show "Vault access is forbidden"
- Environment variables show empty values
- App fails to start

**Diagnosis:**
```bash
# Check Managed Identity status
az webapp identity show \
  --resource-group rg-aztek-weather-neu \
  --name web-aztek-weather-neu-* \
  --query principalId

# Should return a GUID
# If null, Managed Identity is not enabled
```

**Solution:**
```bash
# Enable Managed Identity
az webapp identity assign \
  --resource-group rg-aztek-weather-neu \
  --name web-aztek-weather-neu-*

# Get principal ID
$PRINCIPAL_ID = (az webapp identity show --resource-group rg-aztek-weather-neu --name web-aztek-weather-neu-* --query principalId -o tsv)

# Grant Key Vault access
az keyvault set-policy \
  --name kv-aztek-* \
  --object-id $PRINCIPAL_ID \
  --secret-permissions get list

# Restart app
az webapp restart --resource-group rg-aztek-weather-neu --name web-aztek-weather-neu-*
```

### Issue 4: Terraform State Lock

**Symptoms:**
- Terraform commands fail with "state locked"
- Previous `terraform apply` was interrupted (Ctrl+C)

**Solution:**
```bash
# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>

# LOCK_ID is shown in error message

# If state is corrupted:
terraform state pull > backup.tfstate
terraform state push backup.tfstate  # Only if needed
```

### Issue 5: Application Not Starting

**Symptoms:**
- App Service shows "Application Error"
- Logs show "ModuleNotFoundError" or similar

**Diagnosis:**
```bash
# Check startup logs
az webapp log tail --resource-group rg-aztek-weather-neu --name web-aztek-weather-neu-*

# Look for:
# - Python version mismatch
# - Missing dependencies
# - Startup command errors
```

**Solution:**
```bash
# Verify startup command
az webapp config show \
  --resource-group rg-aztek-weather-neu \
  --name web-aztek-weather-neu-* \
  --query linuxFxVersion

# Should be: PYTHON|3.12

# Redeploy application
cd infra/terraform
terraform apply -target=null_resource.deploy_app

# Or manually:
cd app
az webapp up \
  --resource-group rg-aztek-weather-neu \
  --name web-aztek-weather-neu-* \
  --runtime "PYTHON:3.12"
```