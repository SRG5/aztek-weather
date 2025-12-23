resource "null_resource" "ensure_build_dir" {
  provisioner "local-exec" {
    interpreter = ["bash", "-lc"]
    command     = "mkdir -p ${path.module}/.build"
  }
}

data "archive_file" "app_zip" {
  depends_on  = [null_resource.ensure_build_dir]
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

resource "time_sleep" "wait_for_scm" {
  depends_on      = [azurerm_linux_web_app.web]
  create_duration = "90s"
}

resource "null_resource" "deploy_app" {
  triggers = {
    zip_sha = data.archive_file.app_zip.output_sha
  }

  depends_on = [time_sleep.wait_for_scm]

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

echo "Starting zip deploy..."
# חשוב: 504 לפעמים מגיע מה-CLI שמחכה יותר מדי. אז עושים async ואז פולינג.
az webapp deploy \
  -g "$RG" -n "$APP" \
  --type zip \
  --src-path "$ZIP" \
  --async true \
  --timeout 1800000

echo "Polling deployment status..."
for i in $(seq 1 180); do
  DEPLOY_ID="$(az webapp log deployment list -g "$RG" -n "$APP" --query "sort_by(@,&received_time)[-1].id" -o tsv 2>/dev/null || true)"
  if [ -n "$DEPLOY_ID" ]; then
    STATUS_TEXT="$(az webapp log deployment show -g "$RG" -n "$APP" --deployment-id "$DEPLOY_ID" --query "properties.statusText" -o tsv 2>/dev/null || true)"
    echo "Deployment: $DEPLOY_ID statusText=$STATUS_TEXT"
    if [ "$STATUS_TEXT" = "Success" ] || [ "$STATUS_TEXT" = "Successful" ]; then
      break
    fi
    if [ "$STATUS_TEXT" = "Failed" ]; then
      echo "Deployment failed. Details:"
      az webapp log deployment show -g "$RG" -n "$APP" --deployment-id "$DEPLOY_ID" -o jsonc || true
      exit 1
    fi
  fi
  sleep 5
done

echo "Running health check..."
for i in $(seq 1 60); do
  if curl -fsS "$URL/health" >/dev/null; then
    echo "Health check OK."
    exit 0
  fi
  sleep 5
done

echo "Deployed, but /health not responding."
exit 1
EOT
  }
}