import requests
import pandas as pd
import time

BASE_URL = "https://educationdata.urban.org/api/v1"
ILLINOIS_FIPS = 17
PUBLIC_2YEAR_SECTOR = 4

def fetch_all_pages(url, max_retries=3):
    """Same as before, but retries a failed page a few times before giving up."""
    all_results = []
    while url:
        for attempt in range(max_retries):
            try:
                response = requests.get(url, timeout=30)
                response.raise_for_status()
                break
            except requests.exceptions.RequestException as e:
                if attempt < max_retries - 1:
                    print(f"  Retry {attempt + 1}/{max_retries} for {url} ({e})")
                    time.sleep(3)  # give the server a moment before retrying
                else:
                    raise
        data = response.json()
        all_results.extend(data["results"])
        url = data.get("next")
        time.sleep(0.2)
    return all_results

def backfill_enrollment_year(year):
    url = f"{BASE_URL}/college-university/ipeds/fall-enrollment/{year}/undergraduate/race/sex/?fips={ILLINOIS_FIPS}"
    records = fetch_all_pages(url)
    print(f"Enrollment {year}: {len(records)} records (backfilled)")
    return pd.DataFrame(records)

def backfill_completions_year(year):
    url = f"{BASE_URL}/college-university/ipeds/completions-cip-6/{year}/?fips={ILLINOIS_FIPS}&sector={PUBLIC_2YEAR_SECTOR}"
    records = fetch_all_pages(url)
    print(f"Completions {year}: {len(records)} records (backfilled)")
    return pd.DataFrame(records)

if __name__ == "__main__":
    # --- Enrollment gaps ---
    existing_enrollment = pd.read_csv("raw_enrollment.csv")
    new_enrollment_frames = []

    for year in [2009, 2010]:
        try:
            new_enrollment_frames.append(backfill_enrollment_year(year))
        except requests.exceptions.RequestException as e:
            print(f"Enrollment {year}: still failing after retries ({e})")

    if new_enrollment_frames:
        combined_enrollment = pd.concat([existing_enrollment] + new_enrollment_frames, ignore_index=True)
        combined_enrollment.to_csv("raw_enrollment.csv", index=False)
        print("raw_enrollment.csv updated.")

    # --- Completions gaps ---
    existing_completions = pd.read_csv("raw_completions.csv")
    new_completions_frames = []

    for year in [2009, 2024]:
        try:
            new_completions_frames.append(backfill_completions_year(year))
        except requests.exceptions.RequestException as e:
            print(f"Completions {year}: still failing after retries ({e})")
            if year == 2024:
                print("  Note: 2024 completions data may not be published yet (IPEDS completions typically lag 12-18+ months) -- this might not be a bug.")

    if new_completions_frames:
        combined_completions = pd.concat([existing_completions] + new_completions_frames, ignore_index=True)
        combined_completions.to_csv("raw_completions.csv", index=False)
        print("raw_completions.csv updated.")

    print("\nBackfill complete.")