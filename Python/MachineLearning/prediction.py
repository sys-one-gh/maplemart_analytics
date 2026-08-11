"""Scores the full customer base with a trained model and writes results
back to SQL Server via uspStorePredictionResults / uspLogModelExecution.
"""
import pandas as pd

from Configuration.config import ML
from Configuration.logging_setup import get_logger
from Database.repository import log_model_execution, store_prediction_results_bulk

log = get_logger(__name__)


def predict_all(model, X_all: pd.DataFrame, customer_ids: pd.Series) -> pd.DataFrame:
    probabilities = model.predict_proba(X_all)[:, 1]
    results = pd.DataFrame({
        "CustomerID": customer_ids.values,
        "Probability": probabilities,
        "Result": ["Yes" if p >= 0.5 else "No" for p in probabilities],
    })
    log.info("Scored %d customers: %d predicted 'Yes' (%.1f%%)",
              len(results), (results["Result"] == "Yes").sum(),
              (results["Result"] == "Yes").mean() * 100)
    return results


def store_predictions_and_metrics(predictions: pd.DataFrame, metrics: dict, duration_seconds: float) -> None:
    store_prediction_results_bulk(predictions, ml_model=ML.algorithm, model_version=ML.model_version)
    log_model_execution(
        algorithm=ML.algorithm,
        accuracy=metrics["accuracy"],
        precision=metrics["precision"],
        recall=metrics["recall"],
        f1_score=metrics["f1_score"],
        duration_seconds=duration_seconds,
    )
