"""One-off loader for cloud SQL Server targets (e.g. AWS RDS) where BULK
INSERT isn't available because the server has no filesystem access to the
CSVs. Same end result as Database/DatabaseCreation/10_LoadDataset.sql
(staged lookup resolution, FK-safe order, TransactionTotal recompute), just
inserting row-by-batch over the network via pyodbc instead.

Usage:
    python Python/load_to_rds.py --server HOST,1433 --user admin --password '...' --database CustomerCampaignAnalytics
"""
import argparse
from pathlib import Path

import pandas as pd
import pyodbc

REPO_ROOT = Path(__file__).resolve().parent.parent
DATASET_DIR = REPO_ROOT / "Dataset"

CLEAR_ORDER = ["CustomerPrediction", "AIReport", "CampaignResponse", "SalesTransactionItem",
               "SalesTransaction", "MarketingCampaign", "LoyaltyMembership", "Employee",
               "Product", "Customer", "Store", "ProductCategory"]


def get_conn(server, user, password, database):
    cs = (f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={server};DATABASE={database};"
          f"UID={user};PWD={password};Encrypt=yes;TrustServerCertificate=yes;")
    return pyodbc.connect(cs, autocommit=True)


def clean(df):
    return df.where(pd.notnull(df), None)


def load_direct(cursor, table, filename, columns):
    df = clean(pd.read_csv(DATASET_DIR / filename))[columns]
    rows = list(df.itertuples(index=False, name=None))
    placeholders = ",".join(["?"] * len(columns))
    cursor.executemany(f"INSERT INTO dbo.{table} ({','.join(columns)}) VALUES ({placeholders})", rows)
    print(f"  {table}: {len(rows)} rows")


def resolve_lookup(cursor, table, name_col, id_col, values):
    existing = {r[0]: r[1] for r in cursor.execute(f"SELECT {name_col}, {id_col} FROM dbo.{table}").fetchall()}
    missing = set(values) - set(existing.keys())
    for name in missing:
        cursor.execute(f"INSERT INTO dbo.{table} ({name_col}) VALUES (?)", name)
    if missing:
        existing = {r[0]: r[1] for r in cursor.execute(f"SELECT {name_col}, {id_col} FROM dbo.{table}").fetchall()}
    return existing


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True)
    parser.add_argument("--user", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--database", default="CustomerCampaignAnalytics")
    args = parser.parse_args()

    conn = get_conn(args.server, args.user, args.password, args.database)
    cursor = conn.cursor()
    cursor.fast_executemany = True

    print("Clearing existing data...")
    for tbl in CLEAR_ORDER:
        cursor.execute(f"DELETE FROM dbo.{tbl}")

    load_direct(cursor, "Store", "Stores.csv", ["StoreID", "StoreName", "City", "Province"])
    load_direct(cursor, "ProductCategory", "ProductCategories.csv", ["CategoryID", "CategoryName"])
    load_direct(cursor, "Product", "Products.csv",
                ["ProductID", "ProductName", "CategoryID", "Brand", "UnitPrice", "UnitCost"])
    print("Loading Customer (recomputing Age from DateOfBirth - source Age is stale, see CK_Customer_Age)...")
    df = clean(pd.read_csv(DATASET_DIR / "Customers.csv"))
    dob = pd.to_datetime(df["DateOfBirth"])
    df["Age"] = ((pd.Timestamp("today") - dob).dt.days // 365).astype(int)
    columns = ["CustomerID", "FirstName", "LastName", "Gender", "DateOfBirth", "Age", "Email", "Phone",
               "Address", "City", "Province", "PostalCode", "RegistrationDate", "CustomerStatus"]
    rows = list(df[columns].itertuples(index=False, name=None))
    cursor.executemany(
        f"INSERT INTO dbo.Customer ({','.join(columns)}) VALUES ({','.join(['?']*len(columns))})", rows)
    print(f"  Customer: {len(rows)} rows")
    load_direct(cursor, "Employee", "Employees.csv", ["EmployeeID", "FirstName", "LastName", "Role", "StoreID"])

    print("Loading LoyaltyMembership (resolving MembershipLevel)...")
    df = clean(pd.read_csv(DATASET_DIR / "LoyaltyMemberships.csv"))
    levels = resolve_lookup(cursor, "LoyaltyLevel", "LevelName", "LoyaltyLevelID", df["MembershipLevel"].unique())
    rows = [(r.CustomerID, r.LoyaltyNumber, levels[r.MembershipLevel], r.JoinDate, r.CurrentPoints,
              r.LifetimePointsEarned, r.LifetimePointsRedeemed) for r in df.itertuples()]
    cursor.executemany(
        "INSERT INTO dbo.LoyaltyMembership (CustomerID, LoyaltyNumber, LoyaltyLevelID, JoinDate, "
        "CurrentPoints, LifetimePointsEarned, LifetimePointsRedeemed) VALUES (?,?,?,?,?,?,?)", rows)
    print(f"  LoyaltyMembership: {len(rows)} rows")

    print("Loading MarketingCampaign (resolving Channel, deriving CampaignType)...")
    df = clean(pd.read_csv(DATASET_DIR / "MarketingCampaigns.csv"))
    channels = resolve_lookup(cursor, "MarketingChannel", "ChannelName", "MarketingChannelID", df["Channel"].unique())
    types = {r[0]: r[1] for r in cursor.execute("SELECT TypeName, CampaignTypeID FROM dbo.CampaignType").fetchall()}

    def derive_type(pct):
        if pct >= 30: return types["Deep Discount"]
        if pct >= 15: return types["Standard Discount"]
        if pct > 0: return types["Loyalty/Retention"]
        return types["Awareness"]

    rows = [(r.CampaignID, r.CampaignName, channels[r.Channel], derive_type(r.DiscountPercent),
              r.StartDate, r.EndDate, r.DiscountPercent) for r in df.itertuples()]
    cursor.executemany(
        "INSERT INTO dbo.MarketingCampaign (CampaignID, CampaignName, MarketingChannelID, CampaignTypeID, "
        "StartDate, EndDate, DiscountPercent) VALUES (?,?,?,?,?,?,?)", rows)
    print(f"  MarketingCampaign: {len(rows)} rows")

    print("Loading SalesTransaction (resolving PaymentMethod)...")
    df = clean(pd.read_csv(DATASET_DIR / "SalesTransactions.csv"))
    pms = resolve_lookup(cursor, "PaymentMethod", "MethodName", "PaymentMethodID", df["PaymentMethod"].unique())
    rows = [(r.TransactionID, r.CustomerID, r.StoreID, r.TransactionDate, pms[r.PaymentMethod], r.TransactionTotal)
             for r in df.itertuples()]
    cursor.executemany(
        "INSERT INTO dbo.SalesTransaction (TransactionID, CustomerID, StoreID, TransactionDate, "
        "PaymentMethodID, TransactionTotal) VALUES (?,?,?,?,?,?)", rows)
    print(f"  SalesTransaction: {len(rows)} rows")

    load_direct(cursor, "SalesTransactionItem", "SalesTransactionItems.csv",
                ["TransactionItemID", "TransactionID", "ProductID", "Quantity", "UnitPrice", "Discount", "LineTotal"])
    load_direct(cursor, "CampaignResponse", "CampaignResponses.csv",
                ["ResponseID", "CampaignID", "CustomerID", "EmailOpened", "CouponUsed", "PurchaseCompleted",
                 "PurchaseAmount", "ResponseDate"])

    print("Recomputing TransactionTotal from line items (source data has it as 0)...")
    cursor.execute("""
        UPDATE st SET st.TransactionTotal = ISNULL(agg.LineSum, 0)
        FROM dbo.SalesTransaction st
        CROSS APPLY (
            SELECT SUM(LineTotal) AS LineSum FROM dbo.SalesTransactionItem sti WHERE sti.TransactionID = st.TransactionID
        ) agg
    """)

    print("Done.")
    conn.close()


if __name__ == "__main__":
    main()
