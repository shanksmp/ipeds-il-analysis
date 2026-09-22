# Progress — Illinois Community College Enrollment & Completion Analysis

Last updated: 2026-09-22

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
  feature-branch workflow (`feature/postgres-load`, not yet merged/PR'd to `main`).

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

## Not yet done

1. **SQL analysis layer** — enrollment trends over time (statewide-scoped and
   per-institution), completion/award trends, demographic composition shifts,
   year-over-year % change. Build on `v_il_cc_enrollment` /
   `v_il_cc_completions` joined to the `lookup_*` tables.
2. **Power BI dashboard** (primary deliverable) — via Power BI Service
   (browser), since Desktop isn't available on Mac. Star-schema-ready: scoped
   views as fact tables, `lookup_*` as dimension tables for relationships.
3. **Excel summary workbook** (secondary deliverable).
4. **README / analyst write-up** — framed as an ICCB analyst memo: key
   findings, trends, and explicit documentation of the caveats above (2010
   category change, missing 2024 completions, the enrollment/completions
   sector-scope issue found and fixed here, the undocumented `sex=4` code).
5. **Open a PR** from `feature/postgres-load` into `main` — not done yet,
   pending a decision on whether to keep adding to this branch or cut it here.
