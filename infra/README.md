# 🏗️ Infraestrutura - Azure Synapse + Data Lake

> ⬆️ [Voltar para documentação principal](../README.md)

Provisionamento automatizado da infraestrutura Azure usando Terraform.

## 📦 O que é provisionado

- ✅ Azure Synapse Workspace com Spark Pool
- ✅ Azure Data Lake Storage Gen2 (6 containers)
- ✅ Service Principal para Airflow/Airbyte
- ✅ Firewall rules e permissões RBAC
- ✅ Role assignments automatizados

## 🚀 Quick Start

### 1. Pré-requisitos

```bash
# Verificar instalações
terraform version  # >= 1.0
az --version       # Azure CLI

# Autenticar
az login
```

### 2. Configurar variáveis

```bash
# Copiar template
cp terraform.tfvars.example terraform.tfvars

# Editar com suas configurações
nano terraform.tfvars
```

### 3. Criar Service Principal

O Service Principal precisa ser criado manualmente uma vez:

```bash
# Criar SP
az ad sp create-for-rbac \
  --name "airflow-synapse-access" \
  --role "Reader" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/Data" \
  --query "{clientId:appId, clientSecret:password, tenantId:tenant}" \
  -o json | tee sp_credentials.json

# Obter Object ID
CLIENT_ID=$(cat sp_credentials.json | jq -r '.clientId')
az ad sp show --id "$CLIENT_ID" --query id -o tsv
```

⚠️ **IMPORTANTE**: 
- Salve `sp_credentials.json` em local seguro
- Adicione o Object ID no `terraform.tfvars`

### 4. Provisionar

```bash
# Inicializar Terraform
terraform init

# Ver plano de execução
terraform plan

# Aplicar (vai pedir confirmação)
terraform apply

# Ou aplicar sem confirmação
terraform apply -auto-approve
```

### 5. Obter credenciais

```bash
# Ver instruções de setup
terraform output setup_instructions

# Ver credenciais em JSON
terraform output -json credentials_json

# Salvar para usar no Airflow/Airbyte
terraform output -json credentials_json > ../credentials.json
```

## 🏗️ Arquitetura Provisionada

```
Resource Group: Data
│
├── Synapse Workspace: lablicitacoes-gov-sw
│   ├── Spark Pool: sparkpool1 (3.4)
│   │   ├── Node Size: Small (MemoryOptimized)
│   │   ├── Auto Scale: 3-3 nodes
│   │   └── Auto Pause: 15 min
│   └── Firewall: Allow All (0.0.0.0 - 255.255.255.255)
│
└── Storage Account: lablicitacoessa (ADLS Gen2)
    ├── 📁 transient    (staging)
    ├── 📁 bronze       (raw data)
    ├── 📁 silver       (cleaned data)
    ├── 📁 gold         (aggregated data)
    ├── 📁 archive      (historical)
    └── 📁 synapsefs    (workspace files)
```

## 🔐 Permissões Configuradas

### Service Principal (Airflow/Airbyte)
- ✅ Synapse Administrator (Synapse RBAC)
- ✅ Storage Blob Data Contributor (todos os containers)
- ✅ Contributor (Synapse Workspace - Azure RBAC)

### Synapse Workspace (Managed Identity)
- ✅ Storage Blob Data Owner (storage account)
- ✅ Storage Blob Data Contributor (todos os containers)

### Usuário atual (quem roda o Terraform)
- ✅ Storage Blob Data Contributor (storage account)

## 📁 Estrutura de Arquivos

```
infra/
├── main.tf           # Recursos principais
├── variables.tf      # Definições de variáveis
├── outputs.tf        # Outputs (credenciais, IDs, URLs)
├── terraform.tfvars  # Valores das variáveis (NÃO COMMITAR)
├── .gitignore        # Arquivos a ignorar
└── README.md         # Esta documentação
```

## 🔄 Atualizações

Para atualizar recursos após mudanças no código:

```bash
terraform plan   # Ver mudanças
terraform apply  # Aplicar mudanças
```

Para atualizar um recurso específico:

```bash
terraform apply -target=azurerm_synapse_spark_pool.spark_pool
```

## 🧹 Destruir Infraestrutura

⚠️ **CUIDADO**: Isso vai deletar TODOS os recursos e DADOS!

```bash
# Ver o que será destruído
terraform plan -destroy

# Destruir tudo
terraform destroy

# Ou forçar sem confirmação (cuidado!)
terraform destroy -auto-approve
```

## 📚 Recursos Adicionais

- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Synapse Documentation](https://docs.microsoft.com/azure/synapse-analytics/)
- [ADLS Gen2 Best Practices](https://docs.microsoft.com/azure/storage/blobs/data-lake-storage-best-practices)

---


<div align="center">
  <p>Infraestrutura gerenciada com Terraform 🚀</p>
</div>