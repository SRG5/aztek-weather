output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "web_app_name" {
  value = azurerm_linux_web_app.web.name
}

output "web_app_url" {
  value = "https://${azurerm_linux_web_app.web.default_hostname}"
}

output "frontdoor_endpoint_url" {
  value       = "https://${azurerm_cdn_frontdoor_endpoint.endpoint.host_name}"
  description = "Front Door endpoint URL (use this for accessing the application)"
}

output "frontdoor_profile_name" {
  value = azurerm_cdn_frontdoor_profile.fd.name
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.pg.fqdn
}

output "postgres_db" {
  value = azurerm_postgresql_flexible_server_database.db.name
}