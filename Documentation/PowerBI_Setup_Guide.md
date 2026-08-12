# Power BI Setup Guide

Power BI Desktop is Windows-only (no Mac client, no CLI) - this part has to be
built by hand inside the app. This doc gives you the exact connection steps
and the full dashboard/DAX spec so it's a checklist, not a blank page.

## 0. Prerequisites

- Power BI Desktop (Windows). On a Mac: run it in a Windows VM (Parallels,
  UTM, Boot Camp) or a Windows machine on the same network.
- The `sqlserver` container running (`docker compose up -d` / `./scripts/setup.sh`)
  and the dataset loaded.

## 0b. Building on Windows, viewing later in Chrome

Power BI Desktop is Windows-only, and Power BI **Service** (app.powerbi.com,
the browser version) runs in Microsoft's cloud - it cannot reach a database
on your local network without installing the "On-premises Data Gateway"
(also Windows-only, a separate piece of infrastructure). The practical path
that gets you a Chrome-viewable dashboard **without** setting up a gateway:

1. Build the report in **Power BI Desktop on your Windows machine**, using
   **Import** mode (see step 4 below) - this pulls a snapshot of the data
   into the `.pbix` file itself, rather than querying SQL Server live.
2. If Docker is running on your Mac and Power BI Desktop is on a separate
   Windows VM/PC, point Desktop at your Mac's LAN IP instead of `localhost`:
   on the Mac run `ipconfig getifaddr en0` (or check System Settings ->
   Wi-Fi/Network for your IP), then use `<that-ip>,1433` as the server in
   step 1 below. Docker already publishes the port on all interfaces
   (`0.0.0.0:1433`), so this works as long as both machines are on the same
   network/VM host-network and nothing is firewalling port 1433.
3. File -> **Publish** -> pick your workspace on app.powerbi.com.
4. Open **app.powerbi.com in Chrome** (any machine, including your Mac) and
   sign in - your published report is there, fully interactive (slicers,
   drill-through, cross-filtering all work in the browser).

Because it's Import mode, this view is a snapshot as of when you last
published - clicking "Refresh" in the Service *would* need the gateway, but
for a course submission a static, current snapshot is normal and expected.
Re-publish from Desktop any time your data changes.

## 0c. Alternative: AWS RDS + Power BI Service, fully in Chrome (no Windows at all)

This is the path we actually used when no Windows machine/VM was available.
Instead of local Docker, the database runs on a small AWS RDS SQL Server
Express instance (free tier), which Power BI Service can query directly from
the browser - no gateway, no Desktop, no VM, because Power BI's backend
servers reach RDS over the internet the same way they'd reach Azure SQL.

**One-time setup (already done for this project - here for reference/reuse):**
1. RDS -> Create database -> Standard create -> Engine: **Microsoft SQL
   Server**, Edition: **SQL Server Express Edition**, Template: **Free tier**.
2. Connectivity: **Public access: Yes** (required, or nothing outside AWS can
   reach it - not even Power BI).
3. Security group inbound rule: allow **TCP 1433**. Source needs to cover
   Power BI Service's cloud IPs, not your own - in practice this means either
   `0.0.0.0/0` (all IPs; only acceptable because a strong password still
   gates actual login - never do this with a weak/reused password) or
   Microsoft's published Azure/Power BI IP ranges (more setup, more secure).
4. Run the schema against the endpoint directly (no Docker needed - `sqlcmd`
   or any SQL client works once public access + the security group are set):
   ```
   sqlcmd -S <endpoint>,1433 -U admin -P '<password>' -C -No -b -i Database/DatabaseCreation/01_CreateDatabase.sql
   # ...same for 02 through 09, in the order listed in section 1 below...
   sqlcmd -S <endpoint>,1433 -U admin -P '<password>' -C -No -b -v PowerBiPassword='<pbi-password>' -i Database/Security/11_CreateSecurity.sql
   ```
5. Load the data with **`Python/load_to_rds.py`** instead of
   `10_LoadDataset.sql` - RDS has no filesystem access for `BULK INSERT` to
   read local CSVs from, so this script inserts the same data over the
   network via `pyodbc` instead:
   ```
   .venv/bin/python Python/load_to_rds.py --server <endpoint>,1433 --user admin --password '<password>' --database CustomerCampaignAnalytics
   ```
   This is noticeably slower than local `BULK INSERT` (network round-trips
   vs. a server-side file read) - budget 10-15 minutes for the full dataset
   on a free-tier `db.t3.micro` instance.

**Connecting from Power BI Service (app.powerbi.com) in Chrome:**
1. Sign in -> **Create** -> **Get data from other sources** -> **SQL Server database**.
2. Server: `<endpoint>,1433` (comma before the port). Database: `CustomerCampaignAnalytics`.
3. Data gateway: `(none)`.
4. Authentication kind: **Basic** - Username `admin` (or the `powerbi_reader`
   read-only login), Password as set above.
5. **If you get "unable to connect using an encrypted connection"**: uncheck
   **"Use encrypted connection"** and try again - this is a known quirk
   connecting to RDS's certificate from Power BI's connector; unchecking it
   is safe here since the connection is already password-gated and this
   isn't sensitive production data.
6. Select the 5 views + tables listed in section 1 below, click **"Transform
   data"**, then **"Create a report"** - name the semantic model, pick **My
   workspace**, Create.

**How teammates without their own RDS instance see the finished dashboard:**
They don't need database access at all. Once the report is built (Import
mode bakes the data into it), use Power BI Service's **export/download to
`.pbix`** and commit that file as `PowerBI/CustomerCampaignAnalytics.pbix` in
the repo - anyone can open it (Desktop, or upload to their own free Power BI
account) with zero credentials needed. Only the person actively *building*
the dashboards needs live RDS access; everyone else just needs the finished
file. Keeping the RDS instance running/public indefinitely isn't necessary
once that export is done - delete or lock down the instance afterward.

## 1. Connect (local Docker path)

1. Get Data -> **SQL Server**.
2. Server: `localhost,<SQLSERVER_PORT from .env>` (usually `localhost,1433` - check `.env` in case the setup script had to auto-pick a different port)
   - If Power BI is running on a **different machine/VM** than Docker (e.g.
     Parallels), `localhost` means the VM itself - use the host Mac's LAN IP
     instead (`ipconfig getifaddr en0` on the Mac), and make sure port 1433
     is reachable from the VM (Parallels' default "Shared Network" usually
     handles this automatically).
3. Database: `CustomerCampaignAnalytics`
4. Data Connectivity mode: **Import** is simplest for a class project (static
   snapshot, fast visuals). DirectQuery works too if you want live data on
   every refresh - either is fine, just document which one you picked.
5. Authentication: **Database** (SQL Server auth)
   - User: `powerbi_reader`
   - Password: the `POWERBI_READER_PASSWORD` value from your local `.env`
     (never share this file/value outside the team)
6. In the Navigator, select:
   - Tables: `Customer`, `Product`, `ProductCategory`, `Store`,
     `SalesTransaction`, `SalesTransactionItem`, `MarketingCampaign`,
     `CampaignResponse`, `CustomerPrediction`, `AIReport`, `ModelExecution`
   - Views: `vwCustomerAnalytics`, `vwCampaignPerformance`,
     `vwSalesPerformance`, `vwCustomerLifetimeValue`, `vwPredictionResults`
7. Load, then open **Model view** and check the relationships Power BI
   auto-detected (FK columns match the DB's FKs, e.g.
   `SalesTransaction.CustomerID` -> `Customer.CustomerID`). Fix anything it
   missed manually.

## 2. The 6 Required Dashboards

### Dashboard 1 - Executive Overview
KPI cards: Total Customers, Active Customers, Total Sales, Average Purchase
Value, Total Marketing Campaigns, Campaign Response Rate, Prediction Accuracy
(from `ModelExecution`), AI Report Generation Date (from `AIReport`).
Visuals: monthly sales trend (line), customer distribution by province
(map/bar), campaign response trend (line), AI executive summary text panel
(`AIReport.ReportText` where `ReportType = 'Executive Summary'`).

### Dashboard 2 - Customer Analytics
Age distribution (histogram), loyalty level distribution (donut), customer
lifetime value (bar, top N from `vwCustomerLifetimeValue`), average purchase
amount (card/bar), purchase frequency (bar), days since last purchase
(histogram) - all from `vwCustomerAnalytics`.

### Dashboard 3 - Sales Performance
Monthly sales (line), revenue by store (bar/map), revenue by category (tree
map), revenue by product (bar, top N), average transaction value (card) -
from `vwSalesPerformance` and `SalesTransactionItem`.

### Dashboard 4 - Marketing Campaign Performance
Customers contacted per campaign (bar), response rate (bar/funnel), purchase
completion rate (funnel), average purchase amount per campaign, revenue per
campaign, campaign ranking table - all from `vwCampaignPerformance`.

### Dashboard 5 - Machine Learning Dashboard
Confusion matrix (matrix visual - values are in `Python/Logs/pipeline.log`
after a training run, or recompute from `vwPredictionResults`), accuracy/
precision/recall/F1 KPI cards (from `ModelExecution`, most recent row),
predicted-positive count (card/gauge), probability distribution (histogram
of `CustomerPrediction.PredictionProbability`).

### Dashboard 6 - Artificial Intelligence Dashboard
Text panels for each of the 5 `AIReport.ReportText` values (Executive
Summary, Campaign Analysis, Prediction Interpretation, Business
Recommendations, Dashboard Commentary), with nav buttons/tabs between them,
plus a table of all reports with `GeneratedDate` and `Approved`.
Requires the AI reports to exist first - run
`Ollama.report_generator.generate_all_reports()` (needs `./scripts/setup.sh --with-ai`
to have pulled the `mistral` model first).

## 3. DAX Measures (minimum set - add more as needed)

```
Total Revenue = SUM(SalesTransaction[TransactionTotal])
Average Purchase Value = AVERAGE(SalesTransaction[TransactionTotal])
Campaign Response Rate = DIVIDE(SUM(CampaignResponse[PurchaseCompleted]), COUNTROWS(CampaignResponse))
Average Discount = AVERAGE(SalesTransactionItem[Discount])
Total Predicted Responders = CALCULATE(COUNTROWS(CustomerPrediction), CustomerPrediction[PredictionResult] = "Yes")
Prediction Accuracy = CALCULATE(MAX(ModelExecution[Accuracy]), TOPN(1, ModelExecution, ModelExecution[ExecutionDate], DESC))
```

Document every custom measure you add (name, formula, purpose) at the bottom
of this file as you build.

## 4. Interactivity checklist

- [ ] Slicers on at least province, date range, campaign
- [ ] Cross-filtering works between visuals on the same page
- [ ] At least one drill-through (e.g. click a campaign in Dashboard 4 ->
      drill into that campaign's customer-level detail)
- [ ] Tables are sortable
- [ ] Consistent color scheme/titles across all 6 pages

## 5. Validation (before submitting)

1. Close and reopen the `.pbix`, refresh, confirm every visual loads with no
   errors and no impossible numbers (negative revenue, >100% rates).
2. Test every slicer and the drill-through.
3. Screenshot each of the 6 dashboards (full page) into `Images/`, named
   `Dashboard1_Executive.png` ... `Dashboard6_AI.png`.
4. Save the file as `PowerBI/CustomerCampaignAnalytics.pbix`.

---
*Custom DAX measures added beyond section 3 (fill in as you build):*
