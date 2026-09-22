-- Illinois-public-2-year-scoped views.
--
-- Why these exist: pull_ipeds_data.py filters the *directory* pull to
-- sector=4 (Public, two-year) correctly, but the fall-enrollment and
-- completions-cip-6 API endpoints don't support a sector filter at all --
-- `sector` isn't even a variable on those endpoints (confirmed against
-- Urban Institute's own endpoint metadata), so the &sector=4 query param
-- on the completions pull is silently ignored, and the enrollment pull
-- never had one to begin with. The result: `enrollment` holds 608
-- Illinois institutions (all sectors, not just community colleges), and
-- `completions` holds 572. Only ~25-30% of rows in each table belong to
-- one of the 63 Illinois public 2-year colleges (48 active as of 2024,
-- the rest closed/merged/renamed since 1986) that are in `institutions`.
--
-- Rather than re-pull (there's no filter to pull with) or delete rows
-- (loses the statewide comparison baseline), these views join against
-- `institutions` on (unitid, year) -- which IS correctly sector-scoped --
-- so only rows for years an institution was actually classified as
-- Public, two-year survive. Build all analysis/Power BI/Excel work on
-- these views, not the raw fact tables, unless a statewide comparison is
-- intentionally wanted.

DROP VIEW IF EXISTS v_il_cc_enrollment;
CREATE VIEW v_il_cc_enrollment AS
SELECT e.*
FROM enrollment e
JOIN institutions i
  ON i.unitid = e.unitid
 AND i.year   = e.year;

DROP VIEW IF EXISTS v_il_cc_completions;
CREATE VIEW v_il_cc_completions AS
SELECT c.*
FROM completions c
JOIN institutions i
  ON i.unitid = c.unitid
 AND i.year   = c.year;
