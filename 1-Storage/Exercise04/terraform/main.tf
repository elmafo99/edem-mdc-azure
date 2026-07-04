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

resource "random_id" "sqlserver_suffix" {
  byte_length = 4
}

resource "azurerm_mssql_server" "example" {
  name                         = "example-sqlserver-${random_id.sqlserver_suffix.hex}"
  resource_group_name          = azurerm_resource_group.example.name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.admin_login
  administrator_login_password = var.admin_password
}

resource "azurerm_mssql_database" "example" {
  name         = var.sql_database
  server_id    = azurerm_mssql_server.example.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = 2
  sku_name     = "Basic"

  tags = {
    foo = "bar"
  }


  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_mssql_firewall_rule" "allow_my_ip" {
    name             = "allow-my-ip"
    server_id        = azurerm_mssql_server.example.id
    start_ip_address = "217.130.116.130"
    end_ip_address   = "217.130.116.130"
}