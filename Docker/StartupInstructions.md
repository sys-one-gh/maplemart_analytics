# Startup Instructions

The whole environment is automated - see `scripts/setup.sh` (macOS/Linux/WSL)
or `scripts/setup.ps1` (native Windows). What follows is what those scripts
do, spelled out for reference or manual/offline setup.

## Prerequisites

- Docker Desktop (or Docker Engine on Linux/WSL), running
- Python 3.9+
- Git

## One-command setup

```bash
git clone <repo-url>
cd maplemart_analytics
./scripts/setup.sh --branch feature/<yourname>
```

Windows without WSL:

```powershell
git clone <repo-url>
cd maplemart_analytics
.\scripts\setup.ps1 -Branch feature/<yourname>
```

## What it does

1. Checks/installs Docker and Python 3.
2. Copies `.env.example` to `.env` with a randomly generated SA password
   (never committed - see `.gitignore`).
3. `docker compose up -d` - starts the `sqlserver` and `ollama` containers.
4. Waits for SQL Server to accept connections, then runs
   `Database/**/*.sql` in dependency order (01 through 09, then 11).
5. Creates a Python virtualenv, installs `Python/requirements.txt`.
6. If `Dataset/` is empty, generates synthetic placeholder CSVs
   (`Python/generate_synthetic_dataset.py`) so the pipeline is testable
   before the real course dataset is dropped in.
7. Loads the dataset (`10_LoadDataset.sql`) and runs validation (`12_Validation.sql`).
8. Optionally (`--with-ai` / `-WithAI`) pulls the Ollama `mistral` model (~4GB).

## Ports

SQL Server and Ollama normally publish on `1433` and `11434`. If either port
is already taken by something else on your machine, the setup script
auto-picks the next free port and writes it to `.env` as `SQLSERVER_PORT` /
`OLLAMA_PORT` (and updates `DB_SERVER` / `OLLAMA_HOST` to match) - the
container's own internal port never changes, only the host-side mapping.
**Always check `.env` for the actual port in use** rather than assuming 1433/11434.

## Manual verification

```bash
docker exec -it maplemart-sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -C -No
curl "http://localhost:${OLLAMA_PORT:-11434}/api/tags"
```

## Connecting from SSMS / Azure Data Studio

- Server: `localhost,<SQLSERVER_PORT from .env>` (e.g. `localhost,1433`)
- Auth: SQL login, user `sa`, password from your local `.env`

## Connecting from Power BI

- Get Data -> SQL Server -> Server `localhost,<SQLSERVER_PORT from .env>`, Database `CustomerCampaignAnalytics`
- Auth: SQL login `powerbi_reader`, password from `POWERBI_READER_PASSWORD` in `.env`
