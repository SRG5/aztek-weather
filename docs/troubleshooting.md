## Troubleshooting

### 1) Front Door shows 404 / “origin not found” (right after deploy)

**Symptoms**
- Front Door URL fails but the App Service URL works

**What to do**
- Give Front Door some time to propagate globally.
- Verify the Web App is healthy:

```bash
cd infra/terraform
curl -fsS "$(terraform output -raw web_app_url)/health" && echo "web app OK"
```

If you want to inspect Front Door resources:
```bash
RG=$(terraform output -raw resource_group)
az afd profile list -g "$RG" -o table
az afd endpoint list -g "$RG" --profile-name "$(az afd profile list -g "$RG" --query "[0].name" -o tsv)" -o table
```

---

### 2) Saving forecasts fails (DB connectivity)

**Symptoms**
- “Failed to save forecast to the database” in the UI
- `/saved` redirects back with an error

**Checks**
1) Verify `DATABASE_URL` is set in the Web App settings (Terraform sets it automatically):
```bash
RG=$(terraform output -raw resource_group)
APP=$(terraform output -raw web_app_name)
az webapp config appsettings list -g "$RG" -n "$APP" --query "[?name=='DATABASE_URL'].value" -o tsv
```

2) Verify PostgreSQL server is ready:
```bash
RG=$(terraform output -raw resource_group)
PG=$(az postgres flexible-server list -g "$RG" --query "[0].name" -o tsv)
az postgres flexible-server show -g "$RG" -n "$PG" --query "state" -o tsv
```

3) Firewall rules: ensure Azure services access is allowed (Terraform creates it):
```bash
az postgres flexible-server firewall-rule list -g "$RG" -n "$PG" -o table
```

---

### 3) Key Vault “access denied” / secrets not resolving

**Symptoms**
- App fails to start or env vars using Key Vault references are empty

**Checks**
- Confirm Managed Identity is enabled:
```bash
RG=$(terraform output -raw resource_group)
APP=$(terraform output -raw web_app_name)
az webapp identity show -g "$RG" -n "$APP" --query "principalId" -o tsv
```

- Confirm Key Vault policy exists for the Web App identity (Terraform sets it):
```bash
KV=$(az keyvault list -g "$RG" --query "[0].name" -o tsv)
az keyvault show -g "$RG" -n "$KV" --query "properties.accessPolicies" -o jsonc
```

---

### 4) Deployment succeeded but app doesn’t respond

**Steps**
1) Stream logs:
```bash
az webapp log tail -g "$RG" -n "$APP"
```

2) Confirm runtime:
```bash
az webapp config show -g "$RG" -n "$APP" --query "linuxFxVersion" -o tsv
```

3) Redeploy app:
```bash
cd infra/terraform
terraform apply -target=null_resource.deploy_app
```

---

### 5) Terraform state lock

If a previous run was interrupted and Terraform is locked:
```bash
terraform force-unlock <LOCK_ID>
```

`<LOCK_ID>` appears in the error message.