resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Sirve para generar un sufijo aleatorio para los recursos,
# evitando colisiones de nombres en Azure,
# ya que algunos recursos necesitan nombres únicos a nivel global 
# (como ACR, Event Hub, CosmosDB, etc.)
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

# Container Registry 
resource "azurerm_container_registry" "acr" {
  name                = "acr${var.project}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Event Hub Namespace + Event Hub 
resource "azurerm_eventhub_namespace" "evhns" {
  name                = "evhns-${var.project}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  capacity            = 1
}

resource "azurerm_eventhub" "evh" {
  name                = "evh-transactions"
  namespace_name      = azurerm_eventhub_namespace.evhns.name
  resource_group_name = azurerm_resource_group.rg.name
  partition_count     = 2
  message_retention   = 1
}

resource "azurerm_eventhub_authorization_rule" "evh_rule" {
  name                = "producer-consumer-rule"
  namespace_name      = azurerm_eventhub_namespace.evhns.name
  eventhub_name       = azurerm_eventhub.evh.name
  resource_group_name = azurerm_resource_group.rg.name
  listen              = true
  send                = true
  manage              = false
}

# Cosmos DB
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "cosmos-${var.project}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  offer_type          = "Standard"
  kind                = "MongoDB"

  capabilities {
    name = "EnableMongo"
  }

  capabilities {
    name = "EnableServerless"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_mongo_database" "db" {
  name                = "salesdb"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

resource "azurerm_cosmosdb_mongo_collection" "transactions" {
  name                = "transactions"
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_mongo_database.db.name

  index {
    keys   = ["_id"]
    unique = true
  }
}

# Container Apps Environment - entorno de ejecución para las aplicaciones de contenedor

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.project}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "cae" {
  name                       = "cae-${var.project}"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}

# Container App - Producer
# Publica transacciones simuladas en Event Hub de forma continua,
# por eso no expone ingress y se mantiene siempre con 1 réplica.
resource "azurerm_container_app" "producer" {
  name                         = "ca-producer-${var.project}"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "producer"
      image  = "${azurerm_container_registry.acr.login_server}/producer:v1"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "EVENTHUB_CONNECTION_STRING"
        secret_name = "eventhub-connection-string"
      }

      env {
        name  = "EVENTHUB_NAME"
        value = azurerm_eventhub.evh.name
      }
    }
  }

  secret {
    name  = "eventhub-connection-string"
    value = azurerm_eventhub_authorization_rule.evh_rule.primary_connection_string
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }

  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }
}

# Container App - API (FastAPI)
# Expone los datos de Cosmos DB por HTTP para que el dashboard no
# tenga que conectarse directamente a la base de datos.
resource "azurerm_container_app" "api" {
  name                         = "ca-api-${var.project}"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "api"
      image  = "${azurerm_container_registry.acr.login_server}/api:v1"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "COSMOSDB_CONNECTION_STRING"
        secret_name = "cosmosdb-connection-string"
      }

      env {
        name  = "COSMOSDB_DATABASE_NAME"
        value = azurerm_cosmosdb_mongo_database.db.name
      }

      env {
        name  = "COSMOSDB_COLLECTION_NAME"
        value = azurerm_cosmosdb_mongo_collection.transactions.name
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name  = "cosmosdb-connection-string"
    value = azurerm_cosmosdb_account.cosmos.connection_strings[0]
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }

  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }
}

# Container App - Dashboard (Streamlit)
# Lee los datos únicamente a través de la API, nunca directo de Cosmos DB.
resource "azurerm_container_app" "dashboard" {
  name                         = "ca-dashboard-${var.project}"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "dashboard"
      image  = "${azurerm_container_registry.acr.login_server}/dashboard:v1"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "API_BASE_URL"
        value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8501

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }

  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }
}

# Container App - Processor
# Consume del Event Hub, transforma los mensajes y los guarda en Cosmos DB.
# Al igual que el producer, es un proceso en bucle sin ingress.
resource "azurerm_container_app" "processor" {
  name                         = "ca-processor-${var.project}"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "processor"
      image  = "${azurerm_container_registry.acr.login_server}/processor:v1"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "EVENTHUB_CONNECTION_STRING"
        secret_name = "eventhub-connection-string"
      }

      env {
        name  = "EVENTHUB_NAME"
        value = azurerm_eventhub.evh.name
      }

      env {
        name        = "COSMOSDB_CONNECTION_STRING"
        secret_name = "cosmosdb-connection-string"
      }

      env {
        name  = "COSMOSDB_DATABASE_NAME"
        value = azurerm_cosmosdb_mongo_database.db.name
      }

      env {
        name  = "COSMOSDB_COLLECTION_NAME"
        value = azurerm_cosmosdb_mongo_collection.transactions.name
      }
    }
  }

  secret {
    name  = "eventhub-connection-string"
    value = azurerm_eventhub_authorization_rule.evh_rule.primary_connection_string
  }

  secret {
    name  = "cosmosdb-connection-string"
    value = azurerm_cosmosdb_account.cosmos.connection_strings[0]
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }

  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }
}

