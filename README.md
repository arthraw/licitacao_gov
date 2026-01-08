# 📊 Pipeline de Dados de Licitações Governamentais

Pipeline completo de ingestão, processamento e análise de dados de licitações do governo brasileiro, utilizando arquitetura moderna de Data Lake com camadas medallion (Bronze, Silver, Gold).

## 🎯 Objetivo do Projeto

Automatizar a coleta, processamento e disponibilização de dados públicos de licitações governamentais, permitindo análises e insights sobre processos licitatórios no Brasil.

## 🏗️ Arquitetura
```
┌─────────────────────────────────────────────────────────────┐
│                    PIPELINE DE DADOS                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐      ┌──────────────┐                     │
│  │   Airflow    │─────▶│   Airbyte    │                     │
│  │(Orquestração)│      │  (Ingestão)  │                     │
│  └──────────────┘      └──────┬───────┘                     │
│                               │                             │
│                               ▼                             │
│                    ┌─────────────────────┐                  │
│                    │  Azure Synapse      │                  │
│                    │  ┌───────────────┐  │                  │
│                    │  │  Spark Pool   │  │                  │
│                    │  │  (Processing) │  │                  │
│                    │  └───────────────┘  │                  │
│                    └──────────┬──────────┘                  │
│                               │                             │
│                               ▼                             │
│              ┌────────────────────────────────┐             │
│              │   ADLS Gen2 (Data Lake)        │             │
│              │                                │             │
│              │  📁 Transient (staging)        │             │
│              │  📁 Bronze (raw)               │             │
│              │  📁 Silver (cleaned)           │             │
│              │  📁 Gold (aggregated)          │             │
│              │  📁 Archive (historical)       │             │
│              └────────────────────────────────┘             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 🛠️ Stack Tecnológica

### Orquestração & Workflow
- **Apache Airflow** - Orquestração de pipelines e scheduling
- **Airbyte** - Plataforma de ingestão de dados (ELT)

### Processamento & Armazenamento
- **Azure Synapse Analytics** - Data warehouse e processamento distribuído
- **Apache Spark** (via Synapse) - Processamento big data
- **Delta Lake** - Camada de armazenamento ACID
- **Azure Data Lake Storage Gen2** - Data lake escalável

### Infraestrutura como Código
- **Terraform** - Provisionamento de infraestrutura na Azure
- **Azure CLI** - Automação e configuração

### Linguagens & Ferramentas
- **Python** - Scripts e transformações
- **PySpark** - Processamento distribuído de dados
- **SQL** - Queries e transformações

## 📁 Estrutura do Projeto

```
licitacao_gov/
│
├── airflow/                    # Configuração do Airflow
│   ├── dags/                   # DAGs de orquestração
│   │   └── licitacoes_dag.py  # Pipeline principal
│
├── airbyte/                    # Configuração do Airbyte
│   ├── sources/                # Definições de fontes de dados
│
├── src/                    # Fonte do código
│   ├── notebooks/              # Notebooks PySpark
│   │   ├── bronze_to_silver.ipynb
│   │   └── silver_to_gold.ipynb
│
├── infra/                      # Infraestrutura como Código
│   ├── main.tf                 # Recursos principais
│   ├── variables.tf            # Variáveis
│   ├── outputs.tf              # Outputs
│   └── README.md               # 📖 [Documentação de Infra](infra/README.md)
│
├── scripts/                    # Scripts auxiliares
│   ├── setup.sh                # Setup inicial
│   └── deploy.sh               # Deploy automatizado
│
├── docs/                       # Arquivos para doc
├── .gitignore
└── README.md                   # Este arquivo
```

## 🚀 Como Executar o Projeto

### Pré-requisitos

- **Azure Subscription** ativa
- **Terraform** >= 1.0
- **Azure CLI** autenticado
- **Docker** & **Docker Compose**
- **Python** >= 3.9

### 1️⃣ Provisionar Infraestrutura

```bash
cd infra/

# Configurar variáveis
cp terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com suas configurações

# Provisionar recursos Azure
terraform init
terraform plan
terraform apply

# Salvar credenciais do Service Principal
terraform output -raw airflow_client_secret > ../credentials.txt
```

📖 **Detalhes**: Veja [infra/README.md](infra/README.md) para documentação completa da infraestrutura.

### 2️⃣ Configurar Airflow

```bash
# Inicializar projeto Astro
astro dev init

# Subir o Airflow localmente
astro dev start

# Acessar UI
# http://localhost:8080
# Usuário: admin / Senha: admin

# Configurar conexão Azure Synapse, adls e airbyte

```

### 3️⃣ Configurar Airbyte

```bash
sudo abctl local install

# Acessar UI
# http://localhost:8000
# Usuário: airbyte / Senha: *pega utilizando o comando abaixo:*
sudo abctl local credentials
```

### Configurar source e destination

Crie uma nova source de API pela aba BUILDER na UI, e importe o yaml que esta em airbyte/sources/licitacoes_gov_br.yaml

Apos isso configure uma connection com a destination Azure Blob Storage


### 4️⃣ Executar Pipeline

**Via Airflow UI, ative e execute a DAG 'licitacoes_dag'**


## 📊 Camadas de Dados (Medallion Architecture)

### 🥉 Bronze (Raw)
- Dados brutos ingeridos sem transformação
- Formato: JSON/Parquet original
- Retenção: 90 dias

### 🥈 Silver (Cleaned)
- Dados limpos e normalizados
- Validações de qualidade aplicadas
- Formato: Delta Lake
- Retenção: 1 ano

### 🥇 Gold (Aggregated)
- Dados agregados e otimizados para análise
- KPIs e métricas de negócio
- Formato: Delta Lake / Tabela física
- Retenção: Indefinida

### 📦 Transient
- Área de staging temporária
- Dados intermediários durante processamento

### 🗄️ Archive
- Dados históricos arquivados
- Conformidade e auditoria
- Armazenamento de longo prazo

## 🔄 Fluxo de Dados

```
1. Ingestão (Airbyte)
   └─> API Licitações → Transient (JSON)

2. Raw Layer (Airflow → Synapse)
   └─> Transient → Bronze (Parquet)

3. Archive (Airflow)
   └─> Bronze → Archive (histórico)

4. Cleaned Layer (Synapse Spark)
   └─> Bronze → Silver (Delta Lake)
        ├─ Validação de schema
        ├─ Limpeza de dados
        ├─ Deduplicação
        └─ Normalização

5. Aggregated Layer (Synapse Spark)
   └─> Silver → Gold (Delta Lake)
        ├─ Agregações
        ├─ KPIs
        └─ Tabelas dimensionais

```

## 🔐 Segurança & Governança

- ✅ **Autenticação**: Service Principal com RBAC
- ✅ **Criptografia**: Em repouso (Storage) e em trânsito (TLS)
- ✅ **Auditoria**: Logs centralizados no Azure Monitor
- ✅ **Firewall**: Regras de rede configuradas
- ✅ **Secrets**: Gerenciados via Terraform (sensitive outputs)
- ✅ **LGPD/GDPR**: Dados anonimizados quando necessário

## 📈 Monitoramento

- **Airflow UI**: Status de DAGs e tasks
- **Azure Monitor**: Métricas de recursos
- **Synapse Studio**: Execução de pipelines e queries

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 👥 Autor

- **Arthur Andrade** - [GitHub](https://github.com/arthraw)

## 📚 Documentação Adicional

- 🏗️ **[Infraestrutura (Terraform)](infra/README.md)** - Setup completo da infraestrutura Azure

---

<div align="center">
  <p>Feito com ❤️ usando tecnologias open source e Azure</p>
  <p>⭐ Se este projeto foi útil, considere dar uma estrela!</p>
</div>