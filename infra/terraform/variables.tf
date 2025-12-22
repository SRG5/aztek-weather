variable "subscription_id" {
  type        = string
  description = "d2cc2668-766e-4287-b55c-757156c5d652"
}

variable "project" {
  type    = string
  default = "aztek-weather"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "northeurope"
}

variable "location_short" {
  type    = string
  default = "neu"
}

variable "python_version" {
  type    = string
  default = "3.12"
}

variable "app_service_sku" {
  type    = string
  default = "S1"
}

variable "app_service_worker_count" {
  type    = number
  default = 2
}

# App secrets (pass as TF_VAR_* - don't commit)
variable "openweather_api_key" {
  type      = string
  sensitive = true
}

variable "flask_secret_key" {
  type      = string
  sensitive = true
}

# Postgres
variable "postgres_version" {
  type    = string
  default = "16"
}

variable "postgres_admin_user" {
  type    = string
  default = "pgadmin"
}

variable "postgres_admin_password" {
  type      = string
  sensitive = true
}

variable "postgres_db_name" {
  type    = string
  default = "weatherdb"
}

variable "postgres_sku_name" {
  type    = string
  default = "GP_Standard_D2s_v3"
}

variable "postgres_storage_mb" {
  type    = number
  default = 32768
}

variable "postgres_backup_retention_days" {
  type    = number
  default = 7
}

variable "postgres_ha_enabled" {
  type    = bool
  default = true
}

variable "postgres_primary_zone" {
  type    = string
  default = "1"
}

variable "postgres_standby_zone" {
  type    = string
  default = "2"
}

# optional: allow your IP for debugging (psql from home)
variable "allow_my_ip" {
  type    = bool
  default = false
}

variable "my_ip" {
  type    = string
  default = ""
}