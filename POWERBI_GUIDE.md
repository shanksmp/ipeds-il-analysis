# Building the Power BI dashboard

## Why this is a manual, browser-based process

Power BI Desktop is Windows-only, so this uses **Power BI Service**
(app.powerbi.com) instead. Power BI Service normally reaches a database
live via an **On-premises Data Gateway** — but that gateway is also
Windows-only software, so it can't run on this Mac to expose the local
`ipeds_il` Postgres database to the cloud service. Rather than stand up
a separate cloud-hosted database just for this, the path here is: import
`ipeds_il_summary.xlsx` directly. Every sheet in it is already a
decoded, correctly-scoped, pre-aggregated analysis table (built by
`build_excel_workbook.py` from the SQL views in `sql/analysis/`), so no
relationship-building or DAX is required to get started — just import
and chart.

**Tradeoff:** this is a snapshot, not a live connection. To refresh with
new data: re-run `python3 build_excel_workbook.py`, then re-upload the
file in Power BI Service (steps below cover both first upload and
refresh).

## 1. Upload the workbook

1. Go to [app.powerbi.com](https://app.powerbi.com) and sign in.
2. Open (or create) a workspace for this project.
3. **New → Upload a file → Local File** → select `ipeds_il_summary.xlsx`.
4. Choose **Import** (not "Upload" the raw file for viewing) so Power BI
   creates a dataset and report from it.
5. Power BI will list each Excel sheet as a table in the dataset. Rename
   the auto-generated report/dataset to something like
   `IL Community College Enrollment & Completions`.

## 2. Recommended report pages

Build these as separate pages in one report. Field names below match the
Excel sheet's column headers exactly.

### Page 1 — Statewide Enrollment Trend
- **Line chart**: X = `year`, Y = `total_enrollment`, `full_time_enrollment`,
  `part_time_enrollment` (three series), from the **Enrollment Trend
  (Statewide)** table.
- **Card**: latest year's `total_enrollment`, and a second card for
  `yoy_pct_change` (use "Don't summarize" / "First" as the aggregation —
  this column is already a computed rate per year, so summing it across
  years is meaningless).
- Add a text box calling out the 2009 peak and the ~36% decline to 2023
  (see README.md for the exact figures) — the "so what," not just the line.

### Page 2 — Institution Comparison
- Table/matrix from **Enrollment by Institution**: rows = `inst_name`,
  columns = `year`, values = `total_enrollment`.
- Add a slicer on `year` (pick two years, e.g. 2010 and 2023) and a bar
  chart of `yoy_pct_change` by `inst_name` sorted ascending to surface
  the biggest decliners (Wabash Valley, Rend Lake, John A. Logan, etc.
  per the README).

### Page 3 — Completions Trend
- **Line chart**: X = `year`, Y = `total_completions`, from
  **Completions Trend (Statewide)**.
- **Stacked bar/area chart**: X = `year`, Y = `completions`, Legend =
  `award_level`, from **Completions by Award Level**.
- Consider a combo visual overlaying enrollment and completions trends
  (needs both tables on one visual, or a relationship between them on
  `year` — Power BI can relate two tables on a shared `year` column even
  though they came from different Excel sheets: **Model view → drag
  `year` from one table to `year` on the other** to create the
  relationship) to visually make the "enrollment down, completions up"
  finding pop.

### Page 4 — Demographic Composition
- **100% stacked area or bar chart**: X = `year`, Y = `enrollment`,
  Legend = `race_group_comparable`, from **Enrollment Demog
  (Comparable)** — this is the pre/post-2010-adjusted view, safe to show
  as one continuous trend.
- Add a note/text box citing the 2010 IPEDS category change (from
  README.md), and optionally a second, smaller visual from **Enrollment
  Demog (Raw)** filtered to 2008–2012 specifically to show the
  discontinuity for anyone who wants the underlying detail.
- Repeat both visuals for completions using the **Completions Demog**
  sheets if page space allows, or as a second report page.

### Page 5 (optional) — Completions by Program
- Bar chart from **Completions by Award Level** or a custom visual
  against `cipcode_6digit` from the underlying `v_completions_top_programs`
  SQL view (not currently in the Excel export) — CIP codes aren't
  decoded to program names yet; note this as a known gap if you build
  this page rather than presenting bare numeric codes as if they were
  self-explanatory.

## 3. Formatting notes

- Use a consistent color per demographic group across every page
  (Power BI does this automatically as long as the field name/values
  match across visuals — `race_group_comparable` values are identical
  across the enrollment and completions comparable sheets).
- Pin the enrollment trend and completions trend visuals to a dashboard
  (**Pin visual** from each report page) for an at-a-glance summary view
  separate from the full report.

## 4. Refreshing with new data

1. `python3 pull_ipeds_data.py` / `backfill_missing.py` for new years.
2. Re-run the load and analysis SQL (see README.md "Reproducing this").
3. `python3 build_excel_workbook.py`.
4. In Power BI Service: open the dataset → **Datasets → (this dataset) →
   ⋯ → Update dataset** (or delete and re-upload if the sheet structure
   changed) — existing reports/dashboards built on it will pick up the
   refreshed numbers automatically.
