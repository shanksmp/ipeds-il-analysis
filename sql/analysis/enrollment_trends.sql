-- Enrollment trend views for Illinois public 2-year colleges.
--
-- GRAIN NOTE (read before extending this file): the raw enrollment table
-- is a fully-crossed cube over (ftpt, degree_seeking, class_level, sex,
-- race), with code 99 meaning "Total across this dimension" -- NOT a
-- category to sum alongside the others. Naively summing every row for an
-- institution-year overcounts by ~1.5x. Verified empirically:
--   - ftpt, degree_seeking, sex, race each partition cleanly: summing the
--     non-99 codes for that dimension (holding every other dimension at
--     99) reproduces that dimension's own 99 total.
--   - class_level does NOT independently partition against the grand
--     total. class_level=4 ("Other (total)") is itself a subtotal of
--     class_level 2 + class_level 3, and class_level is only populated
--     (codes 1-4) when degree_seeking=1 -- non-degree-seeking students
--     only ever carry class_level=99. So class_level breakdowns must be
--     read against the degree_seeking=1 subtotal, not the grand total.
-- The views below always pick the correctly-marginalized row for
-- whatever breakdown they present, rather than summing everything.

-- Statewide (all 63 historical IL public 2-year colleges), total
-- headcount by year, full-time/part-time split, and year-over-year %
-- change.
DROP VIEW IF EXISTS v_enrollment_trend_statewide;
CREATE VIEW v_enrollment_trend_statewide AS
WITH by_year AS (
    SELECT
        year,
        SUM(enrollment_fall) FILTER (WHERE ftpt = 99)  AS total_enrollment,
        SUM(enrollment_fall) FILTER (WHERE ftpt = 1)   AS full_time_enrollment,
        SUM(enrollment_fall) FILTER (WHERE ftpt = 2)   AS part_time_enrollment
    FROM v_il_cc_enrollment
    WHERE degree_seeking = 99 AND class_level = 99 AND sex = 99 AND race = 99
    GROUP BY year
)
SELECT
    year,
    total_enrollment,
    full_time_enrollment,
    part_time_enrollment,
    ROUND(
        100.0 * (total_enrollment - LAG(total_enrollment) OVER (ORDER BY year))
        / NULLIF(LAG(total_enrollment) OVER (ORDER BY year), 0),
    2) AS yoy_pct_change
FROM by_year
ORDER BY year;

-- Same, but per institution.
DROP VIEW IF EXISTS v_enrollment_trend_by_institution;
CREATE VIEW v_enrollment_trend_by_institution AS
WITH by_inst_year AS (
    SELECT
        e.unitid,
        i.inst_name,
        e.year,
        SUM(e.enrollment_fall) FILTER (WHERE e.ftpt = 99) AS total_enrollment,
        SUM(e.enrollment_fall) FILTER (WHERE e.ftpt = 1)  AS full_time_enrollment,
        SUM(e.enrollment_fall) FILTER (WHERE e.ftpt = 2)  AS part_time_enrollment
    FROM v_il_cc_enrollment e
    JOIN institutions i ON i.unitid = e.unitid AND i.year = e.year
    WHERE e.degree_seeking = 99 AND e.class_level = 99 AND e.sex = 99 AND e.race = 99
    GROUP BY e.unitid, i.inst_name, e.year
)
SELECT
    unitid,
    inst_name,
    year,
    total_enrollment,
    full_time_enrollment,
    part_time_enrollment,
    ROUND(
        100.0 * (total_enrollment - LAG(total_enrollment) OVER (PARTITION BY unitid ORDER BY year))
        / NULLIF(LAG(total_enrollment) OVER (PARTITION BY unitid ORDER BY year), 0),
    2) AS yoy_pct_change
FROM by_inst_year
ORDER BY inst_name, year;

-- New / continuing / transfer status, degree-seeking undergrads only
-- (class_level is meaningless outside degree_seeking=1 -- see grain note
-- above). class_level=4 ("Other (total)") is deliberately excluded since
-- it's a subtotal of 2+3, not a fourth category.
DROP VIEW IF EXISTS v_enrollment_trend_class_level;
CREATE VIEW v_enrollment_trend_class_level AS
SELECT
    e.year,
    l.label AS class_level,
    SUM(e.enrollment_fall) AS enrollment
FROM v_il_cc_enrollment e
JOIN lookup_class_level l ON l.code = e.class_level
WHERE e.degree_seeking = 1
  AND e.ftpt = 99 AND e.sex = 99 AND e.race = 99
  AND e.class_level IN (1, 2, 3)
GROUP BY e.year, l.label
ORDER BY e.year, l.label;
