variable "subscription_id" {
    type = string
    description = "Nombre de la suscripción"
}


variable "location" {
    type = string
    description = "localización del proyecto (Central Sweden)"
}

variable "resource_group" {
    type = string
    description = "Nombre del grupo de recursos"
}

variable "sql_database" {
    type = string
    description = "Nombre de la base de datos en SQL"
}

variable "admin_login" {
    type = string
    description = "Nombre del admin"
    sensitive = true
}

variable "admin_password" {
    type = string
    description = "Contraseña del admin"
    sensitive = true
}