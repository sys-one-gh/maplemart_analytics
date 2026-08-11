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

One command from a fresh clone:

```bash
git clone https://github.com/sys-one-gh/maplemart_analytics.git
cd maplemart_analytics
./scripts/setup.sh          # macOS/Linux/WSL
# or: .\scripts\setup.ps1   # native Windows
```

This installs prerequisites, starts SQL Server + Ollama in Docker, creates
the full schema, loads the dataset, and sets up a Python virtualenv. Full
details, troubleshooting, and the AI-report/AWS-alternative paths:
**[`SETUP.md`](SETUP.md)**.

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
