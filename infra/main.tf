terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "f1026231-cba4-4be2-9b78-5d79bd09f5e9"
}

variable "prefix" {
  default = "olist"
}

variable "location" {
  default = "centralindia"
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-dev-rg"
  location = var.location
}

resource "azurerm_storage_account" "lake" {
  name                     = "olistlakechintan01"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
}

resource "azurerm_storage_container" "layers" {
  for_each             = toset(["bronze", "silver", "gold"])
  name                 = each.key
  storage_account_name = azurerm_storage_account.lake.name
}

data "azurerm_client_config" "current" {}

# Key Vault (secrets)
resource "azurerm_key_vault" "kv" {
  name                       = "olist-kv-chintan01"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  access_policy {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    object_id          = data.azurerm_client_config.current.object_id
    secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
  }
}

# Azure Data Factory
resource "azurerm_data_factory" "adf" {
  name                = "olist-adf-chintan01"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  identity {
    type = "SystemAssigned"
  }
}

# Let ADF read/write the data lake
resource "azurerm_role_assignment" "adf_lake" {
  scope                = azurerm_storage_account.lake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.adf.identity[0].principal_id
}

# Databricks workspace
resource "azurerm_databricks_workspace" "dbx" {
  name                = "olist-dbx-dev"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "premium"
}

variable "sql_admin_password" {
  type      = string
  sensitive = true
}

resource "azurerm_mssql_server" "sql" {
  name                         = "olist-sql-chintan01"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.sql_admin_password
}

resource "azurerm_mssql_database" "db" {
  name                        = "olist-db"
  server_id                   = azurerm_mssql_server.sql.id
  sku_name                    = "GP_S_Gen5_1"
  min_capacity                = 0.5
  auto_pause_delay_in_minutes = 60
  max_size_gb                 = 2
}

resource "azurerm_mssql_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "my_pc" {
  name             = "MyPC"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "103.240.169.171"
  end_ip_address   = "103.240.169.171"
}

resource "azurerm_key_vault_access_policy" "me" {
  key_vault_id       = azurerm_key_vault.kv.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
}

resource "azurerm_key_vault_access_policy" "adf" {
  key_vault_id       = azurerm_key_vault.kv.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_data_factory.adf.identity[0].principal_id
  secret_permissions = ["Get", "List"]
}