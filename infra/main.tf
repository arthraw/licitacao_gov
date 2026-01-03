data "azurerm_resource_group" "data_rg" {
  name     = "Data"
}
data "azurerm_client_config" "current" {}

// Storage Account for Data Lake Gen2
resource "azurerm_storage_account" "lab_licitacoes_sa" {
  name                     = "lablicitacoessa"
  resource_group_name      = data.azurerm_resource_group.data_rg.name
  location                 = data.azurerm_resource_group.data_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
  public_network_access_enabled = true
  
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  
  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }
  
  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
  
  tags = {
    environment = "production"
    project     = "licitacoes"
    group       = "Data"
  }
}

// Data lake Gen2 Filesystems (Layers)
resource "azurerm_storage_data_lake_gen2_filesystem" "transient" {
  name               = "transient"
  storage_account_id = azurerm_storage_account.lab_licitacoes_sa.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "bronze" {
  name               = "bronze"
  storage_account_id = azurerm_storage_account.lab_licitacoes_sa.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "gold" {
  name               = "gold"
  storage_account_id = azurerm_storage_account.lab_licitacoes_sa.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "silver" {
  name               = "silver"
  storage_account_id = azurerm_storage_account.lab_licitacoes_sa.id
}

// Container for Synapse Workspace
resource "azurerm_storage_data_lake_gen2_filesystem" "synapse" {
  name               = "synapsefs"
  storage_account_id = azurerm_storage_account.lab_licitacoes_sa.id
}

// Container for Archive raw data
resource "azurerm_storage_data_lake_gen2_filesystem" "archive" {
  name               = "archive"
  storage_account_id = azurerm_storage_account.lab_licitacoes_sa.id
}

// Synapse Workspace configuration
resource "azurerm_synapse_workspace" "synapse_workspace" {
  name                                 = "lablicitacoes-gov-sw"
  resource_group_name                  = data.azurerm_resource_group.data_rg.name
  location                             = data.azurerm_resource_group.data_rg.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.synapse.id
  sql_administrator_login              = var.synapse_admin_login
  sql_administrator_login_password     = var.synapse_admin_password
  public_network_access_enabled = true
  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = "production"
  }
}

// Role assignment to allow current user full access to the Storage Account
resource "azurerm_role_assignment" "current_user_storage_access" {
  scope                = azurerm_storage_account.lab_licitacoes_sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

// Role assignment to allow Synapse Workspace access to the Storage Account
resource "azurerm_role_assignment" "synapse_storage_access" {
  scope                = azurerm_storage_account.lab_licitacoes_sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.synapse_workspace.identity[0].principal_id
  
  depends_on = [
    azurerm_synapse_workspace.synapse_workspace,
    azurerm_storage_account.lab_licitacoes_sa
  ]
}

// Role assignment (Owner) to Synapse Workspace
resource "azurerm_role_assignment" "synapse_storage_owner" {
  scope                = azurerm_storage_account.lab_licitacoes_sa.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_synapse_workspace.synapse_workspace.identity[0].principal_id
  
  depends_on = [
    azurerm_synapse_workspace.synapse_workspace,
    azurerm_role_assignment.synapse_storage_access
  ]
}

// Role assignments to allow Synapse Workspace access to each Data Lake layer
resource "azurerm_role_assignment" "synapse_bronze_access" {
  scope                = "${azurerm_storage_account.lab_licitacoes_sa.id}/blobServices/default/containers/bronze"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.synapse_workspace.identity[0].principal_id
  
  depends_on = [
    azurerm_storage_data_lake_gen2_filesystem.bronze
  ]
}

resource "azurerm_role_assignment" "synapse_silver_access" {
  scope                = "${azurerm_storage_account.lab_licitacoes_sa.id}/blobServices/default/containers/silver"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.synapse_workspace.identity[0].principal_id
  
  depends_on = [
    azurerm_storage_data_lake_gen2_filesystem.silver
  ]
}

resource "azurerm_role_assignment" "synapse_gold_access" {
  scope                = "${azurerm_storage_account.lab_licitacoes_sa.id}/blobServices/default/containers/gold"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.synapse_workspace.identity[0].principal_id
  
  depends_on = [
    azurerm_storage_data_lake_gen2_filesystem.gold
  ]
}

resource "azurerm_role_assignment" "synapse_transient_access" {
  scope                = "${azurerm_storage_account.lab_licitacoes_sa.id}/blobServices/default/containers/transient"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.synapse_workspace.identity[0].principal_id
  
  depends_on = [
    azurerm_storage_data_lake_gen2_filesystem.transient
  ]
}

resource "azurerm_role_assignment" "synapse_archive_access" {
  scope                = "${azurerm_storage_account.lab_licitacoes_sa.id}/blobServices/default/containers/archive"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.synapse_workspace.identity[0].principal_id
  
  depends_on = [
    azurerm_storage_data_lake_gen2_filesystem.archive
  ]
}

resource "azurerm_role_assignment" "airflow_storage_access" {
  scope                = azurerm_storage_account.lab_licitacoes_sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.object_id
}

resource "azurerm_role_assignment" "airflow_transient_access" {
  scope                = "${azurerm_storage_account.lab_licitacoes_sa.id}/blobServices/default/containers/transient"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.object_id

  depends_on = [
    azurerm_storage_data_lake_gen2_filesystem.transient
  ]
}

resource "azurerm_role_assignment" "airflow_bronze_access" {
  scope                = "${azurerm_storage_account.lab_licitacoes_sa.id}/blobServices/default/containers/bronze"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.object_id

  depends_on = [
    azurerm_storage_data_lake_gen2_filesystem.bronze
  ]
}

resource "azurerm_synapse_firewall_rule" "allow_all" {
  name                 = "AllowAll"
  synapse_workspace_id = azurerm_synapse_workspace.synapse_workspace.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "255.255.255.255"
}

# Airflow client RBAC access to workspace
resource "azurerm_synapse_role_assignment" "airflow_access" {
  synapse_workspace_id = azurerm_synapse_workspace.synapse_workspace.id
  role_name            = "Synapse Administrator"
  principal_id         = var.object_id

  depends_on = [
    azurerm_synapse_firewall_rule.allow_all
  ]
}

// Synapse Spark Pool configuration
resource "azurerm_synapse_spark_pool" "spark_pool" {
  name                 = "sparkpool1"
  synapse_workspace_id = azurerm_synapse_workspace.synapse_workspace.id
  node_size_family     = "MemoryOptimized"
  node_size            = "Small"
  cache_size           = 100

  auto_scale {
    max_node_count = 3
    min_node_count = 3
  }

  auto_pause {
    delay_in_minutes = 15
  }

  spark_version = "3.4" 

  spark_config {
    content  = <<EOF
spark.sql.extensions org.apache.spark.sql.delta.sql.DeltaSparkSessionExtension
spark.sql.catalog.spark_catalog org.apache.spark.sql.delta.catalog.DeltaCatalog
EOF
    filename = "config.txt"
  }

  tags = {
    environment = "Production"
  }
}