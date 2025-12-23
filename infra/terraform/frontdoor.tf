# Azure Front Door (Standard) in front of the Web App

resource "azurerm_cdn_frontdoor_profile" "afd" {
  name                = "afd-${local.app_name}"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = local.tags
}

# Endpoint name must be globally unique -> use the random suffix in local.app_name
resource "azurerm_cdn_frontdoor_endpoint" "afd_ep" {
  name                     = "fd-${local.app_name}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
  enabled                  = true
  tags                     = local.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "og" {
  name                     = "og-${local.app_name}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required         = 3
  }

  health_probe {
    interval_in_seconds = 30
    path                = "/health"
    protocol            = "Https"
    request_type        = "GET"
  }
}

resource "azurerm_cdn_frontdoor_origin" "origin_webapp" {
  name                          = "origin-webapp"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.og.id

  enabled                        = true
  host_name                      = azurerm_linux_web_app.web.default_hostname
  origin_host_header             = azurerm_linux_web_app.web.default_hostname
  http_port                      = 80
  https_port                     = 443
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "route_all" {
  name                          = "route-main"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.afd_ep.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.og.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.origin_webapp.id]

  enabled                = true
  link_to_default_domain = true

  cdn_frontdoor_custom_domain_ids = []

  patterns_to_match   = ["/*"]
  supported_protocols = ["Https"]
  forwarding_protocol = "HttpsOnly"

  lifecycle {
    create_before_destroy = true
  }
}

