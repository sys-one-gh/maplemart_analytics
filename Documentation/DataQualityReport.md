# Data Quality Report

Findings from loading and validating the real MapleMart dataset (10 CSVs,
350,858 total rows) into `CustomerCampaignAnalytics`, both locally and on
AWS RDS. Every finding below was confirmed by direct query against the
loaded data, not assumed.

## 1. Missing values

None found. All 10 source CSVs have every field populated for every row
(verified via `grep -c ',,'` across all files pre-load, and via
`Database/Validation/12_Validation.sql` post-load). No nullable
business-critical column (Email, Phone, Address) came back empty.

## 2. Duplicate records

- **CustomerID, TransactionID, TransactionItemID, ResponseID, LoyaltyNumber**:
  zero duplicates in any of these primary/business keys.
- **Email**: **41 customers (0.82%) share an email address with another
  customer** (e.g. `aclark@example.org` appears on more than one row). This
  is a genuine source-data collision, not a load error - real households
  sometimes do share an email, so `dbo.Customer.Email` is intentionally
  **not** a unique constraint (see `CK`/index comments in
  `Database/Constraints/05_CreateConstraints.sql`); enforcing uniqueness
  would have meant silently dropping real customer rows during load.

## 3. Orphan foreign keys

Zero, across every relationship checked:
`SalesTransaction.CustomerID -> Customer`,
`SalesTransactionItem.{TransactionID, ProductID}`,
`CampaignResponse.{CampaignID, CustomerID}`. Confirmed via
`12_Validation.sql`, re-run after every load.

## 4. Outliers / value-range issues

Two real, non-trivial data quality problems in the source CSVs - both
confirmed via direct calculation, not guessed, and both corrected during
load (`Database/DatabaseCreation/10_LoadDataset.sql` /
`Python/load_to_rds.py`):

- **`SalesTransactions.csv` → `TransactionTotal` is 0 for all 75,000 rows**,
  with no exceptions. Verified with
  `awk -F',' '{print $6}' SalesTransactions.csv | sort -u` -> single value,
  `0`. Since `SalesTransactionItems.csv` has real per-line totals, the load
  process **recomputes `TransactionTotal` as `SUM(LineTotal)` per
  transaction** immediately after loading the line items, rather than
  trusting the source column. Every downstream feature/view/dashboard that
  depends on transaction value (CLV, average purchase, sales performance)
  uses the recomputed value.
- **`Customers.csv` → `Age` is stale for 46 rows (0.9%)**, all under the
  spec's minimum age of 18 (as low as 17) despite `DateOfBirth` implying the
  customer is currently 18+. The `Age` column was evidently computed once at
  source-data generation time and never refreshed. The load process
  **recomputes `Age` from `DateOfBirth` as of load time** instead of
  trusting the source column (confirmed this drops the under-18 count to
  zero). `dbo.vwCustomerAnalytics` independently recalculates age from
  `DateOfBirth` too, so this can never drift again regardless of when the
  view is queried.

## 5. Type / format consistency

- **`SalesTransactionItems.Discount` is a flat dollar amount, not a
  percentage** - confirmed by checking the arithmetic directly:
  `LineTotal = Quantity * UnitPrice - Discount` holds exactly across sampled
  rows (e.g. `Qty=2, UnitPrice=52.07, Discount=20.83 -> LineTotal=83.31`,
  matching `104.14 - 20.83`). This is easy to misread as a percent given the
  similarly-named `MarketingCampaign.DiscountPercent`; documented explicitly
  in the schema comments to avoid confusion downstream.
- **`PostalCode` formatting is inconsistent**: 2,516 of 5,000 customers have
  a 6-character code with no space (`E5P1P8`), 2,484 have the standard
  7-character format with a space (`K7B 5N2`). Both fit in `CHAR(7)`
  (6-char values are simply space-padded); not corrected, since it's
  display formatting, not a data integrity issue.
- **Dates**: all ISO `YYYY-MM-DD` (or `YYYY-MM-DDTHH:MM:SS`), parse cleanly,
  no ambiguity.
- **Boolean-ish columns** (`EmailOpened`, `CouponUsed`, `PurchaseCompleted`
  in `CampaignResponses.csv`): consistently `0`/`1`, no stray values.
- **`CustomerStatus`**: every row in the real dataset is `Active` - the
  schema supports `Inactive`/`Suspended` (per spec) but the source data
  happens not to exercise those values.
- **`MarketingCampaigns.Channel`**: real distinct values are `Email`,
  `SMS`, `Mobile App` - notably includes `Mobile App`, which isn't in a
  fixed enum anywhere; the load process dynamically adds any not-yet-seen
  channel/payment-method/loyalty-level to its lookup table rather than
  assuming a fixed static list, so this required no manual fix.

## Summary

Of 350,858 loaded rows, the two structurally significant issues
(`TransactionTotal`, stale `Age`) affected 100% and 0.9% of their respective
tables and are both corrected at load time with the fix documented in the
loading script itself. Everything else is either zero findings or a cosmetic
formatting inconsistency (`PostalCode`) that doesn't affect correctness.
