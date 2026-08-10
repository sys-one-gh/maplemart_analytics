"""Trains the one required classifier.

Algorithm: RandomForestClassifier. Chosen because it handles the mix of
numeric and ordinal-encoded categorical features here without scaling,
tolerates the class imbalance in PurchaseCompleted reasonably well, and
exposes feature_importances_ - useful for the "why did the model predict
this" business narrative Parth's AI reports need.
"""
import time

from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split

from Configuration.config import ML
from Configuration.logging_setup import get_logger

log = get_logger(__name__)


def split_data(X, y):
    # Stratified so the (typically low) positive-response rate is
    # represented proportionally in both the train and test sets.
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=ML.test_size, random_state=ML.random_state, stratify=y
    )
    log.info("Split: train=%d, test=%d (test_size=%.0f%%, stratified on target)",
              len(X_train), len(X_test), ML.test_size * 100)
    return X_train, X_test, y_train, y_test


def train_model(X_train, y_train) -> tuple:
    model = RandomForestClassifier(
        n_estimators=200,
        max_depth=10,
        min_samples_leaf=5,
        class_weight="balanced",
        random_state=ML.random_state,
        n_jobs=-1,
    )
    start = time.perf_counter()
    model.fit(X_train, y_train)
    duration = time.perf_counter() - start
    log.info("Trained %s in %.2fs on %d rows", ML.algorithm, duration, len(X_train))
    return model, duration
