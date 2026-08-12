"""Orchestrates the 5 required AI reports: pull data from SQL Server (via
views/procs) -> fill a prompt template -> call Mistral through client.py ->
validate -> store via uspStoreAIReport (Database/repository.py).
"""
import pandas as pd

from Configuration.logging_setup import get_logger
from Database.database import get_connection
from Database.repository import get_campaign_summary, get_model_execution_history, store_ai_report
from Ollama import prompts
from Ollama.client import OllamaError, generate

log = get_logger(__name__)


def _overall_metrics() -> dict:
    with get_connection() as conn:
        customers = pd.read_sql(
            "SELECT COUNT(*) AS total, SUM(CASE WHEN CustomerStatus='Active' THEN 1 ELSE 0 END) AS active "
            "FROM dbo.Customer", conn).iloc[0]
        campaigns = pd.read_sql("SELECT COUNT(*) AS n FROM dbo.MarketingCampaign", conn).iloc[0]
        response = pd.read_sql(
            "SELECT CAST(SUM(CASE WHEN PurchaseCompleted=1 THEN 1 ELSE 0 END) AS DECIMAL(10,4)) "
            "/ NULLIF(COUNT(*),0) * 100 AS rate FROM dbo.CampaignResponse", conn).iloc[0]
        revenue = pd.read_sql("SELECT SUM(TransactionTotal) AS total FROM dbo.SalesTransaction", conn).iloc[0]

    history = get_model_execution_history()
    accuracy = float(history.iloc[0]["Accuracy"]) * 100 if len(history) else 0.0

    return {
        "total_customers": int(customers["total"]),
        "active_customers": int(customers["active"] or 0),
        "total_campaigns": int(campaigns["n"]),
        "response_rate": float(response["rate"] or 0),
        "model_accuracy": accuracy,
        "total_revenue": float(revenue["total"] or 0),
    }


def _latest_model_metrics() -> dict:
    history = get_model_execution_history()
    if history.empty:
        raise RuntimeError("No model runs found in ModelExecution - train a model first (see MachineLearning/).")
    latest = history.iloc[0]
    with get_connection() as conn:
        scored = pd.read_sql("SELECT COUNT(*) AS n FROM dbo.CustomerPrediction", conn).iloc[0]
        positive = pd.read_sql(
            "SELECT COUNT(*) AS n FROM dbo.CustomerPrediction WHERE PredictionResult = 'Yes'", conn).iloc[0]
    return {
        "algorithm": latest["Algorithm"],
        "accuracy": float(latest["Accuracy"]),
        "precision": float(latest["Precision_"]) if "Precision_" in latest else float(latest["Precision"]),
        "recall": float(latest["Recall"]),
        "f1_score": float(latest["F1Score"]),
        "total_scored": int(scored["n"]),
        "predicted_positive_count": int(positive["n"]),
    }


def _best_campaign_and_channel() -> dict:
    summary = get_campaign_summary()
    if summary.empty:
        raise RuntimeError("No campaign data found - load the dataset first.")
    best = summary.sort_values("PurchaseCompletionRate", ascending=False).iloc[0]
    best_channel = summary.groupby("ChannelName")["PurchaseCompletionRate"].mean().idxmax()
    winners = summary[summary["PurchaseCompletionRate"] >= summary["PurchaseCompletionRate"].median()]
    return {
        "best_campaign": best["CampaignName"],
        "best_campaign_response_rate": float(best["PurchaseCompletionRate"]),
        "best_channel": best_channel,
        "avg_discount_on_winners": float(winners["DiscountPercent"].mean()) if len(winners) else 0.0,
    }


def _generate_and_store(report_type: str, prompt: str, campaign_id: int | None = None) -> int:
    try:
        text = generate(prompt)
    except OllamaError:
        log.error("Skipping report_type=%s - Ollama call failed", report_type)
        raise
    return store_ai_report(
        report_type=report_type,
        model_name="mistral",
        prompt_version=prompts.PROMPT_VERSION,
        report_text=text,
        campaign_id=campaign_id,
    )


def generate_executive_summary() -> int:
    return _generate_and_store("Executive Summary", prompts.executive_summary_prompt(_overall_metrics()))


def generate_campaign_analysis(campaign_id: int | None = None) -> int:
    summary = get_campaign_summary(campaign_id)
    if summary.empty:
        raise RuntimeError(f"No campaign found for CampaignID={campaign_id}")
    top = summary.sort_values("TotalRevenueGenerated", ascending=False).iloc[0]
    return _generate_and_store("Campaign Analysis", prompts.campaign_analysis_prompt(top.to_dict()),
                                campaign_id=int(top["CampaignID"]))


def generate_prediction_interpretation() -> int:
    return _generate_and_store("Prediction Interpretation", prompts.prediction_interpretation_prompt(_latest_model_metrics()))


def generate_business_recommendations() -> int:
    combined = {**_best_campaign_and_channel(), **_latest_model_metrics()}
    return _generate_and_store("Business Recommendations", prompts.business_recommendations_prompt(combined))


def generate_dashboard_commentary() -> int:
    return _generate_and_store("Dashboard Commentary", prompts.dashboard_commentary_prompt(_overall_metrics()))


def generate_all_reports() -> list[int]:
    """Generates all 5 required reports. Leaves Approved=0 - a human
    reviews each one (see the validation checklist in Parth_Tasks.txt)
    before flipping it to Approved=1.
    """
    generators = [
        generate_executive_summary,
        generate_campaign_analysis,
        generate_prediction_interpretation,
        generate_business_recommendations,
        generate_dashboard_commentary,
    ]
    ids = []
    for gen in generators:
        try:
            ids.append(gen())
        except (OllamaError, RuntimeError) as exc:
            log.error("Report generation failed for %s: %s", gen.__name__, exc)
    log.info("Generated %d/%d AI reports", len(ids), len(generators))
    return ids


if __name__ == "__main__":
    generate_all_reports()
