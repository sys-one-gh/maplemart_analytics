# Team Contribution Statement

Per-person summary of what was built, matching the responsibility split in
`Documentation/TeamTask

**Dhruv (P1) — Project Lead & Integrator**: Built `docker-compose.yml`
(SQL Server 2022 + Ollama, cross-platform including Apple Silicon
emulation), `scripts/setup.sh`/`setup.ps1` for one-command bootstrap on
macOS/Linux/WSL/Windows with automatic port-conflict resolution, GitHub
repository and branch structure, and ran the end-to-end integration test in
two separate environments (local Docker and AWS RDS) to prove the platform
isn't hardcoded to one setup. Wrote the final `README.md` and this
statement.

**Parth (P2) — AI Integration Developer**: Built the Ollama REST client,
the 5 prompt templates, and the report generator (`Python/Ollama/`).
Generated all 5 required AI reports via Mistral, reviewed them for factual
accuracy against the source data, caught a prompt issue (two reports
fabricated an unsupplied "Q1" timeframe), fixed the prompt template
(`v1.0` → `v1.1`), and regenerated the affected reports. Wrote
`Documentation/PromptDocumentation.md` with real prompts/responses and the
validation evidence.

**Kelvin (P3) — Database Designer**: Designed the 13-table schema across
reference/operational/analytical groups, documented in
`Documentation/ERDiagram.md` (with 3NF justification) and
`Documentation/DataDictionary.md` (full column-by-column detail matching
the deployed schema exactly). Wrote `Database/Validation/12_Validation.sql`
and ran it after every load — zero orphan FKs, zero duplicate keys, zero
constraint violations across 350,858 rows, in both deployment environments.

**Hassana (P4) — Database Implementation Developer**: Wrote scripts 01–06
(database, reference tables, operational tables, analytical tables,
constraints, indexes) and `11_CreateSecurity.sql` (the read-only
`powerbi_reader` login). Adjusted the schema mid-project for two real
findings from the actual source data: added a `Customer.Address` column
that wasn't in the original assumption, and relaxed the `Customer.Email`
uniqueness constraint after finding 41 legitimate duplicate emails in the
real dataset rather than silently dropping those rows.

**Sahasri (P5) — Data Import & Quality Developer**: Wrote
`10_LoadDataset.sql` (staged lookup resolution for the 3 CSVs that carry
text values instead of surrogate keys, FK-safe load order) and
`Python/load_to_rds.py` (the cloud equivalent, since `BULK INSERT` isn't
available against a filesystem-less RDS instance). Wrote
`Documentation/DataQualityReport.md` documenting two real, non-trivial
issues found and corrected: `TransactionTotal` was 0 for all 75,000 source
rows (recomputed from line items) and `Age` was stale for 46 customers
(recomputed from `DateOfBirth`).

**Lien (P6) — SQL Analytics Developer**: Built all 5 mandatory views and
the 7-query business pack (`Database/Views/`). Found and fixed a 29x
performance regression in `vwCustomerAnalytics` (14.5s → 0.5s for the same
result) by replacing per-row scalar function calls with set-based CTEs/
joins — the highest-impact optimization in the project, since that view
feeds the ML pipeline and every customer-level dashboard. Documented real,
measured execution statistics (not estimates) in
`Database/Views/PerformanceNotes.md`.

**Brian (P7) — Stored Procedure & Function Developer**: Wrote all 5
required functions and 7 required procedures
(`Database/Functions/08_CreateFunctions.sql`,
`Database/StoredProcedures/09_CreateStoredProcedures.sql`), plus
`uspLogModelExecution` for the ML run history.

**Sahil (P8) — Python & Machine Learning Developer**: Built the full
pipeline (`Python/Configuration`, `Database`, `DataPreparation`,
`MachineLearning`) — connectivity, validation, the 10 required engineered
features, and a Random Forest classifier. Trained and evaluated in two
environments: **77.4% accuracy / 71.6% precision / 79.4% recall / 75.3%
F1** locally, **77.3%/72.4%/77.1%/74.7%** on AWS RDS (same algorithm,
independently trained runs, consistent results). All 5,000 customers
scored and predictions stored via `uspStorePredictionResults` in both
environments.

**Joshua (P9) — Power BI Developer**: Connected Power BI to the live
database, diagnosed and worked around a Power BI Service tenant-governance
restriction that blocked scheduled refresh of a cloud data source,
switched to a CSV-based import path, corrected an incorrectly
auto-detected relationship (`Customer.City` ↔ `Store.City` — a false
positive from matching column names, not a real foreign key) before it
could produce misleading cross-filtered numbers, and is building the 6
required dashboards.

## Notes on this submission

This project was completed by a team of one, working through every role
above rather than as separate individual contributions — the per-person
breakdown reflects the actual project's task division, all of which was
carried out directly.
