# Setup Guide

One command gets you a running database, loaded data, and a working Python
environment. This doc is everything you need from "I just cloned this" to
"I'm working on my part."

## 1. Prerequisites

| Tool | Needed on |
|---|---|
| Git | everyone (you need it to clone this) |
| Docker Desktop (Mac/Windows) or Docker Engine (Linux/WSL) | everyone |
| Python 3.9+ | everyone (auto-installed if missing) |
| ~5 GB free disk space | everyone (more if you pull the AI model, see step 5) |

You do **not** need to install SQL Server, Ollama, or the ODBC driver
yourself - the setup script handles that.

## 2. Clone and run

```bash
git clone https://github.com/sys-one-gh/maplemart_analytics.git
cd maplemart_analytics
./scripts/setup.sh --branch feature/<yourname>
```

**Windows without WSL:**

PowerShell blocks running `.ps1` scripts by default - if you see an error
like *"running scripts is disabled on this system"*, run this once first
(only affects your current PowerShell window, not a permanent system change):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then:

```powershell
git clone https://github.com/sys-one-gh/maplemart_analytics.git
cd maplemart_analytics
.\scripts\setup.ps1 -Branch feature/<yourname>
```

Replace `feature/<yourname>` with the branch for your part of the project
(see the table in step 4). Leave it off entirely to just stay on `main`.

## 3. What happens automatically

1. Checks for Docker, Python, and the Microsoft ODBC Driver 18 - installs
   whichever are missing (via Homebrew / apt / winget depending on your OS).
2. Creates `.env` with randomly generated database passwords (never
   committed - it's gitignored).
3. Checks if ports `1433` (SQL Server) / `11434` (Ollama) are already taken
   on your machine; if so, auto-picks the next free port and updates `.env`
   to match.
4. Starts the `sqlserver` and `ollama` containers.
5. Runs the full database schema (13 tables, 5 views, 5 functions, 7
   procedures, security).
6. Loads `Dataset/*.csv` - if you don't have the real course CSVs yet, it
   generates placeholder synthetic data instead so you're never blocked.
7. Runs validation checks (row counts, orphan FKs, duplicate keys).
8. Creates a Python virtualenv (`.venv`) and installs `Python/requirements.txt`.

**One manual step the first time (Docker's own requirement, not something a
script can skip):** if Docker Desktop had to be installed fresh, launch it
once from your Applications/Start menu to accept its permissions, then
re-run the command above.

Everything else runs unattended. `sudo`/admin password prompts are the only
other interruptions you might see (Linux/WSL package installs, Windows
`winget`).

## 4. Find your task

Your role's step-by-step instructions are in `Documentation/TeamTasks/`.
Read **`00_MASTER_PROJECT_GUIDE.txt`** first (applies to everyone), then
your own file:

| Branch | Person | Task file |
|---|---|---|
| `main` (lead) | Dhruv | `Dhruv_Tasks.txt` |
| `feature/ollama` | Parth | `Parth_Tasks.txt` |
| `feature/database` | Kelvin | `Kelvin_Tasks.txt` |
| `feature/database` | Hassana | `Hassana_Tasks.txt` |
| `feature/database` | Sahasri | `Sahasri_Tasks.txt` |
| `feature/database` | Lien | `Lien_Tasks.txt` |
| `feature/database` | Brian | `Brian_Tasks.txt` |
| `feature/python` | Sahil | `Sahil_Tasks.txt` |
| `feature/powerbi` | Joshua | `Joshua_Tasks.txt` |

## 5. Optional: the AI reports (Ollama + Mistral)

Skipped by default because it's a ~4 GB download:

```bash
./scripts/setup.sh --with-ai
```

Then generate the 5 required reports:

```bash
source .venv/bin/activate   # Windows: .venv\Scripts\activate
cd Python
python -m Ollama.report_generator
```

## 6. Verify it worked

```bash
docker ps                                   # both containers "healthy"/"Up"
source .venv/bin/activate
python Python/Database/database.py          # prints "Connected."
```

Or open `Python/Notebooks/CustomerCampaignAnalytics.ipynb` and run it top to
bottom - it walks the full pipeline (connect -> validate -> train -> predict
-> store) with output at every step.

## 7. Daily workflow

```bash
git pull                                     # get the latest
# ... do your work ...
./scripts/push_my_work.sh "what you did"     # stage, commit, push your branch
```

`push_my_work.sh` only ever pushes to **your current branch**, never `main`
- it refuses to run if you're on `main`. Nothing pushes automatically; you
run it yourself when you're ready.

## 8. Where things live

```
Database/     SQL scripts (run in order: DatabaseCreation, Tables, Constraints,
              Indexes, Functions, Views, StoredProcedures, Security, Validation)
Dataset/      the 10 CSVs
Python/       Configuration, Database, DataPreparation, MachineLearning,
              Ollama, Notebooks, Logs, load_to_rds.py (cloud DB loader, see
              PowerBI_Setup_Guide.md section 0c)
PowerBI/      CustomerCampaignAnalytics.pbix goes here (see Documentation/PowerBI_Setup_Guide.md)
Docker/       docker-compose.yml details + StartupInstructions.md
Documentation/ ERD, data dictionary, technical report, team task files
scripts/      setup.sh / setup.ps1 / push_my_work.sh|ps1
```

## 9. Troubleshooting

- **Port already in use**: handled automatically (step 3.3) - check `.env`
  for the actual `SQLSERVER_PORT`/`OLLAMA_PORT` in use.
- **Need a clean slate**: `docker compose down -v` (wipes the database
  volume too), then re-run the setup script.
- **Container won't start**: `docker logs maplemart-sqlserver`
- **pyodbc connection errors**: confirm `.venv` is active and `.env` exists;
  re-run `./scripts/setup.sh --skip-data` to re-verify prerequisites without
  reloading data.
- **Script fails mid-way**: it's safe to just re-run it - every step is
  idempotent (the database is fully recreated from scratch each run).

## 10. What's next

Once your part of the database/Python/Ollama work is solid, Power BI is the
last piece - see `Documentation/PowerBI_Setup_Guide.md`. It covers both
Power BI Desktop (Windows/VM, connects to your local Docker database) and a
fully-browser alternative (Power BI Service + a small cloud SQL Server
instance, no Windows needed at all - see its section 0c). Whoever isn't
building the dashboards themselves doesn't need database access either way -
the finished `PowerBI/CustomerCampaignAnalytics.pbix` in the repo is a
self-contained snapshot anyone can open.
