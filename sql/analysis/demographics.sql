-- Demographic composition views (race, sex) for IL public 2-year college
-- enrollment and completions.
--
-- CAVEAT THAT MUST CARRY INTO ANY WRITE-UP: IPEDS changed its race/
-- ethnicity reporting categories in 2010 under new federal OMB standards.
-- Pre-2010, "Asian" and "Native Hawaiian or other Pacific Islander" were
-- reported as one combined category (code 20, labeled "Other" in Urban
-- Institute's schema). Post-2010 they split into separate codes (4 and 6
-- respectively), and a new "Two or more races" category (7) appeared
-- with no pre-2010 equivalent at all. Raw year-over-year race trends that
-- cross 2010 are NOT directly comparable for these categories -- a drop
-- in code 20 after 2010 doesn't mean enrollment fell, it means the
-- category was retired.
--
-- v_enrollment_demographics_raw / v_completions_demographics_raw expose
-- the categories exactly as IPEDS reported them, discontinuity included --
-- use these when the pre/post-2010 distinction itself matters.
--
-- v_enrollment_demographics_comparable / v_completions_demographics_
-- comparable additionally provide a `race_group_comparable` column that
-- merges codes 4, 6, and 20 into one "Asian / Pacific Islander (combined
-- for pre/post-2010 comparability)" bucket, giving a continuous
-- 1986-2024 series at the cost of losing the post-2010 Asian vs. Native
-- Hawaiian/Pacific Islander split. "Two or more races" (7) has no
-- pre-2010 counterpart and is left as its own bucket -- it will show zero
-- before 2010 because the category didn't exist, not because no such
-- students were enrolled.

DROP VIEW IF EXISTS v_enrollment_demographics_raw;
CREATE VIEW v_enrollment_demographics_raw AS
SELECT
    e.year,
    e.year < 2010 AS is_pre_2010_categories,
    r.label AS race,
    s.label AS sex,
    SUM(e.enrollment_fall) AS enrollment
FROM v_il_cc_enrollment e
JOIN lookup_race r ON r.code = e.race
JOIN lookup_sex  s ON s.code = e.sex
WHERE e.ftpt = 99 AND e.degree_seeking = 99 AND e.class_level = 99
  AND e.race <> 99 AND e.sex <> 99
GROUP BY e.year, r.label, s.label
ORDER BY e.year, r.label, s.label;

DROP VIEW IF EXISTS v_enrollment_demographics_comparable;
CREATE VIEW v_enrollment_demographics_comparable AS
SELECT
    e.year,
    CASE
        WHEN e.race IN (4, 6, 20) THEN 'Asian / Pacific Islander (combined for pre/post-2010 comparability)'
        ELSE r.label
    END AS race_group_comparable,
    SUM(e.enrollment_fall) AS enrollment
FROM v_il_cc_enrollment e
JOIN lookup_race r ON r.code = e.race
WHERE e.ftpt = 99 AND e.degree_seeking = 99 AND e.class_level = 99
  AND e.sex = 99 AND e.race <> 99
GROUP BY e.year, race_group_comparable
ORDER BY e.year, race_group_comparable;

-- Completions demographics. race/sex partition cleanly against their own
-- 99 marginal here too (verified). majornum handling matches
-- v_completions_trend_statewide: COALESCE(majornum,1)=1, since majornum
-- is NULL for all pre-2000 rows (only first-major tracking existed) and
-- 1/2 (first/second major) from 2000 onward -- see completions_trends.sql
-- for the full explanation.
--
-- cipcode_6digit=99 is ALSO a marginal "Total across all CIP programs"
-- row (see completions_trends.sql grain note) and must be excluded here
-- too, or every completions figure below doubles.
DROP VIEW IF EXISTS v_completions_demographics_raw;
CREATE VIEW v_completions_demographics_raw AS
SELECT
    c.year,
    c.year < 2010 AS is_pre_2010_categories,
    r.label AS race,
    s.label AS sex,
    SUM(c.awards_6digit) AS completions
FROM v_il_cc_completions c
JOIN lookup_race r ON r.code = c.race
JOIN lookup_sex  s ON s.code = c.sex
WHERE COALESCE(c.majornum, 1) = 1
  AND c.race <> 99 AND c.sex <> 99
  AND c.cipcode_6digit <> 99
GROUP BY c.year, r.label, s.label
ORDER BY c.year, r.label, s.label;

DROP VIEW IF EXISTS v_completions_demographics_comparable;
CREATE VIEW v_completions_demographics_comparable AS
SELECT
    c.year,
    CASE
        WHEN c.race IN (4, 6, 20) THEN 'Asian / Pacific Islander (combined for pre/post-2010 comparability)'
        ELSE r.label
    END AS race_group_comparable,
    SUM(c.awards_6digit) AS completions
FROM v_il_cc_completions c
JOIN lookup_race r ON r.code = c.race
WHERE COALESCE(c.majornum, 1) = 1
  AND c.sex = 99 AND c.race <> 99
  AND c.cipcode_6digit <> 99
GROUP BY c.year, race_group_comparable
ORDER BY c.year, race_group_comparable;
