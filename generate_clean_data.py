"""
generate_clean_data.py
Builds the cleaned tables from the raw CSVs, in one command.
(generate_data.py creates the raw, messy CSVs; this script loads them into
PostgreSQL and produces the clean tables.)

What it does:

    1. schema.sql              -> creates the four raw tables (drops old ones first)
    2. users/subscriptions/payments/events .csv -> loads them into those tables
    3. sql/02_cleaning.sql     -> builds the *_clean tables and payments_quarantine
    4. prints a reconciliation table (raw rows vs clean rows)

All the cleaning logic lives in sql/02_cleaning.sql. This script only runs it,
so the SQL stays the single source of truth.

Requirements:  pip install psycopg2-binary
Before running: create the database and run generate_data.py to make the CSVs.

Connection details come from environment variables, so no password is stored
in this file. Either set one URL:

    export DATABASE_URL="postgresql://USER:PASSWORD@localhost:5432/subscription_analytics"

or the standard PostgreSQL variables (PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD).
On Windows PowerShell use:  $env:DATABASE_URL = "postgresql://..."

Usage:
    python generate_clean_data.py               # full rebuild: schema, load, clean
    python generate_clean_data.py --skip-load   # keep the raw tables, only re-run the cleaning
"""
import argparse
import os
import sys
from pathlib import Path

import psycopg2

HERE = Path(__file__).resolve().parent

# CSV file -> raw table it is loaded into (order does not matter: no foreign keys)
CSV_TO_TABLE = {
    "users.csv": "users",
    "subscriptions.csv": "subscriptions",
    "payments.csv": "payments",
    "events.csv": "events",
}


def run_sql_file(cur, path):
    """Run every statement in a .sql file."""
    print(f"  running {path.relative_to(HERE)}")
    cur.execute(path.read_text(encoding="utf-8"))


def load_csv(cur, csv_name, table):
    """Bulk-load one CSV into its table with COPY (much faster than INSERT).
    In CSV mode an empty, unquoted field becomes NULL, which is what we want
    for the deliberately missing emails, subscription IDs and end dates."""
    path = HERE / csv_name
    if not path.exists():
        sys.exit(f"Missing {csv_name}. Run:  python generate_data.py")
    with open(path, encoding="utf-8") as f:
        cur.copy_expert(f"COPY {table} FROM STDIN WITH (FORMAT csv, HEADER true)", f)
    cur.execute(f"SELECT COUNT(*) FROM {table}")
    print(f"  loaded {cur.fetchone()[0]:>8,} rows into {table}")


def count(cur, table):
    cur.execute(f"SELECT COUNT(*) FROM {table}")
    return cur.fetchone()[0]


def reconciliation(cur):
    """Raw vs clean row counts, so every removed row is accounted for."""
    print("\nReconciliation (raw -> clean)")
    print(f"  {'table':<15}{'raw':>10}{'clean':>10}{'removed':>10}")
    for raw, clean in [("users", "users_clean"),
                       ("subscriptions", "subscriptions_clean"),
                       ("events", "events_clean"),
                       ("payments", "payments_clean")]:
        r, c = count(cur, raw), count(cur, clean)
        print(f"  {raw:<15}{r:>10,}{c:>10,}{r - c:>10,}")
    print(f"\n  payments_quarantine holds {count(cur, 'payments_quarantine'):,} raw "
          "payment rows that could not be matched to a valid user or subscription.")


def main():
    parser = argparse.ArgumentParser(description="Build the project database.")
    parser.add_argument("--skip-load", action="store_true",
                        help="do not recreate/load the raw tables; only re-run the cleaning SQL")
    args = parser.parse_args()

    # An empty connection string makes psycopg2 read the PG* environment variables.
    conn = psycopg2.connect(os.environ.get("DATABASE_URL", ""))
    try:
        with conn, conn.cursor() as cur:   # the 'with conn' block commits on success
            if not args.skip_load:
                print("Step 1: create raw tables (any existing raw tables are dropped)")
                run_sql_file(cur, HERE / "schema.sql")
                print("Step 2: load CSV files")
                for csv_name, table in CSV_TO_TABLE.items():
                    load_csv(cur, csv_name, table)
            print("Step 3: clean the data")
            run_sql_file(cur, HERE / "sql" / "02_cleaning.sql")
            reconciliation(cur)
    finally:
        conn.close()
    print("\nDone. The *_clean tables are ready for sql/03 to sql/07.")


if __name__ == "__main__":
    main()
