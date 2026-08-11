# MapleMart Customer Campaign Analytics Platform

A SQL Server–based predictive analytics platform for MapleMart Canada (a
25-store Ontario grocery retailer with the MapleRewards loyalty program)
that predicts which customers are most likely to respond to the next
marketing campaign, using historical sales, loyalty, and campaign-response
data already in SQL Server. Built for SQL Server Development (ITE-5223)
Simulation 8–9.

**Business problem**: MapleMart distributes marketing campaigns to broad
customer groups without predicting who will respond. This platform answers
*"Which customers are most likely to respond to the next campaign?"* using
a supervised classifier trained on `PurchaseCompleted`, then narrates the
results in plain business language via a local LLM and visualizes them in
Power BI.

## Team & roles

| Person | Role |
|---|---|
| Dhruv | Project Lead — Docker environment, GitHub repo, integration testing, README |
| Parth | AI Integration — Ollama/Mistral client, prompt templates, 5 AI reports |
| Kelvin | Database Design — ERD, data dictionary, 3NF, validation script |
| Hassana | Database Implementation — tables, constraints, indexes, security |
| Sahasri | Data Import & Quality — dataset loader, data quality report |
| Lien | SQL Analytics — 5 mandatory views, business query pack, performance notes |
| Brian | Procedures & Functions — 5 functions, 7 stored procedures |
| Sahil | Python & ML — feature engineering, model training, predictions |
| Joshua | Power BI — 6 dashboards, DAX measures |

Full task breakdown per person: `Documentation/TeamTasks/`.

## Technology stack

| Layer | Technology |
|---|---|
| Database | Microsoft SQL Server 2022 (Docker) or SQL Server Express (AWS RDS) |
| Language | Python 3.13 (pandas, numpy, scikit-learn, pyodbc, requests) |
| ML | Random Forest classifier (`scikit-learn`) |
| LLM | Ollama + Mistral 7B, local, narratives only — never predictions, never direct SQL access |
| BI | Power BI (Desktop or Service) |
| DevOps | Docker Desktop, docker-compose, GitHub |

## Repository structure

```
Database/       SQL scripts, run in order: DatabaseCreation, Tables, Constraints,
                Indexes, Functions, Views, StoredProcedures, Security, Validation
Dataset/        the 10 source CSVs
Python/         Configuration, Database, DataPreparation, MachineLearning,
                Ollama, Notebooks, Logs, load_to_rds.py (cloud loader)
PowerBI/        CustomerCampaignAnalytics.pbix, CSVExport/ (flat-file fallback)
Docker/         docker-compose.yml details, StartupInstructions.md
Documentation/  ERD, data dictionary, data quality report, performance notes,
                prompt documentation, team task files
scripts/        setup.sh / setup.ps1 / push_my_work.sh|ps1
```

## Software requirements

- Git
- Docker Desktop (Mac/Windows) or Docker Engine (Linux/WSL)
- Python 3.9+ (auto-installed by the setup script if missing)
- Power BI Desktop (Windows) *or* a free Power BI Service account (browser-only path available, see below)

## Deployment

One command from a fresh clone gets a fully working local environment -
Docker, database, data, and Python all set up automatically.

**macOS / Linux / WSL:**

```bash
git clone https://github.com/sys-one-gh/maplemart_analytics.git
cd maplemart_analytics
./scripts/setup.sh
```

**Windows (native PowerShell, no WSL):**

```powershell
git clone https://github.com/sys-one-gh/maplemart_analytics.git
cd maplemart_analytics
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass   # only if scripts are blocked
.\scripts\setup.ps1
```

What that one command does, automatically, on every platform:

1. Checks for Docker, Python 3.9+, and the Microsoft ODBC Driver 18 -
   installs whichever are missing (Homebrew on Mac, apt on Linux/WSL,
   winget on Windows).
2. Generates `.env` with random database passwords (gitignored, never
   committed).
3. Detects if ports `1433`/`11434` are already taken and auto-picks the
   next free port if so.
4. Starts the `sqlserver` + `ollama` containers via `docker compose`.
5. Creates the full schema (13 tables, 5 views, 5 functions, 7 procedures)
   and loads the dataset - either the real 10 CSVs in `Dataset/`, or
   auto-generated synthetic placeholder data if those aren't present yet.
6. Runs validation checks (row counts, orphan FKs, duplicate keys).
7. Creates a Python virtualenv and installs `Python/requirements.txt`.

**One manual step the first time** (Docker's own requirement, not
something a script can skip): if Docker Desktop had to be installed
fresh, launch it once to accept its permissions, then re-run the setup
command above.

**Prerequisites you need already installed**: Git, and either Docker
Desktop (Mac/Windows) or Docker Engine (Linux/WSL) — everything else is
handled for you.

**Working on a specific part of the project?** Add `--branch feature/<yourname>`
(or `-Branch feature/<yourname>` on PowerShell) to switch onto your branch
as part of the same command - see the branch table in `SETUP.md` §4.

Full details, troubleshooting, the optional AI-report step, and the
AWS-alternative deployment path: **[`SETUP.md`](SETUP.md)**.

## Database

Single database, `dbo` schema, fully re-creatable from scripts (`01`
through `12` in `Database/`, run automatically by `setup.sh`). 13 tables
across reference/operational/analytical groups, 5 views, 5 functions, 7
stored procedures. Schema details: `Documentation/DataDictionary.md` and
`Documentation/ERDiagram.md`.

## Python

```bash
source .venv/bin/activate          # Windows: .venv\Scripts\activate
cd Python
python -m Ollama.report_generator  # generates the 5 AI reports (needs --with-ai model pull first)
```

Or run `Python/Notebooks/CustomerCampaignAnalytics.ipynb` end to end for
the full pipeline with inline output at every step.

## Power BI

Two supported paths — see **`Documentation/PowerBI_Setup_Guide.md`** for
the full dashboard/DAX spec:

1. **Power BI Desktop** (Windows or VM), live connection to the local
   Docker database.
2. **Power BI Service, browser-only**, no Windows required: either a live
   connection to a cloud SQL instance (e.g. AWS RDS — see guide section
   0c), or the flat-file fallback using the pre-exported CSVs in
   `PowerBI/CSVExport/` if your Power BI tenant restricts live cloud-source
   refreshes (a real constraint we hit on a Humber-managed tenant — see the
   guide for the exact symptom and workaround).

## Dataset

10 CSVs, 350,858 total rows:

| File | Rows | Notes |
|---|---|---|
| Stores.csv | 25 | |
| ProductCategories.csv | 18 | |
| Products.csv | 500 | |
| Customers.csv | 5,000 | Age recomputed from DateOfBirth at load - see Data Quality Report |
| LoyaltyMemberships.csv | 5,000 | |
| Employees.csv | 250 | |
| MarketingCampaigns.csv | 40 | |
| SalesTransactions.csv | 75,000 | TransactionTotal recomputed from line items - see Data Quality Report |
| SalesTransactionItems.csv | 250,000 | |
| CampaignResponses.csv | 18,000 | `PurchaseCompleted` is the ML target |

## How this was built

Not a designed-once-then-implemented project — the build order was
infrastructure first, then the pieces were connected and tested for real at
every stage, with real bugs found and fixed along the way rather than
assumed away:

1. **Docker environment** — SQL Server 2022 + Ollama, cross-platform
   (including Apple Silicon emulation, since Microsoft doesn't publish an
   arm64 SQL Server image), with automatic port-conflict detection so
   `1433`/`11434` being already taken on someone's machine doesn't block them.
2. **Database layer** — schema, functions, views, procedures, security —
   built and tested against real data, not sample rows. Loading the real
   10-CSV dataset surfaced two genuine data-quality problems (a numeric
   column that was 0 for every row; a date-derived column that was stale
   for some rows) which got fixed at the load-script level, not patched
   around downstream.
3. **Python ML pipeline** — connectivity, feature engineering, training,
   evaluation, prediction storage. Trained and verified twice, independently,
   in two different environments (see below) to make sure the result wasn't
   an artifact of one machine's state.
4. **A real cloud deployment, not just local Docker** — the whole platform
   was also stood up on **AWS RDS SQL Server** to prove it isn't hardcoded
   to one setup. This surfaced its own real problems: `BULK INSERT` doesn't
   work against a filesystem-less managed database (solved with a
   Python-based loader instead), and a view that ran fine locally took
   **14.5 seconds** on the smaller cloud instance because it called scalar
   SQL functions once per row — rewriting it as set-based joins brought that
   down to **0.5 seconds**, a fix that ended up mattering everywhere that
   view is used, not just on AWS.
5. **AI reports via Ollama/Mistral** — generated, then actually read rather
   than assumed correct. Two of the five initially invented a timeframe
   ("Q1") that was never supplied in the prompt - caught, the prompt fixed,
   regenerated, verified clean before approval.
6. **Power BI** — connected to the live database, hit a Power BI Service
   tenant-governance restriction blocking live cloud-source refresh
   mid-project, diagnosed it, and switched to a CSV-based import path that
   sidesteps it entirely. Also caught and removed an incorrectly
   auto-detected table relationship (`Customer.City` ↔ `Store.City` — a
   coincidental column-name match, not a real foreign key) before it could
   silently produce misleading cross-filtered numbers on a dashboard.

Every fix above came from actually running the thing and looking at the
output — not from reasoning about what should theoretically work.

## Results summary

- **Model**: Random Forest classifier, target `PurchaseCompleted`, 10
  engineered features, 80/20 stratified train/test split.
- **Performance** (test set): **77.4% accuracy, 71.6% precision, 79.4%
  recall, 75.3% F1**. In business terms: when the model flags a customer as
  a likely responder, it's right about 72% of the time; it also catches
  about 79% of the customers who genuinely would respond.
- **Predictions**: all 5,000 customers scored; 2,294 (45.8%) predicted as
  likely responders to the next campaign.
- **AI reports**: all 5 required report types generated via Ollama/Mistral,
  grounded correctly in real query results (see
  `Documentation/PromptDocumentation.md` for the human review that caught
  and fixed one prompt issue - two reports initially referenced a
  timeframe that was never supplied, corrected in prompt `v1.1`).
- **Performance engineering**: found and fixed a 29x performance
  regression in `vwCustomerAnalytics` (14.5s → 0.5s for the same 5,000-row
  result) by inlining scalar function calls into set-based joins — see
  `Database/Views/PerformanceNotes.md`.
- **Deployed and verified in two environments**: local Docker (full
  pipeline including Ollama) and AWS RDS SQL Server Express (proving the
  schema/data/ML layer is portable, not just locally hardcoded).

## Known limitations

- `Customer.Email` is not unique — 41 real customers (0.8%) share an email
  with another customer in the source data; enforcing uniqueness would have
  meant dropping real rows during load (see Data Quality Report).
- The AI reports are grounded in real query results but are still an LLM's
  narrative framing of those numbers — each one requires a human review
  pass (`Approved` flag) before being treated as final, not an
  auto-published output.
- Power BI Service's live-refresh-from-a-cloud-source behavior is subject
  to whatever governance policy your specific Power BI tenant applies (we
  hit a Humber-tenant restriction mid-project); the CSV fallback in
  `PowerBI/CSVExport/` exists specifically because of that, and needs a
  manual re-export if the underlying data changes.
- AWS RDS deployment uses SQL Server *Express* Edition (free-tier
  eligible) — `BULK INSERT` isn't available against it (no filesystem
  access), so `Python/load_to_rds.py` loads data via row-batched `pyodbc`
  inserts instead, which is slower than the local Docker path's native
  `BULK INSERT`.
