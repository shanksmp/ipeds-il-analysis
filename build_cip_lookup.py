"""
Generates sql/lookup_cip_code.sql -- decodes the numeric cipcode_6digit
column (completions) into program titles.

Our completions data spans 1986-2023, during which NCES revised the CIP
(Classification of Instructional Programs) taxonomy four times: 1985,
1990, 2000, and 2010 editions (a 2020 edition also exists but its file
isn't fetchable without a JS-driven download, so it's not included here;
2020-2023 completions fall back to the 2010-edition title, which is
correct for the large majority of codes since revisions mostly add new
codes rather than redefine existing ones).

Using only the current (2010) edition covers just 47.8% of actual award
volume in our data -- the other editions are genuinely necessary, not
optional polish. Sources, official NCES:
    2010 edition: https://nces.ed.gov/ipeds/cipcode/Files/CIPCode2010.csv
    1985/1990/2000 editions (archived together):
        http://nces.ed.gov/pubs2002/cip2000/xls/cip.zip

MERGE STRATEGY / CAVEAT: this builds one lookup table by layering
editions oldest to newest (1985 -> 1990 -> 2000 -> 2010), so a code gets
the title from the newest edition that defines it, falling back to older
editions for codes later retired. This maximizes coverage and is correct
for the common case (a code's meaning is stable across the editions that
define it). It is NOT verified row-by-row for the rarer case of NCES
reassigning a numeric code to a materially different program across
editions -- the `cip_edition` column on each row records which edition
actually supplied the title, so that can be audited if a specific code's
history matters for an analysis.
"""
import csv
import io
import re
import zipfile

import requests
import xlrd

CIP2010_URL = "https://nces.ed.gov/ipeds/cipcode/Files/CIPCode2010.csv"
LEGACY_ZIP_URL = "http://nces.ed.gov/pubs2002/cip2000/xls/cip.zip"


def strip_excel_text_quote(v):
    """CIPCode2010.csv wraps text fields as ="value" to stop Excel from
    eating leading zeros -- undo that."""
    v = v or ""
    m = re.match(r'^="?(.*?)"?$', v)
    return m.group(1) if m else v


def fetch_2010():
    resp = requests.get(CIP2010_URL, timeout=30)
    resp.raise_for_status()
    reader = csv.DictReader(io.StringIO(resp.content.decode("utf-8-sig")))
    out = {}
    for row in reader:
        code = strip_excel_text_quote(row["CIPCode"])
        if re.match(r"^\d{2}\.\d{4}$", code):
            out[int(code.replace(".", ""))] = strip_excel_text_quote(row["CIPTitle"]).strip()
    return out


def fetch_legacy():
    resp = requests.get(LEGACY_ZIP_URL, timeout=30)
    resp.raise_for_status()
    zf = zipfile.ZipFile(io.BytesIO(resp.content))
    xls_bytes = zf.read(zf.namelist()[0])
    wb = xlrd.open_workbook(file_contents=xls_bytes)

    def col_index(sheet, name):
        header = sheet.row_values(0)
        return header.index(name)

    editions = {}

    # CIP1985 and CIP1990 sheets already carry a precomputed CIPNODOT
    # column in exactly our integer encoding.
    for sheet_name, edition in [("CIP1985", "1985"), ("CIP1990", "1990")]:
        sh = wb.sheet_by_name(sheet_name)
        code_col = col_index(sh, "CIPNODOT")
        title_col = col_index(sh, "CIPTITLE")
        out = {}
        for r in range(1, sh.nrows):
            raw_code = sh.row_values(r)[code_col]
            title = str(sh.row_values(r)[title_col]).strip()
            if not title:
                continue
            try:
                out[int(float(raw_code))] = title
            except (ValueError, TypeError):
                continue
        editions[edition] = out

    # CIP2000 sheet has no nodot column and includes retired-code rows
    # (CIPCode == "-----", meaning "report under" a different code) --
    # skip those, they have no code of their own to key on.
    sh = wb.sheet_by_name("CIP2000")
    code_col = col_index(sh, "CIPCode")
    title_col = col_index(sh, "CIPTITLE")
    out = {}
    for r in range(1, sh.nrows):
        code = str(sh.row_values(r)[code_col]).strip()
        if re.match(r"^\d{2}\.\d{4}$", code):
            out[int(code.replace(".", ""))] = str(sh.row_values(r)[title_col]).strip()
    editions["2000"] = out

    return editions


def sql_escape(s):
    return s.replace("'", "''")


def main():
    print(f"Fetching {CIP2010_URL} ...")
    ed_2010 = fetch_2010()
    print(f"  {len(ed_2010)} codes")

    print(f"Fetching {LEGACY_ZIP_URL} ...")
    legacy = fetch_legacy()
    for ed, d in legacy.items():
        print(f"  CIP{ed}: {len(d)} codes")

    # Layer oldest -> newest so the newest edition that defines a code
    # wins, while codes retired by later editions still fall back to
    # whichever edition last had them.
    merged = {}
    for edition, table in [
        ("1985", legacy["1985"]),
        ("1990", legacy["1990"]),
        ("2000", legacy["2000"]),
        ("2010", ed_2010),
    ]:
        for code, title in table.items():
            merged[code] = (title, edition)

    print(f"Merged: {len(merged)} unique codes")

    lines = [
        "-- Decodes cipcode_6digit into program titles.",
        "--",
        "-- Sourced from NCES's own CIP code dictionaries across all four",
        "-- editions that could apply to our 1986-2023 data (1985, 1990,",
        "-- 2000, 2010 -- see build_cip_lookup.py for exact source URLs and",
        "-- the merge strategy / caveats, especially around the 2020 CIP",
        "-- edition not being included and codes NCES may have reassigned",
        "-- across editions). cip_edition records which edition's title",
        "-- won for each code.",
        "--",
        "-- Auto-generated by build_cip_lookup.py. Do not hand-edit --",
        "-- rerun the script instead.",
        "",
        "DROP TABLE IF EXISTS lookup_cip_code;",
        "CREATE TABLE lookup_cip_code (",
        "    code        integer PRIMARY KEY,",
        "    title       text NOT NULL,",
        "    cip_edition text NOT NULL",
        ");",
        "INSERT INTO lookup_cip_code (code, title, cip_edition) VALUES",
    ]
    value_lines = [
        f"    ({code}, '{sql_escape(title)}', '{edition}')"
        for code, (title, edition) in sorted(merged.items())
    ]
    lines.append(",\n".join(value_lines) + ";")
    lines.append("")

    out_path = "sql/lookup_cip_code.sql"
    with open(out_path, "w") as f:
        f.write("\n".join(lines))
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
