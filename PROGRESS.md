# Progress — Illinois Community College Enrollment & Completion Analysis

Last updated: 2026-09-24

## Done

- **Data pull** (`pull_ipeds_data.py`) — directory, fall-enrollment (race/sex), and
  completions-cip-6, IL, 1986–2024 (2024 completions not yet published by IPEDS).
  Paginated, retried, rate-limited.
- **Backfill** (`backfill_missing.py`) — recovered 2009–2010 enrollment and 2009
  completions after transient 524s; correctly left 2024 completions unfilled
  (genuine data-availability gap, not a bug).
- **Postgres load** (`load_to_postgres.py`) — loads all three CSVs into `ipeds_il`.
  Fixed a real bug: `df.where(pd.notnull(df), None)` silently reverts to `NaN` on
  numeric pandas columns, which crashed the `institutions` load
  (`integer out of range`) and would have written `NaN` instead of `NULL` into
  `longitude`, `enrollment_fall`, `award_level`, `majornum`. Replaced with a
  `to_db_rows()` helper that casts to `object` dtype first. Verified against the
  live DB — row counts match the CSVs exactly and previously-NaN cells are now
  real `NULL`:
  | table | rows |
  |---|---|
  | institutions | 1,927 |
  | enrollment | 3,577,298 |
  | completions | 9,355,053 |
- **`sql/schema.sql`** — schema-only dump of the three fact tables, committed
  (previously existed only in the live DB, undocumented and unreproducible).
- **Scope-leak diagnosis and fix** (`sql/views.sql`) — `enrollment` and
  `completions` are statewide (608 / 572 institutions), not community-college-only,
  despite the pull script trying to filter completions by `sector=4`. Confirmed
  directly against Urban Institute's own endpoint metadata that `sector` isn't a
  filterable field on either endpoint at all — the API silently ignores the query
  param rather than erroring. Fixed downstream instead of re-pulling: added
  `v_il_cc_enrollment` / `v_il_cc_completions`, which join to `institutions` on
  `(unitid, year)` so only rows for years an institution was actually classified
  Public-two-year survive:
  | | raw rows | scoped rows | institutions |
  |---|---|---|---|
  | enrollment | 3,577,298 | 874,925 | 62 of 63 |
  | completions | 9,355,053 | 2,634,225 | 58 of 63 |

  Raw statewide tables are kept (not deleted) as a possible comparison baseline,
  but all analysis/Power BI/Excel work should build on the scoped views unless a
  statewide comparison is intentionally wanted.
- **Code lookup tables** (`build_code_lookups.py` → `sql/lookup_tables.sql`) —
  10 dimension tables (`lookup_race`, `lookup_sex`, `lookup_ftpt`,
  `lookup_level_of_study`, `lookup_degree_seeking`, `lookup_class_level`,
  `lookup_award_level`, `lookup_majornum`, `lookup_sector`,
  `lookup_currently_active_ipeds`) decoding every numeric category code used in
  the fact tables. Sourced programmatically from Urban Institute's own API
  variable metadata (not hand-typed), so labels are traceable to source. One code
  is undocumented anywhere in that metadata: `sex=4` in enrollment, 3,663 rows,
  all `year=2022` — flagged with an explicit "UNDOCUMENTED, verify before
  presenting" label rather than guessed. Cross-checked every other distinct code
  actually present in the data against the generated lookups — full coverage.
- Deleted the redundant `.venv/` (missing `requests`, so it couldn't run the pull
  scripts at all; `venv/` has everything needed).
- Git hygiene: raw CSVs gitignored (each far exceeds GitHub's 100MB limit),
  feature-branch workflow (`feature/postgres-load` → PR #1 → merged into
  `main`, branch deleted, `main` set as the default branch on GitHub).
- **SQL analysis layer** (`sql/analysis/`) — enrollment trends
  (statewide + per-institution + class-level), completions trends
  (statewide + per-institution + award-level + top programs), and
  demographics (raw + 2010-comparable) views. Two more grain gotchas
  found and verified empirically before writing any query:
  `class_level=4` ("Other (total)") is a subtotal of codes 2+3, not a
  fourth category, and only populated for degree-seeking students; and
  completions' `majornum` is `NULL` for every row 1986–1999 (single-major
  tracking only existed from 2000) — a naive `majornum=1` filter would
  have zeroed out 14 years of data, fixed with
  `COALESCE(majornum,1)=1`. Reconciliation checked: sum of
  per-institution enrollment for 2020 exactly equals the statewide total
  (233,777 = 233,777).
- **Excel workbook** (`build_excel_workbook.py` → `ipeds_il_summary.xlsx`)
  — 10 formatted data sheets (one per analysis view) plus a Read Me sheet
  with methodology and caveats, plus 2 native line charts (statewide
  enrollment, statewide completions). Regenerable from the live DB.
- **README.md** — the ICCB-analyst-memo write-up, with real findings
  pulled from the views: enrollment peaked in 2009 (383,960), down ~36%
  to 246,931 by 2023; completions rose 132% over the same 1986–2023 span
  (60,296 → 140,102) even as enrollment fell; demographic composition
  shifted substantially (White share 71.3%→44.9%, Hispanic 9.3%→29.8%,
  1990 vs. 2023); five institutions each lost more than half their
  enrollment 2010–2023 (Wabash Valley -83.8%, Rend Lake -65.2%, John A.
  Logan -58.0%, Kennedy-King -56.3%, Lake Land -55.1%). All caveats from
  this file carried forward into it.
- **Power BI path decided and documented** (`POWERBI_GUIDE.md`) — Power
  BI Service (browser) can't reach local Postgres directly; that needs an
  On-premises Data Gateway, which is Windows-only and can't run on this
  Mac. Decided (with the user) to import `ipeds_il_summary.xlsx` directly
  rather than stand up a separate cloud database. Wrote a page-by-page
  build guide (which sheet/columns/chart type per page, plus a
  cross-sheet relationship note for the enrollment-vs-completions combo
  visual) — the actual report has to be built by hand in the Power BI
  Service UI, which isn't something achievable from this CLI session.

## Known data caveats (carry into the final write-up, don't bury)

- **2010 IPEDS race/ethnicity category change.** Federal OMB standards changed
  reporting categories in 2010; demographic data before/after is not directly
  comparable. Urban Institute's `lookup_race` table reflects this — code `20`
  ("Other") is specifically the pre-2010 combined Asian/Pacific-Islander category,
  superseded post-2010 by separate `4` (Asian) and `6` (Native Hawaiian/Pacific
  Islander) codes.
- **2024 completions not yet published** by IPEDS as of this pull (confirmed via
  repeated, consistent 500s on that year/dataset specifically).
- **`sex=4` in 2022 enrollment data is undocumented** anywhere in Urban
  Institute's published metadata. Not fabricated a label for it — needs manual
  verification (possibly a newer IPEDS gender-reporting category their codebook
  metadata hasn't caught up to, but that's a guess, not confirmed) before it's
  presented as anything more specific than "unlabeled code."
- **63 vs. 48 institutions**: not a bug. 48 is the correct 2024 count; 63 is the
  correct count across the full 1986–2024 span (15 colleges closed, merged, or
  changed unitid over 38 years) — worth a line in the write-up as a small
  historical-analysis footnote.

- **CIP code decoding** (`build_cip_lookup.py` → `sql/lookup_cip_code.sql`)
  — `v_completions_top_programs` now shows real program titles
  (Liberal Arts and Sciences, Nursing, Automotive Technology, etc.), not
  bare numeric codes. Sourced from NCES's own CIP dictionaries across all
  four editions that could apply to 1986–2023 (1985, 1990, 2000, 2010;
  the 2020 edition's file isn't fetchable without a JS-driven download).
  The 2010 edition alone covered only 47.8% of actual award volume in
  this data — the older editions were necessary, not optional, since
  IPEDS completions has used four different CIP taxonomies over the full
  period. 2,703 unique codes covered; each carries a `cip_edition` column
  recording which edition's title won.

  **Found and fixed a real bug in already-merged work while building
  this**: `cipcode_6digit=99` is a hidden "Total across all CIP programs"
  marginal row — the same pattern as `race=99`/`sex=99` — verified to
  reconcile exactly against the sum of every real program code for a
  sample institution-year (2,016 = 2,016). Every completions view in
  `sql/analysis/completions_trends.sql` and `demographics.sql` originally
  summed across it without excluding it, exactly **doubling every
  completions figure** in the merged PR #2: 1986 was reported as 60,296
  (correct: 30,148), 2023 as 140,102 (correct: 70,051). The
  year-over-year % change figures were coincidentally still correct
  (the error was a constant 2x multiplier, so ratios between years were
  unaffected), but every absolute total was wrong. Fixed in all four
  affected views, re-verified with the same reconciliation-check
  discipline as the enrollment fix (sum of per-institution completions
  for 2020 now exactly equals the statewide total: 65,768 = 65,768),
  Excel workbook regenerated, README numbers corrected.

## Not yet done

1. **Build the actual Power BI report/dashboard** in the Power BI Service
   UI, by hand, following `POWERBI_GUIDE.md` — data is uploaded and
   confirmed in Power BI as of this update. Guide now includes: a
   validated colorblind-safe theme (`powerbi/theme.json`, import via
   View > Themes before building anything else), a terminology note
   (one report + 5 pages, optionally one pinned dashboard — not five
   dashboards), KPI-card conditional formatting using the theme's
   reserved good/bad colors, and a 10-point "what makes it look
   designed" checklist. One real correction made to the guide itself:
   the original Page 3 suggestion to overlay enrollment and completions
   on a dual-axis combo chart was a genuine anti-pattern (two
   independent y-scales invent an arbitrary visual correlation) —
   replaced with indexing both series to a common base (=100 at the
   first year) on one shared axis. This is a manual, browser-based
   build; nothing left to automate from this repo.
2. Optional polish: pin visuals to a Power BI dashboard view once the
   report exists; consider a regional/urbanicity cut on the
   institution-level enrollment declines noted in README.md; source the
   2020 CIP edition if exact 2020-2023 program titles ever matter enough
   to justify scripting past its JS-driven download.
