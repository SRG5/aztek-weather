resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

locals {
  tags = {
    project = var.project
    env     = var.env
  }

  rg_name   = "rg-${var.project}-${var.location_short}"
  app_name  = "${var.project}-${var.location_short}-${random_string.suffix.result}"
  pg_name   = "pg-${var.project}-${var.location_short}-${random_string.suffix.result}"
  law_name  = "law-${var.project}-${var.location_short}-${random_string.suffix.result}"
  appi_name = "appi-${var.project}-${var.location_short}-${random_string.suffix.result}"

  database_url = "postgresql://${var.postgres_admin_user}:${var.postgres_admin_password}@${azurerm_postgresql_flexible_server.pg.fqdn}:5432/${azurerm_postgresql_flexible_server_database.db.name}?sslmode=require"
}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = local.law_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_application_insights" "appi" {
  name                = local.appi_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
  tags                = local.tags
}

resource "azurerm_service_plan" "plan" {
  name                = "asp-${local.app_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  worker_count        = var.app_service_worker_count
  tags                = local.tags
}

resource "azurerm_linux_web_app" "web" {
  name                = "web-${local.app_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  https_only                 = true
  client_affinity_enabled    = false

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on           = true
    http2_enabled       = true
    minimum_tls_version = "1.2"

    health_check_path = "/health"
    health_check_eviction_time_in_min = 5

    application_stack {
      python_version = var.python_version
    }

    # App Service expects gunicorn for Flask by default if app.py exists.
    # We'll set it explicitly to be deterministic.
    app_command_line = "gunicorn --bind=0.0.0.0 --timeout 600 app:app"
  }

  app_settings = {
    OPENWEATHER_API_KEY = var.openweather_api_key
    FLASK_SECRET_KEY    = var.flask_secret_key
    DATABASE_URL        = local.database_url

    # Oryx build during deployment (GitHub Actions / zip deploy)
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    WEBSITE_RUN_FROM_PACKAGE = "1"

    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.appi.connection_string
  }

  tags = local.tags
}

data "archive_file" "app_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../app"
  output_path = "/tmp/aztek-weather-app.zip"
}

resource "null_resource" "deploy_app" {
  # Redeploy only when the zip content changes
  triggers = {
    zip_sha = data.archive_file.app_zip.output_sha
  }

  depends_on = [azurerm_linux_web_app.web]

  provisioner "local-exec" {
    interpreter = ["bash", "-lc"]
    command = <<EOT
      az webapp deployment source config-zip \
        --resource-group ${azurerm_resource_group.rg.name} \
        --name ${azurerm_linux_web_app.web.name} \
        --src ${data.archive_file.app_zip.output_path}
    EOT
  }
}

resource "azurerm_postgresql_flexible_server" "pg" {
  name                = local.pg_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  version = var.postgres_version

  administrator_login    = var.postgres_admin_user
  administrator_password = var.postgres_admin_password

  sku_name   = var.postgres_sku_name
  storage_mb = var.postgres_storage_mb

  backup_retention_days        = var.postgres_backup_retention_days
  geo_redundant_backup_enabled = false

  public_network_access_enabled = true

  # Zone redundant HA for max availability (meets the "availability" requirement)
  dynamic "high_availability" {
    for_each = var.postgres_ha_enabled ? [1] : []
    content {
      mode = "SameZone"
    }
  }

  zone = var.postgres_ha_enabled ? var.postgres_primary_zone : null

  tags = local.tags

  lifecycle {
    # After a failover, zones can swap. Ignore to avoid perpetual diffs.
    ignore_changes = [
      zone
    ]
  }
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = var.postgres_db_name
  server_id = azurerm_postgresql_flexible_server.pg.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Allow Azure services (fast for exercise; NOT ideal for prod)
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Optional: allow your home IP (for psql debugging)
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_my_ip" {
  count            = var.allow_my_ip ? 1 : 0
  name             = "allow-my-ip"
  server_id        = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = var.my_ip
  end_ip_address   = var.my_ip
}