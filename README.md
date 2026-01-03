# 🚀 Infraestrutura Synapse + Data Lake + Airflow/Airbyte

Infraestrutura como código (IaC) para provisionar um ambiente completo de Data Lake no Azure com Synapse Analytics, incluindo Service Principal para integração com Airflow/Airbyte.

## 📋 Pré-requisitos

- **Terraform** >= 1.0
- **Azure CLI** instalado e autenticado
- Permissões no Azure para:
  - Criar recursos no Resource Group "Data"
  - Criar Service Principals no Azure AD
  - Atribuir roles (RBAC)

## 🏗️ Arquitetura

```text
┌─────────────────────────────────────────────────────────┐
│                  Azure Data Platform                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐        ┌─────────────────┐          │
│  │   Airflow    │───────▶│ Service         │          │
│  │   Airbyte    │        │ Principal       │          │
│  └──────────────┘        └────────┬────────┘          │
│                                   │                    │
│                                   ▼                    │
│         ┌─────────────────────────────────┐            │
│         │    Synapse Workspace            │            │
│         │  ┌──────────────────────────┐   │            │
│         │  │   Spark Pool (3.4)       │   │            │
│         │  │   - MemoryOptimized      │   │            │
│         │  │   - Auto Scale (3 nodes) │   │            │
│         │  └──────────────────────────┘   │            │
│         └─────────────────────────────────┘            │
│                      │                                 │
│                      ▼                                 │
│         ┌─────────────────────────────────┐            │
│         │  Storage Account (ADLS Gen2)    │            │
│         │  ┌─────────┬─────────┬────────┐ │            │
│         │  │Transient│ Bronze  │ Silver │ │            │
│         │  ├─────────┼─────────┼────────┤ │            │
│         │  │  Gold   │ Archive │Synapse │ │            │
│         │  └─────────┴─────────┴────────┘ │            │
│         └─────────────────────────────────┘            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 🛠️ Recursos Criados

- ✅ **Azure Synapse Workspace**
  - Spark Pool configurado com Delta Lake
  - Firewall rules configuradas
  
- ✅ **Storage Account (ADLS Gen2)** com containers:
  - `transient` - Dados temporários
  - `bronze` - Raw data
  - `silver` - Cleaned data
  - `gold` - Aggregated data
  - `archive` - Historical data
  - `synapse` - Workspace files

- ✅ **Service Principal** para Airflow/Airbyte
  - Permissões RBAC no Synapse
  - Permissões de leitura/escrita no Storage
  - Credenciais automaticamente geradas

- ✅ **Role Assignments** configuradas automaticamente

## 🚀 Como Usar

### 1. Clonar o repositório

```bash
git clone <seu-repo>
cd infra
```

### 2. Configurar variáveis

Crie um arquivo `terraform.tfvars`:

```hcl
subscription_id        = "sua subscription"
synapse_admin_login    = "sqladmin"
synapse_admin_password = "SuaSenhaSegura123!"
```

⚠️ **IMPORTANTE**: Adicione `terraform.tfvars` ao `.gitignore`

### 3. Autenticar no Azure

```bash
az login
```

### 4. Executar o Terraform

```bash
# Inicializar
terraform init

# Ver o plano de execução
terraform plan

# Aplicar as mudanças
terraform apply
```

### 5. Obter as credenciais

```bash
# Ver todas as informações
terraform output setup_instructions

# Obter apenas o client secret (sensível)
terraform output -raw airflow_client_secret

# Obter credenciais em JSON
terraform output -json credentials_json
```

## 🔧 Configuração no Airflow

### Opção 1: Via UI do Airflow

1. Acesse o Airflow UI
2. Vá em **Admin** → **Connections**
3. Clique em **+** para adicionar uma nova conexão
4. Configure:
   - **Connection Id**: `azure_synapse_default`
   - **Connection Type**: `Azure Synapse`
   - **Client ID**: (obter do output)
   - **Client Secret**: `terraform output -raw airflow_client_secret`
   - **Tenant ID**: (obter do output)
   - **Subscription ID**: (obter do output)

### Opção 2: Via variáveis de ambiente

```bash
export AZURE_CLIENT_ID="<client_id_do_output>"
export AZURE_CLIENT_SECRET="$(terraform output -raw airflow_client_secret)"
export AZURE_TENANT_ID="<tenant_id_do_output>"
export AZURE_SUBSCRIPTION_ID="<subscription_id_do_output>"
```

## 🔧 Configuração no Airbyte

1. Crie uma nova **Source** ou **Destination** do tipo:
   - Azure Blob Storage
   - Azure Data Lake Gen2

2. Configure:
   - **Account Name**: `lablicitacoessa`
   - **Authentication**: Service Principal
   - **Client ID**: (obter do output)
   - **Client Secret**: `terraform output -raw airflow_client_secret`
   - **Tenant ID**: (obter do output)
   - **Container**: `transient`, `bronze`, `silver`, `gold`, ou `archive`

## 📦 Estrutura do Projeto

```
.
├── main.tf              # Recursos principais
├── variables.tf         # Definição de variáveis
├── outputs.tf           # Outputs e credenciais
├── terraform.tfvars     # Valores das variáveis (NÃO COMMITAR)
├── .gitignore          # Arquivos a ignorar
└── README.md           # Esta documentação
```

## 🔐 Segurança

- ✅ Service Principal com princípio do menor privilégio
- ✅ Client Secret com data de expiração definida
- ✅ Outputs sensíveis marcados como `sensitive = true`
- ⚠️ **NUNCA** commite `terraform.tfvars` ou arquivos `.tfstate` no git
- ⚠️ Firewall configurado para permitir todos IPs (ajuste para produção)

## 🧹 Limpeza

Para destruir toda a infraestrutura:

```bash
terraform destroy
```

⚠️ **CUIDADO**: Isso vai deletar TODOS os recursos criados, incluindo dados!

## 📝 Variáveis Disponíveis

| Variável | Descrição | Padrão | Obrigatório |
|----------|-----------|--------|-------------|
| `synapse_admin_login` | Username do admin SQL | `sqladmin` | Não |
| `synapse_admin_password` | Password do admin SQL | - | Sim |

## 🔄 Atualizações

Para atualizar a infraestrutura após mudanças no código:

```bash
terraform plan   # Ver mudanças
terraform apply  # Aplicar mudanças
```

## 🐛 Troubleshooting

### Erro: "ClientIpAddressNotAuthorized"

**Solução**: O firewall do Synapse está bloqueando seu IP. Execute via portal ou ajuste as regras de firewall.

### Erro: "resource already exists"

**Solução**: Importe o recurso existente:
```bash
terraform import <resource_type>.<name> <azure_resource_id>
```

### Erro: Permissões insuficientes

**Solução**: Verifique se você tem permissões para:
- Criar Service Principals
- Atribuir roles RBAC
- Criar recursos no Resource Group

## 📞 Suporte

Para issues e sugestões, abra uma issue no GitHub.

## 📄 Licença

MIT License