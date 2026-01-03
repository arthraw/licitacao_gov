import pytest
from airflow.models import DagBag
from unittest.mock import MagicMock, patch


@pytest.fixture
def dagbag():
    # Carrega as DAGs da pasta dags/ sem rodar o Scheduler
    return DagBag(dag_folder='dags/', include_examples=False)

def test_no_import_errors(dagbag):
    """Garante que não existem erros de sintaxe ou importação"""
    assert len(dagbag.import_errors) == 0, f"Erros encontrados: {dagbag.import_errors}"

def test_dag_tags(dagbag):
    """Garante que todas as DAGs possuem pelo menos uma tag"""
    for dag_id, dag in dagbag.dags.items():
        assert dag.tags, f"A DAG {dag_id} precisa de tags para organização."

""" 
def test_task_ingest_data_from_api(dagbag):
    dag_id = "licitacoes_dag"
    dag = dagbag.dags.get(dag_id)
    task = dag.get_task("ingest_licitacoes_data")
    from airflow.utils import timezone
    execution_date = timezone.utcnow()
    
    context = {
        'dag': dag,
        'ds': execution_date.strftime('%Y-%m-%d'),
        'execution_date': execution_date,
        'ti': MagicMock(),
        'task': task
    }

    
    result = task.execute(context=context)
    print(f"Resultado da tarefa: {result}")
    
    assert task.task_id == "ingest_licitacoes_data"
"""

def test_ingest_task_mocked(dagbag):
    """Testa a execução da task do Airbyte usando Mock para não precisar de conexão real"""
    dag = dagbag.dags.get("licitacoes_dag")
    task = dag.get_task("ingest_licitacoes_data")

    with patch("airflow.providers.airbyte.operators.airbyte.AirbyteHook") as mock_hook:
        mock_hook.return_value.submit_sync_connection.return_value.json.return_value = {"job": {"id": 123}}
        mock_hook.return_value.get_job.return_value.json.return_value = {"status": "succeeded"}
        
        context = {"ti": MagicMock(), "dag": dag, "task": task}
        
        result = task.execute(context=context)
        print(f"Resultado mockado da tarefa: {result}")
        assert task.airbyte_conn_id == "airbyte_conn"
        assert task.connection_id == "405b2bcc-c792-47fd-9ba5-12740ec54c67"