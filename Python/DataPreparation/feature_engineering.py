"""Turns the raw vwCustomerAnalytics pull into the 10-feature matrix (X) and
target (y) used for training/prediction. Column names here must match the
view's output columns exactly.
"""
import pandas as pd

from Configuration.logging_setup import get_logger

log = get_logger(__name__)

FEATURE_COLUMNS = [
    "Age",
    "LoyaltyLevelEncoded",
    "NumTransactions",
    "TotalAmountSpent",
    "AveragePurchaseValue",
    "DaysSinceLastPurchase",
    "NumCampaignsReceived",
    "CampaignResponseRate",
    "NumDistinctProductsPurchased",
    "AverageDiscountReceived",
]

_LOYALTY_ORDER = {"Bronze": 1, "Silver": 2, "Gold": 3, "Platinum": 4}


def engineer_features(df: pd.DataFrame, for_training: bool = True):
    """Returns (X, y, customer_ids) when for_training, else (X, customer_ids)
    for scoring the full customer base (y may be missing/irrelevant there).
    """
    work = df.copy()

    work["LoyaltyLevelEncoded"] = work["LoyaltyLevel"].map(_LOYALTY_ORDER).fillna(0).astype(int)

    # A customer with no purchases has DaysSinceLastPurchase = NULL from the
    # view - impute with "worse than the observed worst", not 0 (0 would
    # falsely say "purchased today").
    if work["DaysSinceLastPurchase"].notna().any():
        sentinel = int(work["DaysSinceLastPurchase"].max()) + 1
    else:
        sentinel = 9999
    work["DaysSinceLastPurchase"] = work["DaysSinceLastPurchase"].fillna(sentinel)

    for col in ["NumTransactions", "TotalAmountSpent", "AveragePurchaseValue", "NumCampaignsReceived",
                "CampaignResponseRate", "NumDistinctProductsPurchased", "AverageDiscountReceived"]:
        work[col] = work[col].fillna(0)

    if for_training:
        before = len(work)
        work = work.dropna(subset=["PurchaseCompleted"])
        dropped = before - len(work)
        if dropped:
            log.info("Dropped %d customers with no campaign-response history (no target label)", dropped)
        X = work[FEATURE_COLUMNS]
        y = work["PurchaseCompleted"].astype(int)
        log.info("Feature engineering complete: X=%s, positive rate=%.1f%%", X.shape, y.mean() * 100)
        return X, y, work["CustomerID"]

    X = work[FEATURE_COLUMNS]
    return X, work["CustomerID"]
