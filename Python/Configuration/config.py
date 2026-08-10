"""Central config loader. No connection strings or secrets are hardcoded
anywhere else in the codebase - everything else imports from here.

Precedence: environment variables / .env (repo root) override settings.json,
so the same .env that scripts/setup.sh generates for Docker also drives
Python - you don't maintain the SA password in two places.
"""
import json
import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

REPO_ROOT = Path(__file__).resolve().parents[2]
load_dotenv(REPO_ROOT / ".env")

_SETTINGS_PATH = Path(__file__).parent / "settings.json"
if not _SETTINGS_PATH.exists():
    _SETTINGS_PATH = Path(__file__).parent / "settings.example.json"

with open(_SETTINGS_PATH) as f:
    _settings = json.load(f)


@dataclass(frozen=True)
class DatabaseConfig:
    server: str
    database: str
    user: str
    password: str
    driver: str
    encrypt: bool
    trust_server_certificate: bool

    @property
    def connection_string(self) -> str:
        return (
            f"DRIVER={{{self.driver}}};SERVER={self.server};DATABASE={self.database};"
            f"UID={self.user};PWD={self.password};"
            f"Encrypt={'yes' if self.encrypt else 'no'};"
            f"TrustServerCertificate={'yes' if self.trust_server_certificate else 'no'};"
        )


@dataclass(frozen=True)
class OllamaConfig:
    host: str
    model: str
    timeout_seconds: int


@dataclass(frozen=True)
class MLConfig:
    algorithm: str
    model_version: str
    test_size: float
    random_state: int


def _env(key: str, default):
    return os.environ.get(key, default)


# encrypt defaults to False in settings.example.json: this connects to
# localhost only (the Docker container), and unixODBC's TLS handshake with
# the driver hangs on macOS/Linux for the container's self-signed cert. Set
# encrypt=true (and use a real cert) if this ever points at a non-local server.
DATABASE = DatabaseConfig(
    server=_env("DB_SERVER", _settings["database"]["server"]),
    database=_env("DB_NAME", _settings["database"]["database"]),
    user=_env("DB_USER", _settings["database"]["user"]),
    password=_env("SA_PASSWORD", _settings["database"]["password"]),
    driver=_settings["database"]["driver"],
    encrypt=_settings["database"]["encrypt"],
    trust_server_certificate=_settings["database"]["trust_server_certificate"],
)

OLLAMA = OllamaConfig(
    host=_env("OLLAMA_HOST", _settings["ollama"]["host"]),
    model=_env("OLLAMA_MODEL", _settings["ollama"]["model"]),
    timeout_seconds=_settings["ollama"]["timeout_seconds"],
)

ML = MLConfig(**_settings["ml"])

LOGS_DIR = REPO_ROOT / "Python" / "Logs"
LOGS_DIR.mkdir(parents=True, exist_ok=True)
