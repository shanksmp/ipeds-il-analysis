import pandas as pd

df = pd.read_csv("raw_directory.csv")

cols = [
    "unitid",
    "year",
    "inst_name",
    "city",
    "state_abbr",
    "zip",
    "county_name",
    "sector",
    "longitude",
    "latitude",
    "currently_active_ipeds",
]

df = df[cols]

INT_MIN = -2147483648
INT_MAX = 2147483647

print("\n--- DTYPES ---")
print(df.dtypes)

print("\n--- NUMERIC RANGES ---")

for col in cols:
    numeric = pd.to_numeric(df[col], errors="coerce")

    if numeric.notna().any():
        print(
            f"{col:30} "
            f"min={numeric.min():20} "
            f"max={numeric.max():20}"
        )

print("\n--- INTEGER OVERFLOW CHECK ---")

for col in cols:
    numeric = pd.to_numeric(df[col], errors="coerce")

    bad = df[
        (numeric < INT_MIN) |
        (numeric > INT_MAX)
    ]

    if not bad.empty:
        print(f"\nPROBLEM COLUMN: {col}")
        print(f"Rows outside INTEGER range: {len(bad)}")
        print(
            df.loc[bad.index, ["unitid", "year", col]]
            .head(30)
            .to_string(index=False)
        )