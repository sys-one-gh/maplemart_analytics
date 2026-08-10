"""Computes and interprets the 4 required metrics + confusion matrix."""
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score, precision_score, recall_score

from Configuration.logging_setup import get_logger

log = get_logger(__name__)


def evaluate(model, X_test, y_test) -> dict:
    y_pred = model.predict(X_test)

    metrics = {
        "accuracy": accuracy_score(y_test, y_pred),
        "precision": precision_score(y_test, y_pred, zero_division=0),
        "recall": recall_score(y_test, y_pred, zero_division=0),
        "f1_score": f1_score(y_test, y_pred, zero_division=0),
        "confusion_matrix": confusion_matrix(y_test, y_pred).tolist(),
    }

    tn, fp, fn, tp = confusion_matrix(y_test, y_pred).ravel()
    metrics["business_interpretation"] = {
        "accuracy": f"The model correctly classifies {metrics['accuracy']*100:.1f}% of customers overall.",
        "precision": (f"When the model predicts a customer WILL respond, it's right "
                       f"{metrics['precision']*100:.1f}% of the time - this bounds wasted campaign spend "
                       f"on customers targeted but who won't convert."),
        "recall": (f"Of customers who actually respond, the model catches "
                    f"{metrics['recall']*100:.1f}% of them - this bounds missed-opportunity cost from "
                    f"under-targeting."),
        "f1_score": f"F1 (precision/recall balance) is {metrics['f1_score']:.3f}.",
        "confusion_matrix": (f"True negatives={tn}, False positives={fp}, False negatives={fn}, "
                              f"True positives={tp}."),
    }

    log.info("Evaluation: accuracy=%.4f precision=%.4f recall=%.4f f1=%.4f",
              metrics["accuracy"], metrics["precision"], metrics["recall"], metrics["f1_score"])
    return metrics
