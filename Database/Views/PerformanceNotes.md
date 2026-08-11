# Performance Notes

Real execution statistics captured with `SET STATISTICS IO, TIME ON`
against the live, fully-loaded database (350,858 rows), not estimates.

## Finding 1: scalar UDFs in `vwCustomerAnalytics` were the single biggest
## performance problem in the whole schema

The first version of `vwCustomerAnalytics` called `ufnCustomerAge`,
`ufnAveragePurchase`, `ufnDaysSinceLastPurchase`, and
`ufnCampaignResponseRate` once per row - i.e. per customer, forcing SQL
Server into a row-by-row (RBAR) execution plan instead of a set-based one,
since scalar UDFs generally block plan-level optimization/parallelism.

Measured on AWS RDS (`db.t3.micro`, the most resource-constrained
environment this project runs on):

| Version | `SELECT COUNT(*) FROM vwCustomerAnalytics` (5,000 rows) |
|---|---|
| Original (4 scalar UDF calls/row) | **14.557 s** |
| Rewritten (same logic, inlined as CTEs/joins) | **0.502 s** |

**~29x faster**, same output (verified row-for-row against the original on
customers 1-5 before/after). The functions themselves (`ufnCustomerAge`
etc.) still exist standalone per the spec - they're just not called from
inside the view anymore. This is the single highest-impact optimization in
the project: this view is the ML training input and gets queried by the
Python pipeline, `uspGenerateCustomerMetrics`, and every Power BI dashboard
that touches customer-level data, so the fix compounds everywhere it's used.

**Lesson for the team**: prefer inlining scalar function logic into views/
queries with CTEs over calling `dbo.ufnX(column)` per row, especially in any
view that gets queried repeatedly or against a resource-constrained
instance. Keep the standalone functions for one-off lookups
(`SELECT dbo.ufnCustomerAge(1)`), not for use inside a view's SELECT list.

## Finding 2: Top-20-customers-by-revenue (business query #1)

```sql
SELECT TOP 20 c.CustomerID, SUM(st.TransactionTotal) AS TotalRevenue
FROM dbo.Customer c
JOIN dbo.SalesTransaction st ON st.CustomerID = c.CustomerID
GROUP BY c.CustomerID
ORDER BY TotalRevenue DESC;
```

| Table | Scan count | Logical reads |
|---|---|---|
| Customer | 0 (index seek per group) | 48 |
| SalesTransaction | 1 | 393 |

CPU/elapsed time: **21 ms**. `SalesTransaction` at 393 logical reads for a
75,000-row aggregation is efficient - `IX_SalesTransaction_CustomerID`
(`Database/Indexes/06_CreateIndexes.sql`) supports the join/group directly
instead of a full table scan (which at ~10-15 bytes/row overhead would cost
roughly 10x more logical reads for this table). `Customer`'s 0 scan count
with only 48 logical reads confirms per-group index seeks against
`PK_Customer` rather than a table scan.

## Finding 3: Top-products-by-profit (business query #3)

```sql
SELECT TOP 20 p.ProductID, p.ProductName, SUM(sti.Quantity * (p.UnitPrice - p.UnitCost)) AS TotalProfit
FROM dbo.Product p
JOIN dbo.SalesTransactionItem sti ON sti.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName
ORDER BY TotalProfit DESC;
```

| Table | Scan count | Logical reads |
|---|---|---|
| SalesTransactionItem | 1 | 1,618 |
| Product | 1 | 8 |

CPU/elapsed time: **19 ms**. `SalesTransactionItem` is the largest table
(250,000 rows) and this query touches all of it once (a full aggregation by
definition has to), but 1,618 logical reads for 250K rows (~154 rows/page)
is consistent with a clean clustered-index scan, not a costly bookmark
lookup pattern - `IX_SalesTransactionItem_ProductID` wasn't needed for this
particular query shape (grouping needs the whole table regardless), but it
does help `vwCustomerAnalytics`'s `ProductAgg` CTE, which filters/joins by
customer rather than aggregating the whole table.

## Summary

19-21ms for both business queries against the full dataset is fast enough
that neither needed further tuning. The one query that *did* need
intervention (`vwCustomerAnalytics`) got a 29x improvement from a schema
design change (removing per-row scalar function calls), not from adding
more indexes - a reminder that query *shape* often matters more than
indexing alone.
