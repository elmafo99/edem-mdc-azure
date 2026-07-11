output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  value = azurerm_container_registry.acr.admin_username
}

output "acr_admin_password" {
  value     = azurerm_container_registry.acr.admin_password
  sensitive = true
}

output "eventhub_connection_string" {
  value     = azurerm_eventhub_authorization_rule.evh_rule.primary_connection_string
  sensitive = true
}

output "eventhub_namespace_name" {
  value = azurerm_eventhub_namespace.evhns.name
}

output "eventhub_name" {
  value = azurerm_eventhub.evh.name
}

output "cosmosdb_connection_string" {
  value     = azurerm_cosmosdb_account.cosmos.connection_strings[0]
  sensitive = true
}

output "cosmosdb_account_name" {
  value = azurerm_cosmosdb_account.cosmos.name
}

output "container_app_environment_id" {
  value = azurerm_container_app_environment.cae.id
}

output "producer_container_app_name" {
  value = azurerm_container_app.producer.name
}

output "processor_container_app_name" {
  value = azurerm_container_app.processor.name
}

output "api_url" {
  value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}

output "dashboard_url" {
  value = "https://${azurerm_container_app.dashboard.ingress[0].fqdn}"
}
