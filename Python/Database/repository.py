"""All stored-procedure calls the Python pipeline makes, in one place.
Nothing outside this module should write raw SQL against the database.
"""
from datetime import datetime

import pandas as pd

from Configuration.logging_setup import get_logger
from Database.database import get_connection

log = get_logger(__name__)


def get_customer_analytics_dataset() -> pd.DataFrame:
    """Calls uspGeneratePredictionDataset - this is the ML training input."""
    with get_connection() as conn:
        df = pd.read_sql("EXEC dbo.uspGeneratePredictionDataset", conn)
    log.info("Retrieved customer analytics dataset: %d rows, %d columns", len(df), len(df.columns))
    return df


def get_campaign_summary(campaign_id: int | None = None) -> pd.DataFrame:
    with get_connection() as conn:
        df = pd.read_sql("EXEC dbo.uspCampaignSummary @CampaignID = ?", conn, params=[campaign_id])
    return df


def store_prediction_result(
    customer_id: int,
    probability: float,
    result: str,
    ml_model: str,
    model_version: str,
    prediction_date: datetime | None = None,
) -> None:
    prediction_date = prediction_date or datetime.now()
    with get_connection() as conn:
        # uspStorePredictionResults returns a SELECT SCOPE_IDENTITY() row -
        # must be fetched (or the driver reports the connection "busy" on
        # the next command, even on a fresh connection under pooling).
        conn.execute(
            "EXEC dbo.uspStorePredictionResults ?, ?, ?, ?, ?, ?",
            customer_id, prediction_date, probability, result, ml_model, model_version,
        ).fetchall()


def store_prediction_results_bulk(predictions: pd.DataFrame, ml_model: str, model_version: str) -> int:
    """predictions needs columns: CustomerID, Probability, Result."""
    now = datetime.now()
    count = 0
    with get_connection() as conn:
        cursor = conn.cursor()
        for row in predictions.itertuples(index=False):
            cursor.execute(
                "EXEC dbo.uspStorePredictionResults ?, ?, ?, ?, ?, ?",
                int(row.CustomerID), now, float(row.Probability), row.Result, ml_model, model_version,
            )
            cursor.fetchall()  # consume the SCOPE_IDENTITY() result set before the next execute()
            count += 1
        cursor.commit()
        cursor.close()
    log.info("Stored %d prediction rows (model=%s, version=%s)", count, ml_model, model_version)
    return count


def log_model_execution(algorithm: str, accuracy: float, precision: float, recall: float,
                         f1_score: float, duration_seconds: float) -> None:
    with get_connection() as conn:
        conn.execute(
            "EXEC dbo.uspLogModelExecution ?, ?, ?, ?, ?, ?",
            algorithm, accuracy, precision, recall, f1_score, duration_seconds,
        ).fetchall()
    log.info("Logged model execution: %s (accuracy=%.4f, duration=%.1fs)", algorithm, accuracy, duration_seconds)


def store_ai_report(report_type: str, model_name: str, prompt_version: str, report_text: str,
                     campaign_id: int | None = None) -> int:
    with get_connection() as conn:
        row = conn.execute(
            "EXEC dbo.uspStoreAIReport ?, ?, ?, ?, ?",
            report_type, campaign_id, model_name, prompt_version, report_text,
        ).fetchone()
    report_id = int(row[0])
    log.info("Stored AI report id=%d type=%s campaign=%s", report_id, report_type, campaign_id)
    return report_id


def approve_ai_report(report_id: int) -> None:
    with get_connection() as conn:
        conn.execute("UPDATE dbo.AIReport SET Approved = 1 WHERE AIReportID = ?", report_id)


def get_model_execution_history() -> pd.DataFrame:
    with get_connection() as conn:
        return pd.read_sql("SELECT * FROM dbo.ModelExecution ORDER BY ExecutionDate DESC", conn)
