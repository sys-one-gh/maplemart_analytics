"""Shared logging setup - every module in Python/ calls get_logger(__name__)
instead of configuring logging itself, so log format/destination stays
consistent across the whole pipeline (DataPreparation, MachineLearning, Ollama).
"""
import logging
import sys

from Configuration.config import LOGS_DIR

_CONFIGURED = False


def _configure_root():
    global _CONFIGURED
    if _CONFIGURED:
        return
    handlers = [
        logging.FileHandler(LOGS_DIR / "pipeline.log", encoding="utf-8"),
        logging.StreamHandler(sys.stdout),
    ]
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s  %(levelname)-7s  %(name)s: %(message)s",
        handlers=handlers,
    )
    _CONFIGURED = True


def get_logger(name: str) -> logging.Logger:
    _configure_root()
    return logging.getLogger(name)
