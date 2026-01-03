from airflow.sdk import dag, task
from airflow.providers.microsoft.azure.hooks.wasb import WasbHook
from airflow.providers.microsoft.azure.sensors.wasb import WasbPrefixSensor
from airflow.providers.microsoft.azure.operators.synapse import AzureSynapseRunPipelineOperator
from airflow.providers.airbyte.operators.airbyte import AirbyteTriggerSyncOperator
from airflow.providers.http.operators.http import HttpOperator
from datetime import datetime
from airflow.providers.microsoft.azure.hooks.data_lake import AzureDataLakeStorageV2Hook
from airflow.providers.standard.sensors.python import PythonSensor
from importlib_metadata import files

AIRBYTE_CONN_NAME = "airbyte_conn"
AIRBYTE_CONNECTION_ID = "863830d4-1ecb-45c3-b3b5-08e6be0cb366"
AZURE_DATA_LAKE_GEN2_CONN_ID = "azure_data_lake_v2"
AZURE_SYNAPSE_CONN_ID = "azure_synapse_workspace"
year = datetime.now().year

@dag(
    dag_id="licitacoes_dag",
    catchup=False,
    start_date=datetime(2025, 1, 1),
    schedule=None,
    tags=["licitacoes", "pipeline"],
)
def licitacoes_dag():
    
    ingest_data_from_api = AirbyteTriggerSyncOperator(
        task_id="ingest_licitacoes_data",
        airbyte_conn_id=AIRBYTE_CONN_NAME,
        connection_id=AIRBYTE_CONNECTION_ID 
    )

    def adls_files_exist():
        hook = AzureDataLakeStorageV2Hook(adls_conn_id=AZURE_DATA_LAKE_GEN2_CONN_ID)

        files = hook.list_files_directory(
            file_system_name="transient",
            directory_name="Licitacoes_Gov"
        )

        return len(files) > 0
    
    
    wait_data = PythonSensor(
        task_id="wait_for_data",
        python_callable=adls_files_exist,
        poke_interval=60,
        timeout=3600,
        mode="reschedule"
    )

    
    @task
    def get_latest_file():
        hook = AzureDataLakeStorageV2Hook(adls_conn_id=AZURE_DATA_LAKE_GEN2_CONN_ID)

        files = hook.list_files_directory(
            file_system_name="transient",
            directory_name="Licitacoes_Gov"
        )

        if not files:
            raise ValueError("Nenhum arquivo encontrado em Licitacoes_Gov")

        latest = sorted(files)[-1]

        return f"abfss://transient@lablicitacoessa.dfs.core.windows.net/{latest}"



    lastest_file = get_latest_file()


    run_bronze_pipeline = AzureSynapseRunPipelineOperator(
        task_id="run_bronze_pipeline",
        pipeline_name="bronze_licitacoes_pipeline",
        azure_synapse_conn_id=AZURE_SYNAPSE_CONN_ID,
        azure_synapse_workspace_dev_endpoint="https://lablicitacoes-gov-sw.dev.azuresynapse.net",
        parameters={
            "input_file": "{{ ti.xcom_pull(task_ids='get_latest_file') }}"
        }
    )



    ingest_data_from_api >> wait_data >> lastest_file >> run_bronze_pipeline

licitacoes_dag()