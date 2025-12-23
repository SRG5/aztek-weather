# Azure Front Door for global distribution and WAF protection
resource "azurerm_cdn_frontdoor_profile" "fd" {
  name                = "fd-${local.app_name}"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = var.frontdoor_sku_name
  tags                = local.tags
}

# Endpoint for the Front Door
resource "azurerm_cdn_frontdoor_endpoint" "endpoint" {
  name                     = "fd-endpoint-${local.app_name}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
  tags                     = local.tags
}

# Origin group (backend pool)
resource "azurerm_cdn_frontdoor_origin_group" "og" {
  name                     = "web-app-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id

  health_probe {
    path                = "/health"
    protocol            = "Https"
    request_type        = "GET"
    interval_in_seconds = 100
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

# Origin (the App Service backend)
resource "azurerm_cdn_frontdoor_origin" "app_service" {
  name                          = "webapp-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.og.id
  
  enabled                        = true
  host_name                      = azurerm_linux_web_app.web.default_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_linux_web_app.web.default_hostname
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

# Route to connect endpoint to origin
resource "azurerm_cdn_frontdoor_route" "route" {
  name                          = "default-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.og.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.app_service.id]
  
  enabled                = true
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  cdn_frontdoor_custom_domain_ids = []
  link_to_default_domain          = true

  depends_on = [
    azurerm_cdn_frontdoor_origin.app_service,
    azurerm_cdn_frontdoor_origin_group.og
  ]
}
