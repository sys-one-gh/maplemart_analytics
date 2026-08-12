"""Thin REST client for the local Ollama server. This is the ONLY module
that talks to Ollama - SQL Server data reaches Mistral exclusively through
here, and Mistral never touches SQL Server directly.
"""
import requests

from Configuration.config import OLLAMA
from Configuration.logging_setup import get_logger

log = get_logger(__name__)


class OllamaError(Exception):
    pass


def generate(prompt: str, retries: int = 1) -> str:
    url = f"{OLLAMA.host}/api/generate"
    payload = {"model": OLLAMA.model, "prompt": prompt, "stream": False}

    last_error = None
    for attempt in range(retries + 1):
        try:
            resp = requests.post(url, json=payload, timeout=OLLAMA.timeout_seconds)
            resp.raise_for_status()
            text = resp.json().get("response", "").strip()
            if not text:
                raise OllamaError("Ollama returned an empty response")
            log.info("Ollama generated %d chars (model=%s, attempt=%d)", len(text), OLLAMA.model, attempt + 1)
            return text
        except (requests.RequestException, OllamaError) as exc:
            last_error = exc
            log.warning("Ollama call failed (attempt %d/%d): %s", attempt + 1, retries + 1, exc)

    log.error("Ollama call failed after %d attempts: %s", retries + 1, last_error)
    raise OllamaError(str(last_error))


def is_available() -> bool:
    try:
        resp = requests.get(f"{OLLAMA.host}/api/tags", timeout=5)
        return resp.ok
    except requests.RequestException:
        return False
