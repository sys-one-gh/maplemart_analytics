"""Generates the 10 MapleMart CSVs with the schema/row counts documented in
README.md, when the real course-provided dataset isn't available yet.

This is placeholder data only - swap it for the real CSVs by dropping them
into Dataset/ (same filenames) and skipping this script.

Usage:
    python Python/generate_synthetic_dataset.py [--scale 1.0] [--seed 42]

--scale lets you shrink everything for a fast local smoke test, e.g.
--scale 0.05 generates about 5% of the full row counts.
"""
import argparse
import csv
import os
import random
from datetime import date, datetime, timedelta

import numpy as np

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUTPUT_DIR = os.path.join(REPO_ROOT, "Dataset")

CANADIAN_CITIES = [
    ("Toronto", "Ontario"), ("Ottawa", "Ontario"), ("Mississauga", "Ontario"),
    ("Hamilton", "Ontario"), ("London", "Ontario"), ("Kitchener", "Ontario"),
    ("Windsor", "Ontario"), ("Vaughan", "Ontario"), ("Markham", "Ontario"),
    ("Brampton", "Ontario"), ("Barrie", "Ontario"), ("Kingston", "Ontario"),
    ("Guelph", "Ontario"), ("Sudbury", "Ontario"), ("Oshawa", "Ontario"),
]
FIRST_NAMES = ["James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
               "William", "Elizabeth", "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
               "Thomas", "Sarah", "Charles", "Karen", "Priya", "Wei", "Fatima", "Ahmed", "Sofia",
               "Liam", "Noah", "Emma", "Olivia", "Ava"]
LAST_NAMES = ["Smith", "Brown", "Tremblay", "Martin", "Roy", "Wilson", "MacDonald", "Taylor",
              "Campbell", "Anderson", "Patel", "Chen", "Khan", "Singh", "Nguyen", "Kim",
              "Gagnon", "Lee", "Walker", "White", "Clark", "Lewis", "Young", "King"]
CATEGORY_NAMES = ["Produce", "Dairy", "Bakery", "Meat & Seafood", "Frozen Foods", "Pantry",
                   "Beverages", "Snacks", "Health & Beauty", "Household", "Baby Care", "Pet Care",
                   "Deli", "Condiments", "Cereal & Breakfast", "Canned Goods", "Alcohol", "Organic"]
BRANDS = ["MapleMart Choice", "Northern Harvest", "GreatValue", "PrimeSelect", "PureCanada",
          "FreshField", "EveryDay", "Heritage Farms", "TrueNorth", "Homestead"]
EMPLOYEE_ROLES = ["Cashier", "Store Manager", "Assistant Manager", "Stock Clerk", "Customer Service"]
# Names below MUST match the seed values in Database/Tables/02_CreateReferenceTables.sql
CHANNELS = ["Email", "SMS", "Social Media", "Direct Mail", "Push Notification"]
PAYMENT_METHODS = ["Cash", "Credit Card", "Debit Card", "Mobile Payment"]
LOYALTY_LEVELS = ["Bronze", "Silver", "Gold", "Platinum"]
LOYALTY_WEIGHTS = [0.45, 0.30, 0.18, 0.07]


def write_csv(filename, header, rows):
    path = os.path.join(OUTPUT_DIR, filename)
    with open(path, "w", newline="\n", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)
    print(f"  wrote {filename}: {len(rows):,} rows")


def random_date(start: date, end: date, rng: random.Random) -> date:
    delta = (end - start).days
    return start + timedelta(days=rng.randint(0, max(delta, 0)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--scale", type=float, default=1.0)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    np.random.seed(args.seed)
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    def n(count):
        return max(1, int(round(count * args.scale)))

    n_stores, n_categories, n_products = n(25), len(CATEGORY_NAMES), n(500)
    n_customers, n_employees, n_campaigns = n(5000), n(250), n(40)
    n_transactions, n_items, n_responses = n(75000), n(250000), n(18000)

    print(f"Generating synthetic MapleMart dataset (scale={args.scale}) into {OUTPUT_DIR}")

    # --- Stores ------------------------------------------------------------
    stores = []
    for sid in range(1, n_stores + 1):
        city, prov = rng.choice(CANADIAN_CITIES)
        stores.append((sid, f"MapleMart {city} #{sid}", city, prov))
    write_csv("Stores.csv", ["StoreID", "StoreName", "City", "Province"], stores)

    # --- ProductCategories ---------------------------------------------------
    categories = [(i + 1, name) for i, name in enumerate(CATEGORY_NAMES)]
    write_csv("ProductCategories.csv", ["CategoryID", "CategoryName"], categories)

    # --- Products ------------------------------------------------------------
    products = []
    for pid in range(1, n_products + 1):
        cat_id = rng.randint(1, n_categories)
        cost = round(rng.uniform(0.75, 35.0), 2)
        price = round(cost * rng.uniform(1.25, 1.8), 2)
        products.append((pid, f"{CATEGORY_NAMES[cat_id-1]} Item {pid}", cat_id, rng.choice(BRANDS), price, cost))
    write_csv("Products.csv", ["ProductID", "ProductName", "CategoryID", "Brand", "UnitPrice", "UnitCost"], products)

    # --- Customers -------------------------------------------------------
    today = date.today()
    customers = []
    for cid in range(1, n_customers + 1):
        first, last = rng.choice(FIRST_NAMES), rng.choice(LAST_NAMES)
        dob = today - timedelta(days=rng.randint(18 * 365, 85 * 365))
        age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
        city, prov = rng.choice(CANADIAN_CITIES)
        reg_date = random_date(date(2019, 1, 1), today, rng)
        status = rng.choices(["Active", "Inactive", "Suspended"], weights=[0.85, 0.12, 0.03])[0]
        postal = f"{rng.choice('ABCEGHJKLMNPRSTVXY')}{rng.randint(0,9)}{rng.choice('ABCEGHJKLMNPRSTVWXYZ')} {rng.randint(0,9)}{rng.choice('ABCEGHJKLMNPRSTVWXYZ')}{rng.randint(0,9)}"
        customers.append((
            cid, first, last, rng.choice(["Male", "Female", "Non-binary"]),
            dob.isoformat(), age, f"{first.lower()}.{last.lower()}{cid}@example.com",
            f"416-555-{rng.randint(1000,9999)}", f"{rng.randint(10,9999)} {last} St", city, prov, postal,
            reg_date.isoformat(), status,
        ))
    write_csv("Customers.csv", ["CustomerID", "FirstName", "LastName", "Gender", "DateOfBirth", "Age",
                                 "Email", "Phone", "Address", "City", "Province", "PostalCode",
                                 "RegistrationDate", "CustomerStatus"], customers)
    customer_ids = [c[0] for c in customers]
    customer_regdate = {c[0]: date.fromisoformat(c[11]) for c in customers}

    # --- LoyaltyMemberships (1:1 with Customer) -----------------------------------
    loyalty = []
    for cid in customer_ids:
        level = rng.choices(LOYALTY_LEVELS, weights=LOYALTY_WEIGHTS)[0]
        join_date = random_date(customer_regdate[cid], today, rng)
        earned = rng.randint(0, 20000)
        redeemed = rng.randint(0, earned)
        loyalty.append((f"LM{cid:06d}", cid, level, join_date.isoformat(), earned - redeemed, earned, redeemed))
    write_csv("LoyaltyMemberships.csv", ["LoyaltyNumber", "CustomerID", "MembershipLevel", "JoinDate",
                                          "CurrentPoints", "LifetimePointsEarned", "LifetimePointsRedeemed"], loyalty)

    # --- Employees ---------------------------------------------------------
    employees = []
    for eid in range(1, n_employees + 1):
        employees.append((eid, rng.choice(FIRST_NAMES), rng.choice(LAST_NAMES),
                           rng.choice(EMPLOYEE_ROLES), rng.randint(1, n_stores)))
    write_csv("Employees.csv", ["EmployeeID", "FirstName", "LastName", "Role", "StoreID"], employees)

    # --- MarketingCampaigns --------------------------------------------------
    campaigns = []
    for camp_id in range(1, n_campaigns + 1):
        start = random_date(date(2024, 1, 1), today - timedelta(days=14), rng)
        end = start + timedelta(days=rng.randint(7, 30))
        campaigns.append((camp_id, f"Campaign {camp_id:03d} - {rng.choice(CATEGORY_NAMES)} Promo",
                           rng.choice(CHANNELS), start.isoformat(), end.isoformat(),
                           round(rng.uniform(0, 50), 2)))
    write_csv("MarketingCampaigns.csv", ["CampaignID", "CampaignName", "Channel", "StartDate", "EndDate",
                                          "DiscountPercent"], campaigns)
    campaign_ids = [c[0] for c in campaigns]
    campaign_dates = {c[0]: (date.fromisoformat(c[3]), date.fromisoformat(c[4])) for c in campaigns}

    # --- SalesTransactions + SalesTransactionItems (generated together so
    #     TransactionTotal always equals the sum of its line items) -----------
    product_price = {p[0]: p[4] for p in products}
    txn_start, txn_end = date(2024, 1, 1), today
    transactions, items = [], []
    item_id = 1
    remaining_items = n_items
    for tid in range(1, n_transactions + 1):
        cust = rng.choice(customer_ids)
        store = rng.randint(1, n_stores)
        tdate = datetime.combine(random_date(txn_start, txn_end, rng), datetime.min.time()) \
            + timedelta(hours=rng.randint(8, 21), minutes=rng.randint(0, 59))
        payment = rng.choice(PAYMENT_METHODS)

        items_left_for_txns = n_transactions - tid + 1
        max_here = max(1, remaining_items - (items_left_for_txns - 1))
        n_line_items = min(max_here, rng.randint(1, 8))
        remaining_items -= n_line_items

        total = 0.0
        for _ in range(n_line_items):
            pid = rng.randint(1, n_products)
            qty = rng.randint(1, 5)
            unit_price = product_price[pid]
            # Discount is a flat dollar amount off the line, not a percent
            # (matches the real MapleMart dataset's semantics).
            discount = round(rng.choice([0, 0, 0, 1, 2, 3, 5, 8]) * qty * rng.uniform(0.5, 1.5), 2)
            line_total = round(max(qty * unit_price - discount, 0), 2)
            items.append((item_id, tid, pid, qty, unit_price, discount, line_total))
            total += line_total
            item_id += 1

        transactions.append((tid, cust, store, tdate.strftime("%Y-%m-%dT%H:%M:%S"), payment, round(total, 2)))

    write_csv("SalesTransactions.csv", ["TransactionID", "CustomerID", "StoreID", "TransactionDate",
                                         "PaymentMethod", "TransactionTotal"], transactions)
    write_csv("SalesTransactionItems.csv", ["TransactionItemID", "TransactionID", "ProductID", "Quantity",
                                             "UnitPrice", "Discount", "LineTotal"], items)

    # --- CampaignResponses ---------------------------------------------------
    responses = []
    for rid in range(1, n_responses + 1):
        camp_id = rng.choice(campaign_ids)
        cust = rng.choice(customer_ids)
        opened = rng.random() < 0.55
        coupon_used = opened and rng.random() < 0.35
        purchased = coupon_used and rng.random() < 0.6 or (not coupon_used and rng.random() < 0.08)
        amount = round(rng.uniform(15, 250), 2) if purchased else 0.0
        cstart, cend = campaign_dates[camp_id]
        rdate = datetime.combine(random_date(cstart, cend + timedelta(days=5), rng), datetime.min.time())
        responses.append((rid, camp_id, cust, int(opened), int(coupon_used), int(purchased), amount,
                           rdate.strftime("%Y-%m-%dT%H:%M:%S")))
    write_csv("CampaignResponses.csv", ["ResponseID", "CampaignID", "CustomerID", "EmailOpened", "CouponUsed",
                                         "PurchaseCompleted", "PurchaseAmount", "ResponseDate"], responses)

    print("Done.")


if __name__ == "__main__":
    main()
