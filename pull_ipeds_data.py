import requests
import pandas as pd
import time

BASE_URL = "https://educationdata.urban.org/api/v1"
ILLINOIS_FIPS = 17
PUBLIC_2YEAR_SECTOR = 4  # IPEDS sector code for "Public, 2-year"

def fetch_all_pages(url):
    """Follows the API's pagination ('next' key) until all pages are collected."""
    all_results = []
    while url:
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()
        all_results.extend(data["results"])
        url = data.get("next")
        time.sleep(0.2)  # be polite to the API, avoid hammering it
    return all_results

def pull_directory(start_year, end_year):
    """Institution characteristics: name, sector, state — one call per year."""
    all_records = []
    for year in range(start_year, end_year + 1):
        url = f"{BASE_URL}/college-university/ipeds/directory/{year}/?fips={ILLINOIS_FIPS}&sector={PUBLIC_2YEAR_SECTOR}"
        try:
            records = fetch_all_pages(url)
            print(f"Directory {year}: {len(records)} institutions")
            all_records.extend(records)
        except requests.exceptions.HTTPError as e:
            print(f"Directory {year}: skipped ({e})")
    return pd.DataFrame(all_records)

def pull_enrollment(start_year, end_year):
    """Fall enrollment by race and sex, for undergraduates."""
    all_records = []
    for year in range(start_year, end_year + 1):
        url = f"{BASE_URL}/college-university/ipeds/fall-enrollment/{year}/undergraduate/race/sex/?fips={ILLINOIS_FIPS}"
        try:
            records = fetch_all_pages(url)
            print(f"Enrollment {year}: {len(records)} records")
            all_records.extend(records)
        except requests.exceptions.HTTPError as e:
            print(f"Enrollment {year}: skipped ({e})")
    return pd.DataFrame(all_records)

def pull_completions(start_year, end_year):
    """Completions by CIP code (6-digit) — broad category, not detailed program."""
    all_records = []
    for year in range(start_year, end_year + 1):
        url = f"{BASE_URL}/college-university/ipeds/completions-cip-6/{year}/?fips={ILLINOIS_FIPS}&sector={PUBLIC_2YEAR_SECTOR}"
        try:
            records = fetch_all_pages(url)
            print(f"Completions {year}: {len(records)} records")
            all_records.extend(records)
        except requests.exceptions.HTTPError as e:
            print(f"Completions {year}: skipped ({e})")
    return pd.DataFrame(all_records)

if __name__ == "__main__":
    START_YEAR = 1986
    END_YEAR = 2024

    print("=== Pulling directory data ===")
    directory_df = pull_directory(START_YEAR, END_YEAR)
    directory_df.to_csv("raw_directory.csv", index=False)

    print("\n=== Pulling enrollment data ===")
    enrollment_df = pull_enrollment(START_YEAR, END_YEAR)
    enrollment_df.to_csv("raw_enrollment.csv", index=False)

    print("\n=== Pulling completions data ===")
    completions_df = pull_completions(START_YEAR, END_YEAR)
    completions_df.to_csv("raw_completions.csv", index=False)

    print("\nDone. Check raw_directory.csv, raw_enrollment.csv, raw_completions.csv")