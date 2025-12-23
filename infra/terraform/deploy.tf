resource "time_sleep" "wait_for_scm" {
  depends_on      = [azurerm_linux_web_app.web]
  create_duration = "90s"
}

data "archive_file" "app_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../app"
  output_path = "${path.module}/.build/aztek-weather-app.zip"

  excludes = [
    "**/.venv/**",
    "**/__pycache__/**",
    "**/*.pyc",
    "**/.git/**",
    "**/.terraform/**"
  ]
}

resource "null_resource" "ensure_build_dir" {
  provisioner "local-exec" {
    interpreter = ["bash", "-lc"]
    command     = "mkdir -p ${path.module}/.build"
  }
}

resource "null_resource" "deploy_app" {
  triggers = {
    zip_sha = data.archive_file.app_zip.output_sha
  }

  depends_on = [time_sleep.wait_for_scm, null_resource.ensure_build_dir]

  provisioner "local-exec" {
    interpreter = ["bash", "-lc"]
    command = <<EOT
set -euo pipefail

RG="${azurerm_resource_group.rg.name}"
APP="${azurerm_linux_web_app.web.name}"
ZIP="${data.archive_file.app_zip.output_path}"
URL="https://${azurerm_linux_web_app.web.default_hostname}"

echo "Waiting for SCM (Kudu) to be ready..."
SCM="https://$APP.scm.azurewebsites.net"
for i in $(seq 1 60); do
  code="$(curl -s -o /dev/null -w "%%{http_code}" -I "$SCM/")"
  if [ "$code" = "200" ] || [ "$code" = "401" ] || [ "$code" = "403" ]; then
    echo "SCM is ready (HTTP $code)."
    break
  fi
  echo "Waiting for SCM... ($i/60) (HTTP $code)"
  sleep 5
done

# Capture the deployment id BEFORE deploy (so we can detect the new one)
BEFORE_ID="$(az webapp log deployment list -g "$RG" -n "$APP" --query "sort_by(@,&received_time)[-1].id" -o tsv 2>/dev/null || true)"

echo "Starting zip deploy..."
az webapp deploy \
  -g "$RG" -n "$APP" \
  --type zip \
  --src-path "$ZIP" \
  --track-status \
  --async false \
  --timeout 1800000

# Capture the deployment id AFTER deploy (for logs if needed)
AFTER_ID="$(az webapp log deployment list -g "$RG" -n "$APP" --query "sort_by(@,&received_time)[-1].id" -o tsv 2>/dev/null || true)"

if [ -n "$AFTER_ID" ] && [ "$AFTER_ID" != "$BEFORE_ID" ]; then
  st="$(az webapp log deployment show -g "$RG" -n "$APP" --deployment-id "$AFTER_ID" --query "properties.status" -o tsv 2>/dev/null || true)"
  echo "Latest deployment id: $AFTER_ID (status=$st)"
  if [ "$st" = "3" ]; then
    echo "Deployment failed. Full deployment info:"
    az webapp log deployment show -g "$RG" -n "$APP" --deployment-id "$AFTER_ID" -o jsonc || true
    exit 1
  fi
fi

# Health check
echo "Running health check..."
for i in $(seq 1 60); do
  if curl -fsS "$URL/health" >/dev/null; then
    echo "Health check OK."
    exit 0
  fi
  sleep 5
done

echo "Deployed, but /health not responding."
echo "Tip: check container logs / app logs if health endpoint depends on DB, env vars, etc."
exit 1
EOT
  }
}