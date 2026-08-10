#!/usr/bin/env bash
# Cross-platform bootstrap for macOS, Linux and WSL (bash).
# Windows without WSL: use scripts/setup.ps1 instead.
#
# What this does, in order:
#   1. Detects your OS and makes sure Docker + Python 3 are available
#      (best-effort auto-install; otherwise tells you exactly what to run)
#   2. Creates .env from .env.example if you don't have one yet
#   3. Starts the sqlserver + ollama containers
#   4. Waits for SQL Server to be ready, then runs Database/*.sql in order
#   5. Loads Dataset/*.csv (generating synthetic placeholder data first if
#      Dataset/ is empty)
#   6. Creates a Python virtualenv and installs Python/requirements.txt
#
# Usage:
#   ./scripts/setup.sh                     full setup
#   ./scripts/setup.sh --branch feature/python   also checks out that branch
#   ./scripts/setup.sh --skip-data         skip dataset generation/load
#   ./scripts/setup.sh --with-ai           also pulls the Ollama mistral model (~4GB)

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."   # repo root
REPO_ROOT="$(pwd)"

BRANCH=""
SKIP_DATA=false
WITH_AI=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --skip-data) SKIP_DATA=true; shift ;;
    --with-ai) WITH_AI=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
ok()   { printf '\033[1;32m    ok:\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m    warn:\033[0m %s\n' "$1"; }
die()  { printf '\033[1;31m    error:\033[0m %s\n' "$1" >&2; exit 1; }
# portable in-place sed (macOS bsd sed vs. gnu sed)
sed_i() { if sed --version >/dev/null 2>&1; then sed -i "$1" "$2"; else sed -i '' "$1" "$2"; fi }

# ---------------------------------------------------------------------------
log "Detecting operating system"
OS="unknown"
IS_WSL=false
case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)
    OS="linux"
    if grep -qi microsoft /proc/version 2>/dev/null; then
      IS_WSL=true
      OS="wsl"
    fi
    ;;
  *) die "Unsupported OS from bash (use scripts/setup.ps1 on native Windows)" ;;
esac
ok "$OS"

# ---------------------------------------------------------------------------
log "Checking Docker"
if ! command -v docker >/dev/null 2>&1; then
  warn "Docker not found - attempting install"
  if [[ "$OS" == "macos" ]]; then
    if command -v brew >/dev/null 2>&1; then
      brew install --cask docker
      warn "Launch Docker.app once from Applications to finish setup, then re-run this script."
      exit 1
    else
      die "Homebrew not found. Install Docker Desktop manually from docker.com, then re-run this script."
    fi
  elif [[ "$OS" == "linux" || "$OS" == "wsl" ]]; then
    if command -v apt-get >/dev/null 2>&1; then
      curl -fsSL https://get.docker.com | sh
      sudo usermod -aG docker "$USER" || true
      warn "Docker Engine installed. Log out/in (or run 'newgrp docker') so your user picks up docker-group access, then re-run this script."
      exit 1
    else
      die "Unsupported Linux distro for auto-install. Install Docker manually, then re-run this script."
    fi
  fi
fi
docker info >/dev/null 2>&1 || die "Docker is installed but not running. Start Docker Desktop (or the docker daemon) and re-run this script."
ok "Docker is installed and running"

# ---------------------------------------------------------------------------
log "Checking Python 3"
PY=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1 && "$cand" -c 'import sys; sys.exit(0 if sys.version_info>=(3,9) else 1)' 2>/dev/null; then
    PY="$cand"; break
  fi
done
if [[ -z "$PY" ]]; then
  warn "Python 3.9+ not found - attempting install"
  if [[ "$OS" == "macos" ]] && command -v brew >/dev/null 2>&1; then
    brew install python
  elif [[ "$OS" == "linux" || "$OS" == "wsl" ]] && command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y python3 python3-venv python3-pip
  fi
  command -v python3 >/dev/null 2>&1 && PY=python3
fi
[[ -n "$PY" ]] || die "Could not find or install Python 3.9+. Install it manually, then re-run this script."
ok "$($PY --version)"

# ---------------------------------------------------------------------------
log "Checking Microsoft ODBC Driver 18 for SQL Server (required by pyodbc)"
if ! (command -v odbcinst >/dev/null 2>&1 && odbcinst -q -d 2>/dev/null | grep -qi "ODBC Driver 18"); then
  warn "ODBC Driver 18 not found - attempting install"
  if [[ "$OS" == "macos" ]] && command -v brew >/dev/null 2>&1; then
    brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release 2>/dev/null || true
    brew trust microsoft/mssql-release 2>/dev/null || true
    HOMEBREW_ACCEPT_EULA=Y brew install unixodbc msodbcsql18 || die "Failed to install ODBC driver via brew"
  elif [[ "$OS" == "linux" || "$OS" == "wsl" ]] && command -v apt-get >/dev/null 2>&1; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc >/dev/null
    curl -fsSL "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs 2>/dev/null || echo 22.04)/prod.list" | sudo tee /etc/apt/sources.list.d/mssql-release.list >/dev/null
    sudo apt-get update
    ACCEPT_EULA=Y sudo apt-get install -y unixodbc msodbcsql18 || die "Failed to install ODBC driver via apt"
  else
    die "Could not auto-install the ODBC driver on this OS. See https://learn.microsoft.com/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server"
  fi
fi
ok "ODBC Driver 18 for SQL Server is available"

# ---------------------------------------------------------------------------
log "Checking .env"
if [[ ! -f .env ]]; then
  cp .env.example .env
  if command -v openssl >/dev/null 2>&1; then
    GEN_PW="$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 20)Aa1!"
    GEN_PW2="$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 20)Bb2!"
    sed_i "s/^SA_PASSWORD=.*/SA_PASSWORD=${GEN_PW}/" .env
    sed_i "s/^POWERBI_READER_PASSWORD=.*/POWERBI_READER_PASSWORD=${GEN_PW2}/" .env
    ok "Generated .env with random SA/Power BI passwords (never committed - see .gitignore)"
  else
    warn ".env created from .env.example - please edit the passwords by hand"
  fi
else
  ok ".env already exists, leaving it as-is"
fi
set -a; source .env; set +a

# ---------------------------------------------------------------------------
log "Checking for port conflicts"

port_in_use() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
  elif command -v nc >/dev/null 2>&1; then
    nc -z localhost "$port" >/dev/null 2>&1
  else
    return 1   # no way to check on this system - assume free
  fi
}

find_free_port() {
  local port="$1" tries=0
  while port_in_use "$port"; do
    port=$((port + 1))
    tries=$((tries + 1))
    [[ $tries -lt 50 ]] || die "Could not find a free port near $1 after 50 tries"
  done
  echo "$port"
}

# If our own containers are already up, whatever port they're bound to is
# already working - never reassign out from under a running setup.
sqlserver_running=false; ollama_running=false
docker ps --format '{{.Names}}' 2>/dev/null | grep -qx maplemart-sqlserver && sqlserver_running=true
docker ps --format '{{.Names}}' 2>/dev/null | grep -qx maplemart-ollama && ollama_running=true

CUR_SQLSERVER_PORT="${SQLSERVER_PORT:-1433}"
CUR_OLLAMA_PORT="${OLLAMA_PORT:-11434}"

if [[ "$sqlserver_running" == false ]] && port_in_use "$CUR_SQLSERVER_PORT"; then
  NEW_PORT="$(find_free_port "$CUR_SQLSERVER_PORT")"
  warn "Port $CUR_SQLSERVER_PORT is already in use by another process - using $NEW_PORT for SQL Server instead"
  CUR_SQLSERVER_PORT="$NEW_PORT"
fi
if [[ "$ollama_running" == false ]] && port_in_use "$CUR_OLLAMA_PORT"; then
  NEW_PORT="$(find_free_port "$CUR_OLLAMA_PORT")"
  warn "Port $CUR_OLLAMA_PORT is already in use by another process - using $NEW_PORT for Ollama instead"
  CUR_OLLAMA_PORT="$NEW_PORT"
fi

grep -q '^SQLSERVER_PORT=' .env && sed_i "s/^SQLSERVER_PORT=.*/SQLSERVER_PORT=${CUR_SQLSERVER_PORT}/" .env || echo "SQLSERVER_PORT=${CUR_SQLSERVER_PORT}" >> .env
grep -q '^OLLAMA_PORT=' .env && sed_i "s/^OLLAMA_PORT=.*/OLLAMA_PORT=${CUR_OLLAMA_PORT}/" .env || echo "OLLAMA_PORT=${CUR_OLLAMA_PORT}" >> .env
sed_i "s/^DB_SERVER=.*/DB_SERVER=localhost,${CUR_SQLSERVER_PORT}/" .env
sed_i "s#^OLLAMA_HOST=.*#OLLAMA_HOST=http://localhost:${CUR_OLLAMA_PORT}#" .env
set -a; source .env; set +a
ok "SQL Server -> host port $SQLSERVER_PORT, Ollama -> host port $OLLAMA_PORT"

# ---------------------------------------------------------------------------
if [[ -n "$BRANCH" ]]; then
  log "Checking out branch: $BRANCH"
  git fetch origin "$BRANCH" 2>/dev/null || true
  git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH" 2>/dev/null || die "Branch $BRANCH not found locally or on origin"
  ok "On branch $(git branch --show-current)"
fi

# ---------------------------------------------------------------------------
log "Starting containers (sqlserver + ollama)"
docker compose up -d
ok "docker compose up -d done"

log "Waiting for SQL Server to accept connections"
SQLCMD_BIN="/opt/mssql-tools18/bin/sqlcmd"
SQLCMD_EXTRA="-C -No"
for i in $(seq 1 12); do
  if docker exec maplemart-sqlserver test -x "$SQLCMD_BIN" 2>/dev/null; then break; fi
  SQLCMD_BIN="/opt/mssql-tools/bin/sqlcmd"; SQLCMD_EXTRA=""
  if docker exec maplemart-sqlserver test -x "$SQLCMD_BIN" 2>/dev/null; then break; fi
  sleep 5
done

ready=false
for i in $(seq 1 30); do
  if docker exec maplemart-sqlserver "$SQLCMD_BIN" -S localhost -U sa -P "$SA_PASSWORD" $SQLCMD_EXTRA -Q "SELECT 1" >/dev/null 2>&1; then
    ready=true; break
  fi
  sleep 5
done
[[ "$ready" == true ]] || die "SQL Server did not become ready in time. Check: docker logs maplemart-sqlserver"
ok "SQL Server is ready"

run_sql() {
  local file="$1"
  echo "    -> $file"
  docker exec maplemart-sqlserver "$SQLCMD_BIN" -S localhost -U sa -P "$SA_PASSWORD" $SQLCMD_EXTRA \
    -v PowerBiPassword="${POWERBI_READER_PASSWORD:-ChangeMePBI!2026}" \
    -b -i "/workspace/${file}"
}

log "Running database scripts (schema)"
for f in \
  "Database/DatabaseCreation/01_CreateDatabase.sql" \
  "Database/Tables/02_CreateReferenceTables.sql" \
  "Database/Tables/03_CreateOperationalTables.sql" \
  "Database/Tables/04_CreateAnalyticalTables.sql" \
  "Database/Constraints/05_CreateConstraints.sql" \
  "Database/Indexes/06_CreateIndexes.sql" \
  "Database/Functions/08_CreateFunctions.sql" \
  "Database/Views/07_CreateViews.sql" \
  "Database/StoredProcedures/09_CreateStoredProcedures.sql" \
  "Database/Security/11_CreateSecurity.sql" \
; do
  run_sql "$f"
done
ok "Schema created"

if [[ "$SKIP_DATA" == false ]]; then
  log "Preparing Python virtualenv"
  $PY -m venv .venv
  # shellcheck disable=SC1091
  source .venv/bin/activate 2>/dev/null || source .venv/Scripts/activate
  pip install --quiet --upgrade pip
  pip install --quiet -r Python/requirements.txt
  ok "Python dependencies installed into .venv"

  if [[ -z "$(ls -A Dataset 2>/dev/null | grep -v '.gitkeep')" ]]; then
    log "Dataset/ is empty - generating synthetic placeholder CSVs"
    python Python/generate_synthetic_dataset.py
    ok "Synthetic dataset generated in Dataset/"
  else
    ok "Dataset/ already has data, skipping generation"
  fi

  log "Loading dataset into SQL Server"
  run_sql "Database/DatabaseCreation/10_LoadDataset.sql"
  ok "Dataset loaded"

  log "Running validation checks"
  run_sql "Database/Validation/12_Validation.sql"
fi

if [[ "$WITH_AI" == true ]]; then
  log "Pulling Ollama model: ${OLLAMA_MODEL:-mistral} (this can take a while)"
  docker exec maplemart-ollama ollama pull "${OLLAMA_MODEL:-mistral}"
  ok "Ollama model ready"
else
  warn "Skipped pulling the Ollama model. Run: docker exec maplemart-ollama ollama pull mistral  (or re-run with --with-ai)"
fi

log "Done"
cat <<EOF

  SQL Server : localhost,${SQLSERVER_PORT}  (user 'sa', password in .env)
  Ollama     : http://localhost:${OLLAMA_PORT}
  Python venv: source .venv/bin/activate   (Windows: .venv\\Scripts\\activate)

  Your branch: $(git branch --show-current)
  When you're ready to upload your part:
    ./scripts/push_my_work.sh "short description of what you did"

EOF
