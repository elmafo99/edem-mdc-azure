terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.6.0"
    }
  }
}

provider "azurerm" {
  subscription_id                 = var.subscription_id
  features {}
  resource_provider_registrations = "none"
}

resource "azurerm_resource_group" "example" {
  name     = var.resource_group
  location = var.location
}

resource "random_id" "pgserver_suffix" {
  byte_length = 4
}

resource "azurerm_postgresql_flexible_server" "example" {
  name                = "example-pgserver-${random_id.pgserver_suffix.hex}"
  resource_group_name = azurerm_resource_group.example.name
  location            = var.location

  version = "16"

  administrator_login    = var.admin_login
  administrator_password = var.admin_password

  storage_mb = 32768
  sku_name   = "B_Standard_B1ms"

  zone = "1"

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_postgresql_flexible_server_database" "example" {
  name      = var.pg_database
  server_id = azurerm_postgresql_flexible_server.example.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_my_ip" {
  name             = "allow-my-ip"
  server_id        = azurerm_postgresql_flexible_server.example.id
  start_ip_address = "217.130.116.130"
  end_ip_address   = "217.130.116.130"
}
