output "resource_group_name" {
    description = "O nome do Resource Group criado"
    value       = data.azurerm_resource_group.data_rg.name
}

output "storage_account_name" {
    description = "O nome da Storage Account criada"
    value       = azurerm_storage_account.lab_licitacoes_sa.name
}

output "airflow_service_principal_tenant_id" {
  description = "Tenant ID para configurar no Airflow"
  value       = data.azurerm_client_config.current.tenant_id
}

output "synapse_workspace_name" {
  description = "Nome do Synapse Workspace"
  value       = azurerm_synapse_workspace.synapse_workspace.name
}

output "synapse_workspace_id" {
  description = "ID do Synapse Workspace"
  value       = azurerm_synapse_workspace.synapse_workspace.id
}

output "airflow_credentials" {
  description = "Credenciais do Service Principal (criado manualmente)"
  value = <<-EOF
  
  ╔════════════════════════════════════════════════╗
  ║   CREDENCIAIS AIRFLOW/AIRBYTE                  ║
  ╚════════════════════════════════════════════════╝
  
  ⚠️  Service Principal criado manualmente.
      Use as credenciais salvas em sp_credentials.json

  Object ID:     ${var.object_id}
  Tenant ID:     ${data.azurerm_client_config.current.tenant_id}
  Subscription:  ${data.azurerm_client_config.current.subscription_id}
  
  Client ID e Secret: veja sp_credentials.json
  
  EOF
}