from airflow.sdk import dag, task
from airflow.providers.microsoft.azure.operators.synapse import AzureSynapseRunPipelineOperator
from airflow.providers.microsoft.azure.hooks.data_lake import AzureDataLakeStorageV2Hook
from airflow.providers.microsoft.azure.hooks.synapse import AzureSynapsePipelineHook
from airflow.providers.airbyte.operators.airbyte import AirbyteTriggerSyncOperator
from datetime import datetime
from airflow.providers.standard.sensors.python import PythonSensor

AIRBYTE_CONN_NAME = "airbyte_conn"
AIRBYTE_CONNECTION_ID = "405b2bcc-c792-47fd-9ba5-12740ec54c67" # Id da conexão criada no Airbyte (Presente na url do Airbyte)
AZURE_DATA_LAKE_GEN2_CONN_ID = "azure_data_lake_v2"
AZURE_SYNAPSE_CONN_ID = "azure_synapse_workspace"
year = datetime.now().year


@dag(
    dag_id="licitacoes_dag",
    catchup=False,
    start_date=datetime(2026, 1, 1),
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

    def run_pipeline(pipe_name: str, file_path: str = None):
        hook = AzureSynapsePipelineHook(
            azure_synapse_conn_id=AZURE_SYNAPSE_CONN_ID,
            azure_synapse_workspace_dev_endpoint="https://lablicitacoes-gov-sw.dev.azuresynapse.net"
        )
        if not file_path:
            run_id = hook.run_pipeline(
                pipeline_name=pipe_name,
            )
        else:
            run_id = hook.run_pipeline(
                pipeline_name=pipe_name,
                parameters={
                    "input_file": file_path
                }
            )

        status = hook.get_pipeline_run(run_id=run_id.run_id).status
        while status not in ["Succeeded", "Failed", "Cancelled"]:
            import time
            time.sleep(5)
            status = hook.get_pipeline_run(run_id=run_id.run_id).status
            print(f"Status atual da pipeline: {status}")

        if status != "Succeeded":
            raise Exception(f"A pipeline do Synapse falhou com status: {status}")
        return run_id

    @task()
    def run_bronze_pipeline(input_file: str):
        run_id = run_pipeline(pipe_name="bronze_licitacoes_pipeline", file_path=input_file)
        return run_id

    @task()
    def run_silver_pipeline():
        run_id = run_pipeline(pipe_name="silver_licitacoes_pipeline")
        return run_id

    run_silver = run_silver_pipeline()

    ingest_data_from_api >> wait_data >> lastest_file >> run_bronze_pipeline(lastest_file) >> run_silver

licitacoes_dag()