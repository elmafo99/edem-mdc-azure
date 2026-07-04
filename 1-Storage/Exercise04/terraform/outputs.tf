output "sql_server_fqdn" {
  description = "FQDN del servidor SQL (host para la cadena de conexión)"
  value       = azurerm_mssql_server.example.fully_qualified_domain_name
}

output "sql_server_name" {
  description = "Nombre del servidor SQL"
  value       = azurerm_mssql_server.example.name
}

output "sql_database_name" {
  description = "Nombre de la base de datos"
  value       = azurerm_mssql_database.example.name
}

output "resource_group_name" {
  description = "Nombre del resource group"
  value       = azurerm_resource_group.example.name
}
