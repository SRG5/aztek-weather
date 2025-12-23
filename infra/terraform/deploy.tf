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

# Publishing creds for querying Kudu API
PUBLISH_USER="$(az webapp deployment list-publishing-credentials -g "$RG" -n "$APP" --query publishingUserName -o tsv)"
PUBLISH_PASS="$(az webapp deployment list-publishing-credentials -g "$RG" -n "$APP" --query publishingPassword -o tsv)"

# Capture the deployment id BEFORE deploy (best effort)
BEFORE_ID="$(az webapp log deployment list -g "$RG" -n "$APP" --query "sort_by(@,&received_time)[-1].id" -o tsv 2>/dev/null || true)"

echo "Starting zip deploy..."
set +e
DEPLOY_OUT="$(az webapp deploy \
  -g "$RG" -n "$APP" \
  --type zip \
  --src-path "$ZIP" \
  --async false \
  --timeout 1800000 2>&1)"
RC=$?
set -e

echo "$DEPLOY_OUT"

if [ $RC -ne 0 ]; then
  if echo "$DEPLOY_OUT" | grep -q "Status Code: 504"; then
    echo "WARNING: Got 504 from CLI/Kudu gateway. Deployment may still be running. Will poll Kudu..."
  else
    echo "ERROR: az webapp deploy failed (rc=$RC)"
    exit $RC
  fi
fi

echo "Polling Kudu deployment status..."
# status: 0=pending,1=building,2=deploying,3=failed,4=success
for i in $(seq 1 120); do
  resp="$(curl -sS -u "$PUBLISH_USER:$PUBLISH_PASS" "$SCM/api/deployments/latest" || true)"
  status="$(python3 - <<'PY'
import json,sys
try:
    d=json.loads(sys.stdin.read() or "{}")
    print(d.get("status",""))
except Exception:
    print("")
PY
<<< "$resp")"

  msg="$(python3 - <<'PY'
import json,sys
try:
    d=json.loads(sys.stdin.read() or "{}")
    print(d.get("status_text","") or d.get("message","") or "")
except Exception:
    print("")
PY
<<< "$resp")"

  if [ -n "$status" ]; then
    echo "Kudu status=$status $msg"
  else
    echo "Kudu status unreadable (try $i/120) ..."
  fi

  if [ "$status" = "4" ]; then
    echo "Deployment succeeded."
    break
  fi

  if [ "$status" = "3" ]; then
    echo "Deployment failed. Latest deployment payload:"
    echo "$resp"
    echo "Tip: open $SCM/api/deployments/latest (with publishing creds) or use:"
    echo "  az webapp log tail -g $RG -n $APP"
    exit 1
  fi

  sleep 5
done

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
exit 1
EOT
  }
}