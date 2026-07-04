output "pg_server_fqdn" {
  description = "FQDN del servidor PostgreSQL (host para la cadena de conexión)"
  value       = azurerm_postgresql_flexible_server.example.fqdn
}

output "pg_server_name" {
  description = "Nombre del servidor PostgreSQL"
  value       = azurerm_postgresql_flexible_server.example.name
}

output "pg_database_name" {
  description = "Nombre de la base de datos"
  value       = azurerm_postgresql_flexible_server_database.example.name
}

output "resource_group_name" {
  description = "Nombre del resource group"
  value       = azurerm_resource_group.example.name
}
