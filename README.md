# Illinois Community College Enrollment & Completion Analysis

A data analysis project examining enrollment, completion, and demographic
trends across Illinois's public 2-year (community) colleges, built on
federal IPEDS data. Framed as an ICCB (Illinois Community College Board)
analyst memo — the kind of scoped, caveat-aware analysis that role
actually produces, not a polished-over dashboard that hides how the data
got there.

## Key findings

**Enrollment peaked in 2009 and has fallen ~36% since, with only a
partial post-pandemic recovery.** Statewide headcount across the 63
institutions that have carried IL public 2-year status at some point
since 1986 hit 383,960 in fall 2009, fell to 233,777 by fall 2020 (-39%
from peak, the single largest year-over-year drop being -13.8% in 2020),
and had recovered only to 246,931 by fall 2023 — still 36% below the
2009 peak and 26% below the 1986 starting point (335,100).

**The decline is not evenly distributed.** Comparing fall 2010 to fall
2023 by institution, several colleges lost the majority of their
enrollment: Illinois Eastern Community Colleges–Wabash Valley College
(-83.8%), Rend Lake College (-65.2%), John A. Logan College (-58.0%),
City Colleges of Chicago–Kennedy-King College (-56.3%), and Lake Land
College (-55.1%). This is a mix of downstate rural colleges and one
Chicago college — worth a follow-up cut by region/urbanicity rather than
treating "community college enrollment" as one statewide trend.

**Completions moved in the opposite direction.** Total awards conferred
rose from 60,296 (1986) to 140,102 (2023) — up 132% — even as headcount
fell. Falling enrollment alongside rising completions points to improved
throughput/completion rates per enrolled student, consistent with the
kind of guided-pathways and completion-agenda work ICCB and its colleges
have pursued; this analysis doesn't isolate the cause, but flags the
counter-trend as the headline result worth investigating further.

**The student population has diversified substantially.** Comparable
demographic shares (merging pre/post-2010 category definitions — see
caveat below) shifted from 1990 to 2023 as follows:

| Group | 1990 | 2023 |
|---|---|---|
| White | 71.3% | 44.9% |
| Hispanic | 9.3% | 29.8% |
| Black | 14.4% | 12.4% |
| Asian / Pacific Islander | 3.8% | 5.3% |
| Two or more races | n/a (category didn't exist) | 3.1% |
| Unknown | 0.6% | 3.2% |
| American Indian / Alaska Native | 0.4% | 0.2% |
| Nonresident alien | 0.2% | 1.1% |

The Hispanic share more than tripled and the White share fell by more
than a third of its 1990 level — the single largest compositional shift
in the data.

## Data source

[Urban Institute's Education Data Portal](https://educationdata.urban.org)
— a free public REST API wrapping raw IPEDS (Integrated Postsecondary
Education Data System) data. Scope: Illinois (`fips=17`), public 2-year
institutions (`sector=4`), 1986–2024 for directory/enrollment, 1986–2023
for completions.

## Data caveats (read before citing any number from this project)

- **2010 IPEDS race/ethnicity category change.** Federal OMB standards
  changed reporting categories in 2010. Pre-2010, "Asian" and "Native
  Hawaiian or other Pacific Islander" were one combined category; they
  split in 2010, and "Two or more races" appeared with no pre-2010
  equivalent. Raw year-over-year race trends crossing 2010 are not
  directly comparable for these groups. This project provides both a
  `_raw` view (categories exactly as reported, discontinuity included)
  and a `_comparable` view (pre/post-2010 categories merged) for every
  demographic breakdown — see `sql/analysis/demographics.sql`.
- **2024 completions data is not yet published by IPEDS**, confirmed via
  repeated, consistent errors specific to that year/dataset (distinct
  from the transient server errors seen elsewhere in the pull).
- **One enrollment code is undocumented.** `sex=4` appears in 3,663 rows,
  all from fall 2022, and isn't defined anywhere in Urban Institute's own
  published API metadata. It's excluded from the demographic breakdowns
  in this project rather than guessed at — flagged for follow-up, not
  silently dropped without a note.
- **The Urban Institute API doesn't support institution-sector filtering
  on the enrollment or completions endpoints at all** — `sector` isn't
  even a variable on those endpoints, confirmed against their metadata.
  The raw pulled data for both is statewide (all sectors), not
  community-college-only. This project scopes it correctly at the
  database layer instead: `v_il_cc_enrollment` / `v_il_cc_completions`
  join to `institutions` on `(unitid, year)` so only rows for years an
  institution was actually classified Public, two-year are used. All
  analysis in this repo builds on those scoped views, not the raw
  statewide tables.
- **63 institutions appear in the data, not 48.** 48 is the correct
  count of active Illinois public 2-year colleges as of 2024; 63 is the
  correct count across the full 1986–2024 span, reflecting colleges that
  closed, merged, or changed IPEDS unitid over 38 years. Both numbers are
  right — they're answering different questions.
- **IPEDS category grain is non-obvious and easy to get wrong.**
  Enrollment data is a fully-crossed cube (full-time/part-time ×
  degree-seeking × class level × sex × race) where code `99` means
  "Total across this dimension," not a category to sum — naively summing
  every row overcounts by ~1.5x. `class_level` additionally has an
  internal subtotal (`4`, "Other (total)," is itself `2 + 3`) and is
  only meaningful for degree-seeking students. Completions'
  `majornum` field is `NULL` for every row before 2000 (single-major
  tracking only) and `1`/`2` (first/second major) from 2000 on — a naive
  `majornum = 1` filter would silently zero out 1986–1999. Every
  analysis view in `sql/analysis/` documents and correctly handles this;
  see the comment headers in those files for the full reasoning and the
  empirical checks that confirmed it.

## Repository structure

```
pull_ipeds_data.py       -- pulls directory, enrollment, completions from the API
backfill_missing.py      -- targeted retry for specific year/dataset gaps
load_to_postgres.py      -- loads the raw CSVs into Postgres (ipeds_il)
build_code_lookups.py    -- generates sql/lookup_tables.sql from Urban Institute's
                             own API metadata (not hand-typed labels)
build_excel_workbook.py  -- generates ipeds_il_summary.xlsx from the analysis views
inspect_data.py,
check_institutions.py    -- diagnostic scripts (kept for reference; found the
                             NaN/NULL load bug documented in PROGRESS.md)

sql/
  schema.sql             -- the three fact tables (institutions, enrollment, completions)
  lookup_tables.sql       -- generated dimension tables decoding IPEDS category codes
  views.sql               -- v_il_cc_enrollment / v_il_cc_completions (sector-scoped)
  analysis/
    enrollment_trends.sql -- statewide + per-institution enrollment, YoY change
    completions_trends.sql-- statewide + per-institution completions, by award level
    demographics.sql      -- race/sex composition, raw and 2010-comparable

ipeds_il_summary.xlsx    -- Excel deliverable: every analysis view as a formatted
                             sheet, plus a Read Me sheet with methodology/caveats
POWERBI_GUIDE.md          -- how to build the Power BI Service dashboard from
                             ipeds_il_summary.xlsx
PROGRESS.md               -- running project status log
```

## Reproducing this

1. `python3 pull_ipeds_data.py` (run under `caffeinate -i` on Mac — this
   takes hours and sleep will kill it), then `python3 backfill_missing.py`
   if any years failed.
2. Create the `ipeds_il` Postgres database, then apply
   `sql/schema.sql` → `python3 load_to_postgres.py` →
   `python3 build_code_lookups.py` then `psql -d ipeds_il -f sql/lookup_tables.sql`
   → `psql -d ipeds_il -f sql/views.sql` → apply everything under
   `sql/analysis/`.
3. `python3 build_excel_workbook.py` to regenerate the Excel deliverable.
4. See `POWERBI_GUIDE.md` for the dashboard.
