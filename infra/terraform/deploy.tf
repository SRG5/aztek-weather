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
SCM="https://${azurerm_linux_web_app.web.name}.scm.azurewebsites.net"
for i in $(seq 1 60); do
  if curl -fsS "$SCM/api/settings" >/dev/null 2>&1; then
    echo "SCM is ready."
    break
  fi
  echo "Waiting for SCM... ($i/60)"
  sleep 5
done

echo "Starting zip deploy..."
az webapp deploy \
  -g "$RG" -n "$APP" \
  --type zip \
  --src-path "$ZIP" \
  --async true

echo "Deployment initiated (async). Waiting briefly..."
sleep 10

# Health check
echo "Running health check..."
for i in $(seq 1 60); do
  if curl -fsS "$URL/health" >/dev/null 2>&1; then
    echo "Health check OK."
    exit 0
  fi
  if [ $i -eq 1 ] || [ $((i % 10)) -eq 0 ]; then
    echo "Waiting for /health endpoint... ($i/60)"
  fi
  sleep 5
done

echo "Deployed, but /health not responding."
echo "Tip: check container logs / app logs if health endpoint depends on DB, env vars, etc."
exit 1
EOT
  }
}