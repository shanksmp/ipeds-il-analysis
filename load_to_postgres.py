import math

import pandas as pd
import psycopg2
from psycopg2.extras import execute_values

DB_CONFIG = {
    "dbname": "ipeds_il",
    "user": "shanks",
    "host": "localhost",
    "port": 5432
}


def to_db_rows(df):
    """Convert a DataFrame to row tuples with real Python None for missing
    values, instead of NaN.

    df.where(pd.notnull(df), None) alone doesn't work: pandas coerces the
    None right back to NaN in any numeric column, so NaN was still reaching
    Postgres. That crashes on integer columns ("integer out of range", since
    Postgres has no integer NaN) and silently loads as float NaN in numeric
    columns instead of NULL.
    """
    df = df.astype(object).where(pd.notnull(df), None)
    rows = []
    for row in df.itertuples(index=False, name=None):
        rows.append(tuple(
            None if isinstance(x, float) and math.isnan(x)
            else (x.item() if hasattr(x, "item") else x)
            for x in row
        ))
    return rows


def load_institutions(conn):
    df = pd.read_csv("raw_directory.csv")
    cols = ["unitid", "year", "inst_name", "city", "state_abbr", "zip",
            "county_name", "sector", "longitude", "latitude", "currently_active_ipeds"]
    df = df[cols]

    rows = to_db_rows(df)
    with conn.cursor() as cur:
        cur.execute("TRUNCATE institutions")  # clear before reload, avoids duplicate runs
        execute_values(
            cur,
            f"INSERT INTO institutions ({', '.join(cols)}) VALUES %s",
            rows
        )
    conn.commit()
    print(f"Loaded {len(rows)} institution rows")

def load_enrollment(conn):
    df = pd.read_csv("raw_enrollment.csv")
    cols = ["unitid", "year", "ftpt", "level_of_study", "degree_seeking",
            "class_level", "sex", "race", "enrollment_fall"]
    df = df[cols]

    rows = to_db_rows(df)
    with conn.cursor() as cur:
        cur.execute("TRUNCATE enrollment")
        execute_values(
            cur,
            f"INSERT INTO enrollment ({', '.join(cols)}) VALUES %s",
            rows
        )
    conn.commit()
    print(f"Loaded {len(rows)} enrollment rows")

def load_completions(conn):
    df = pd.read_csv("raw_completions.csv")
    cols = ["unitid", "year", "cipcode_6digit", "award_level",
            "majornum", "race", "sex", "awards_6digit"]
    df = df[cols]

    rows = to_db_rows(df)
    with conn.cursor() as cur:
        cur.execute("TRUNCATE completions")
        execute_values(
            cur,
            f"INSERT INTO completions ({', '.join(cols)}) VALUES %s",
            rows,
            page_size=5000  # insert in batches, since this table has 300k+ rows
        )
    conn.commit()
    print(f"Loaded {len(rows)} completions rows")

if __name__ == "__main__":
    conn = psycopg2.connect(**DB_CONFIG)
    try:
        load_institutions(conn)
        load_enrollment(conn)
        load_completions(conn)
    finally:
        conn.close()
    print("Done.")