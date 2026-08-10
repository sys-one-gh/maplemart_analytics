"""Data quality checks on the customer analytics dataset pulled from SQL
Server, before it goes anywhere near feature engineering or training.
"""
import pandas as pd

from Configuration.logging_setup import get_logger

log = get_logger(__name__)


def validate(df: pd.DataFrame) -> dict:
    report = {
        "row_count": len(df),
        "missing_values": {},
        "duplicate_customer_ids": 0,
        "invalid_values": {},
    }

    missing = df.isna().sum()
    report["missing_values"] = {col: int(n) for col, n in missing.items() if n > 0}

    dup_mask = df["CustomerID"].duplicated()
    report["duplicate_customer_ids"] = int(dup_mask.sum())

    invalid = {}
    if "Age" in df.columns:
        bad_age = ((df["Age"] < 18) | (df["Age"] > 120)).sum()
        if bad_age:
            invalid["Age_out_of_range"] = int(bad_age)
    if "TotalAmountSpent" in df.columns:
        neg_spend = (df["TotalAmountSpent"] < 0).sum()
        if neg_spend:
            invalid["TotalAmountSpent_negative"] = int(neg_spend)
    if "CampaignResponseRate" in df.columns:
        bad_rate = ((df["CampaignResponseRate"] < 0) | (df["CampaignResponseRate"] > 100)).sum()
        if bad_rate:
            invalid["CampaignResponseRate_out_of_range"] = int(bad_rate)
    report["invalid_values"] = invalid

    log.info("Validation: %d rows, %d columns with missing values, %d duplicate CustomerIDs, %d invalid-value checks flagged",
              report["row_count"], len(report["missing_values"]), report["duplicate_customer_ids"], len(invalid))
    for col, n in report["missing_values"].items():
        log.info("  missing: %s -> %d rows", col, n)
    for check, n in invalid.items():
        log.warning("  invalid: %s -> %d rows", check, n)

    return report
