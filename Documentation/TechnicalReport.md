# Technical Report — Intelligent Customer Campaign Prediction Platform

**Course**: SQL Server Development (ITE-5223), Simulation 8–9
**Company scenario**: MapleMart Canada — 25-store Ontario grocery retailer, MapleRewards loyalty program

---

## 1. Executive Summary

This project builds a full predictive-analytics platform on top of SQL
Server that answers one business question: *which customers are most
likely to respond to MapleMart's next marketing campaign?* A Random Forest
classifier trained on 10 engineered features achieves **77.4% accuracy and
75.3% F1** predicting `PurchaseCompleted`, all 5,000 customers are scored
and the results written back to SQL Server, a local LLM (Mistral, via
Ollama) turns the analytical results into 5 plain-language business
reports, and Power BI dashboards make the results explorable. The platform
was deployed and independently verified in **two separate environments**
(local Docker and AWS RDS SQL Server), and every real data-quality problem
encountered in the source dataset — not hypothetical ones — was found,
documented, and fixed at the schema/load level rather than worked around
downstream.

## 2. Business Problem

MapleMart currently distributes marketing campaigns to broad customer
segments without any way to predict who will actually respond, wasting
spend on customers unlikely to convert and under-targeting customers who
would. The retailer already has the data needed to fix this — five years
of sales, loyalty, and campaign-response history — but no system turns it
into a prediction. The target variable, `CampaignResponse.PurchaseCompleted`,
is a binary label already present in the data; the gap is entirely in
turning historical behavior into a forward-looking targeting list.

## 3. Proposed Solution

A single SQL Server database (`CustomerCampaignAnalytics`) as the system of
record, with three layers on top:

1. **SQL layer** — 13 tables (reference/operational/analytical), 5 views,
   5 functions, 7 stored procedures. `vwCustomerAnalytics` is the one-row-
   per-customer feature table that everything downstream reads from.
2. **Python layer** — pulls `vwCustomerAnalytics`, engineers the 10
   required features, trains/evaluates a classifier, writes predictions
   back via `uspStorePredictionResults`.
3. **AI layer** — Ollama running Mistral locally turns SQL query results
   into 5 required plain-language reports, stored via `uspStoreAIReport`.
   Mistral never queries SQL Server directly and never produces
   predictions — only narrative, and only from data Python hands it.
4. **BI layer** — Power BI reads the views/tables (read-only login) for 6
   dashboards.

Everything is containerized (Docker: SQL Server 2022 + Ollama) and
scripted end-to-end (`scripts/setup.sh`/`setup.ps1`) so the whole platform
is reproducible from a clean clone on macOS, Linux, WSL, or Windows — not
just on the machine it was built on. See `SETUP.md`.

## 4. Database Design

Full detail: `Documentation/ERDiagram.md` (ER diagram + 3NF justification)
and `Documentation/DataDictionary.md` (column-by-column, matching the
deployed schema exactly, not a separate design doc that could drift).

Key design decisions worth calling out:
- **Reference tables** (`LoyaltyLevel`, `PaymentMethod`, `MarketingChannel`,
  `CampaignType`) don't exist as separate source CSVs — their values live
  as plain text inside other files. The load process resolves these
  dynamically (seeds known values, adds any newly-seen one) rather than
  assuming a fixed enum, which mattered in practice: the real data
  contained a `MarketingChannels` value (`Mobile App`) that wasn't in the
  originally seeded list.
- **`LoyaltyMembership` is keyed by `CustomerID` itself**, not a separate
  surrogate, specifically to make a second membership per customer
  structurally impossible (true 1:1 enforcement via the schema, not
  application logic).
- **`SalesTransactionItem` stores its own `UnitPrice`/`Discount`** rather
  than deriving them from `Product` at query time — this looks like
  denormalization but is correct: it's the price *at the time of sale*,
  which can differ from `Product`'s current price.

## 5. SQL Server Implementation

- **5 views**: `vwCustomerAnalytics` (the ML input), `vwCampaignPerformance`,
  `vwSalesPerformance`, `vwCustomerLifetimeValue`, `vwPredictionResults`.
- **5 functions**: `ufnCustomerAge`, `ufnCustomerLifetimeValue`,
  `ufnAveragePurchase`, `ufnCampaignResponseRate`, `ufnDaysSinceLastPurchase`
  — all still exist standalone per spec, though `vwCustomerAnalytics`
  deliberately doesn't call them internally (see §Model Evaluation... no,
  see the performance note below).
- **7 procedures**: `uspLoadDataset`, `uspGenerateCustomerMetrics`,
  `uspRefreshAnalytics`, `uspGeneratePredictionDataset`,
  `uspStorePredictionResults`, `uspStoreAIReport`, `uspCampaignSummary`
  (plus `uspLogModelExecution`).
- **Security**: a `powerbi_reader` SQL login with `SELECT`-only grants on
  the 5 views and the tables Power BI needs — no write access.

**A real performance finding**: the first version of `vwCustomerAnalytics`
called 4 scalar functions once per row (per customer), forcing SQL Server
into a row-by-row execution plan. Measured on AWS RDS:
`SELECT COUNT(*) FROM vwCustomerAnalytics` took **14.557 seconds** for
5,000 rows. Rewriting the same logic as inlined CTEs/joins (no scalar
function calls) brought that to **0.502 seconds — a 29x improvement**,
same output verified row-for-row. Full writeup with additional query
statistics: `Database/Views/PerformanceNotes.md`.

## 6. Data Preparation

Full findings: `Documentation/DataQualityReport.md`. The two significant,
non-obvious issues found in the real source data (not synthetic/assumed
issues):

1. **`SalesTransactions.TransactionTotal` is 0 for all 75,000 source
   rows**, with no exceptions — confirmed via direct inspection of the raw
   CSV, not a load bug. Corrected by recomputing `TransactionTotal` as
   `SUM(LineTotal)` per transaction from `SalesTransactionItem` immediately
   after load, since that table's per-line totals are genuine.
2. **`Customers.Age` is stale for 46 rows (0.9%)** — as low as 17, despite
   `DateOfBirth` implying the customer is 18+, evidently computed once at
   source-data generation and never refreshed. Corrected by recomputing
   `Age` from `DateOfBirth` at load time instead of trusting the source
   column, and `vwCustomerAnalytics` recalculates it independently so it
   can never drift again.

Both fixes are applied at the load-script level (`10_LoadDataset.sql` /
`Python/load_to_rds.py`), not patched over in Python or Power BI, so every
consumer of the data — ML features, views, dashboards — sees the corrected
values automatically.

## 7. Supervised Machine Learning

**Algorithm**: Random Forest (`scikit-learn`), chosen because it handles
the mix of numeric and ordinal-encoded categorical features here without
scaling, tolerates the class imbalance in `PurchaseCompleted` reasonably
well via `class_weight="balanced"`, and exposes feature importances useful
for the marketing-interpretation narrative the AI reports produce.

**10 required features** (`Python/DataPreparation/feature_engineering.py`):
Customer Age, Loyalty Level (ordinal-encoded), Number of Transactions,
Total Amount Spent, Average Purchase Value, Days Since Last Purchase,
Number of Campaigns Received, Campaign Response Rate, Number of Distinct
Products Purchased, Average Discount Received.

**Split**: 80/20, stratified on the target (`PurchaseCompleted` has a
~43-46% positive rate depending on run — stratification keeps that ratio
proportional in both train and test sets, which matters more than usual
given the imbalance isn't extreme but isn't 50/50 either).

**Missing target handling**: 137 of 5,000 customers have no campaign-
response history at all (never contacted), so `PurchaseCompleted` is
undefined for them — these are dropped from training (can't have a label)
but still scored in the final full-customer prediction pass.

## 8. Model Evaluation

Trained and evaluated independently in two environments (same algorithm,
same features, separately-run training):

| Metric | Local Docker | AWS RDS |
|---|---|---|
| Accuracy | 77.4% | 77.3% |
| Precision | 71.6% | 72.4% |
| Recall | 79.4% | 77.1% |
| F1 | 75.3% | 74.7% |

**Business interpretation**:
- **Precision (71.6-72.4%)**: when the model predicts a customer *will*
  respond, it's right roughly 72% of the time — this bounds wasted
  campaign spend on customers who are targeted but won't convert.
- **Recall (77.1-79.4%)**: of customers who would actually respond, the
  model catches ~77-79% of them — this bounds missed-opportunity cost from
  under-targeting.
- **F1 (~75%)**: a reasonable balance between the two — the model is
  usable for real targeting decisions, not just descriptively interesting.

Confusion matrix (local run, test set of 973): 417 true negatives, 133
false positives, 87 false negatives, 336 true positives.

All 5,000 customers scored in the final pass (not just the test split);
**2,278-2,294 customers (45.6-45.9%)** predicted as likely responders,
consistent between the two independent training runs. Predictions stored
via `uspStorePredictionResults`; each run logged via `uspLogModelExecution`
so there's a history of every training attempt, not just the latest.

## 9. Power BI Dashboards

*[Pending — dashboard construction in progress at time of writing. Will be
completed with: screenshots of all 6 required dashboards
(`Images/Dashboard1_Executive.png` through `Dashboard6_AI.png`), the DAX
measures used, and notes on the two supported connection paths (Power BI
Desktop live connection vs. Power BI Service CSV import — the latter
required after a Power BI Service tenant governance policy blocked live
cloud-source refresh; see `Documentation/PowerBI_Setup_Guide.md` §0c for
the full diagnosis and workaround).]*

## 10. Generative AI Usage

Full detail with real prompts and responses: `Documentation/PromptDocumentation.md`.

Platform: Ollama running Mistral 7B locally (no external API, no data
leaves the machine). All 5 required report types generated: Executive
Summary, Campaign Analysis, Prediction Interpretation, Business
Recommendations, Dashboard Commentary — each grounded in real query
results passed into the prompt, never hand-written data.

**Validation caught a real issue**: the first-generation Executive Summary
and Business Recommendations reports both invented a "Q1" timeframe that
was never supplied in the prompt (every actual *number* in both was
correct — the issue was a fabricated framing detail, not fabricated data).
Caught during the required human review step, fixed by revising the
prompt template to explicitly forbid inventing an unsupplied time period
(`PROMPT_VERSION` `v1.0` → `v1.1`), regenerated, and re-verified clean.
All 5 reports are now `Approved = 1` in `AIReport`. This is direct evidence
the "AI content must be team-reviewed before approval" requirement isn't
just a formality here — it caught something real.

## 11. Conclusions

The prototype achieves its core goal: a working prediction pipeline
(~77% accuracy) that identifies likely campaign responders, with the
supporting infrastructure (database, security, AI narration, dashboards)
to make that prediction actually usable by a marketing team rather than
just a notebook exercise. Beyond the assignment requirements, the project
surfaced and fixed real problems that a less-scrutinized build would have
shipped with: a source dataset where a required numeric column was
uniformly wrong, a view with a 29x performance problem, and an LLM
quietly fabricating a detail that happened to be plausible-sounding. All
three were caught by actually querying/measuring/reading the output rather
than assuming success — the same standard applied to the two independent
deployment environments (local Docker, AWS RDS), which exist to prove the
platform is portable rather than accidentally coupled to one machine's
state.

## 12. Recommendations

- **Improve precision** before relying on this for real campaign spend:
  71-72% means roughly 1 in 4 targeted customers won't convert. Feature
  engineering beyond the required 10 (e.g. recency-weighted engagement,
  category-level purchase affinity) is the most likely lever, ahead of
  more complex algorithms.
- **Extend to other prediction targets** per the original spec's future-
  work section: churn prediction (customers going inactive) and sales
  forecasting are natural next targets using the same feature pipeline.
- **Automate the AI-report review step**: currently a manual `Approved`
  flag flip after human read; a lightweight automated check (e.g.
  flagging any number/date in the response that doesn't appear in the
  input data) could catch fabrication issues like the one found here
  without waiting for manual review to notice it.
- **Revisit the Power BI Service tenant-governance constraint** for any
  future deployment expecting live-refreshing cloud dashboards — the CSV
  fallback used here is a reasonable workaround for a course submission
  but isn't a substitute for a properly gateway-configured or
  Pro-licensed setup in a real production rollout.
