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

## Terminology, so "how many dashboards do I need" has a clean answer

Power BI overloads the word "dashboard." What you're building is one
**report** with several **pages** (tabs along the bottom of one report,
like sheets in Excel) — that's what the sections below call "Page 1,
Page 2," etc. A Power BI **dashboard** is a separate, different object:
a single canvas of tiles **pinned** from report pages, used for an
at-a-glance view across pages. You need **one report with 5 pages**
(below), and optionally **one dashboard** at the end that pins the 3-4
best visuals from across those pages — not five separate dashboards.

## 0. Apply the visual theme first

`powerbi/theme.json` in this repo is a validated color theme: 8
categorical colors ordered so adjacent pairs stay distinguishable under
the three common forms of colorblindness (not eyeballed — computed and
checked against contrast/separation thresholds), plus consistent
background/text colors and reserved green/red "good/bad" colors for KPI
cards. Applying it once fixes color for every page and visual you build
afterward, rather than fighting Power BI's default rainbow palette
visual-by-visual.

1. Open the report → **View** tab → **Themes** → **Browse for themes**.
2. Select `powerbi/theme.json`.
3. Every new visual you add now pulls from this palette automatically.

This matters more than it sounds: it's the single biggest thing that
makes a Power BI report look "designed" instead of "default," and it's
zero effort once applied.

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
- On the `yoy_pct_change` card, add **conditional formatting** (the fx
  icon next to Callout Value in the Format pane) so the number renders
  green when positive, red when negative — Power BI's default theme
  won't pick colors that mean anything, but `theme.json` reserves
  `good`/`bad` specifically for this: rule 1 uses `#0ca30c` (good) when
  value ≥ 0, rule 2 uses `#d03b3b` (bad) when value < 0. This is a status
  color, not a category color — it should be the *only* red/green on the
  page, reserved for exactly this meaning.
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
- **Do not** build this as a combo chart with enrollment on a second
  y-axis, even though Power BI offers that option and it's tempting for
  the "enrollment down, completions up" finding. Two independent
  y-scales on one plot is a real, well-documented chart mistake (a
  classic case: a chart plotting one series 0-30k against another
  0-800k on the same plot was flagged by reviewers as "hallucinating" a
  correlation) — the alignment between the two axes is arbitrary, so the
  visual overstates or invents how tightly the two trends actually
  relate. Do this instead: **index both series to a common base.** Add a
  calculated column/measure in each table: `Indexed = [value] /
  CALCULATE([value], year = <first year>) * 100`, then plot both
  indexed series on **one** shared axis (both start at 100). This is a
  standard, honest way to compare two series of different scale and
  actually makes the divergence more visually obvious, not less.

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

### Page 5 — Completions by Program
- Horizontal bar chart from **Completions by Program**: Axis =
  `cip_title` (filter/Top N to the top 15-20 by `total_completions` —
  there are 683 programs total, too many to chart at once), Value =
  `total_completions`. This surfaces the actual program mix (Liberal
  Arts and Sciences, Nursing, Automotive Technology, etc. — see
  README.md for the top-5 list) instead of bare numeric codes.
- The `cip_edition` column shows which NCES CIP taxonomy edition
  (1985/1990/2000/2010) supplied each title — worth a tooltip or a small
  note if a reviewer asks why a niche program's title looks dated;
  titles for codes retired before the current edition come from
  whichever edition last defined them, per the caveat in README.md.

## 3. What makes it look designed instead of default

Roughly in order of how much visual difference each one makes for how
little effort it takes:

1. **Apply `theme.json` before building anything** (step 0 above) — the
   single highest-leverage thing here.
2. **Turn off gridlines, or make them barely visible.** Format pane →
   your line/bar chart → **Gridlines** → either off, or set the color to
   a near-surface gray (`#e1e0d9`) at low weight. Power BI's default
   gridlines are heavier than they need to be and read as clutter, not
   structure.
3. **One consistent color per category, everywhere it appears.**
   `race_group_comparable` values are identical across the enrollment
   and completions sheets, so Power BI will assign them the same colors
   automatically *as long as you don't manually override colors on only
   one visual*. Don't hand-pick a color for "White" on one chart and
   leave the rest on auto — either theme it everywhere or nowhere.
   Never let a slicer/filter change which color means which category
   (Power BI does this correctly by default — avoid "Rank by color"
   options if any custom visual offers them).
4. **A legend on every multi-series chart, none on single-series ones.**
   Skip a legend only when there's exactly one line/series — the title
   already says what it is.
5. **No pie or donut charts for the demographic breakdowns.** Eight
   categories on a pie is unreadable regardless of color; the stacked
   bar/area recommended above is the right form for composition-over-time.
   Reserve a donut (if you use one anywhere) for a single part-to-whole
   snapshot with 6 or fewer segments.
6. **Don't label every data point.** Power BI defaults to no data labels
   on lines, which is correct — leave it that way and let the tooltip
   (hover) carry the exact value. If you do add labels, do it selectively
   (just the latest point, or just the peak), not on every year.
7. **Consistent card style.** Format pane → **Effects** → same corner
   radius and same subtle shadow (or none) on every Card/KPI visual on a
   page. Mismatched card styles on one page is one of the fastest ways a
   report reads as "assembled" rather than "designed."
8. **Put slicers/filters in one row, same position on every page** — top
   of the canvas, not scattered. Consistent placement is what makes
   multi-page navigation feel coherent rather than like five separate
   reports stapled together.
9. **Generous whitespace over dense packing.** Resist the urge to fill
   every pixel — 3-4 well-sized visuals per page reads better than 6-7
   cramped ones. If a page feels crowded, that's a sign it should be two
   pages.
10. **Pin the 3-4 best visuals to an actual Power BI dashboard**
    (**Pin visual** from each report page, per the terminology note
    above) as a true at-a-glance summary separate from the full report —
    do this last, once the report pages themselves are settled, so
    you're not re-pinning after every layout change.

## 4. Refreshing with new data

1. `python3 pull_ipeds_data.py` / `backfill_missing.py` for new years.
2. Re-run the load and analysis SQL (see README.md "Reproducing this").
3. `python3 build_excel_workbook.py`.
4. In Power BI Service: open the dataset → **Datasets → (this dataset) →
   ⋯ → Update dataset** (or delete and re-upload if the sheet structure
   changed) — existing reports/dashboards built on it will pick up the
   refreshed numbers automatically.
