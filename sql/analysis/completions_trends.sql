-- Completions/award trend views for Illinois public 2-year colleges.
--
-- GRAIN NOTE: unlike enrollment, the completions cube has no marginal
-- "Total" code for award_level or cipcode_6digit -- every value present
-- is a real category, so summing across all of them is safe and does not
-- overcount. race and sex DO have a 99 "Total" marginal (verified to
-- partition cleanly, including across the methodology change below).
--
-- majornum GOTCHA: the field is NULL for every row 1986-1999 (Urban
-- Institute/IPEDS only started distinguishing first vs. second majors in
-- 2000), then 1 (first major) or 2 (second major) from 2000 onward.
-- Filtering `WHERE majornum = 1` alone would silently zero out all
-- 1986-1999 completions data. The correct de-duplicated "one row per
-- completer" filter across the full historical range is
-- COALESCE(majornum, 1) = 1 -- used throughout this file. Second majors
-- (majornum=2, 2000+ only, a small share of rows) are real additional
-- awards, not a data quality issue -- they're excluded from headline
-- totals here to avoid double-counting double-major completers, and can
-- be added back in explicitly for a "total awards including second
-- majors" variant if that's ever the question being asked.

DROP VIEW IF EXISTS v_completions_trend_statewide;
CREATE VIEW v_completions_trend_statewide AS
WITH by_year AS (
    SELECT
        year,
        SUM(awards_6digit) AS total_completions
    FROM v_il_cc_completions
    WHERE COALESCE(majornum, 1) = 1 AND race = 99 AND sex = 99
    GROUP BY year
)
SELECT
    year,
    total_completions,
    ROUND(
        100.0 * (total_completions - LAG(total_completions) OVER (ORDER BY year))
        / NULLIF(LAG(total_completions) OVER (ORDER BY year), 0),
    2) AS yoy_pct_change
FROM by_year
ORDER BY year;

DROP VIEW IF EXISTS v_completions_trend_by_institution;
CREATE VIEW v_completions_trend_by_institution AS
WITH by_inst_year AS (
    SELECT
        c.unitid,
        i.inst_name,
        c.year,
        SUM(c.awards_6digit) AS total_completions
    FROM v_il_cc_completions c
    JOIN institutions i ON i.unitid = c.unitid AND i.year = c.year
    WHERE COALESCE(c.majornum, 1) = 1 AND c.race = 99 AND c.sex = 99
    GROUP BY c.unitid, i.inst_name, c.year
)
SELECT
    unitid,
    inst_name,
    year,
    total_completions,
    ROUND(
        100.0 * (total_completions - LAG(total_completions) OVER (PARTITION BY unitid ORDER BY year))
        / NULLIF(LAG(total_completions) OVER (PARTITION BY unitid ORDER BY year), 0),
    2) AS yoy_pct_change
FROM by_inst_year
ORDER BY inst_name, year;

-- Completions by award type (associate's degree vs. certificate length
-- vs. other), statewide by year. Note award_level 20-24 (doctoral/
-- first-professional codes) and similar can appear on paper even though
-- these are two-year institutions -- IPEDS occasionally records these
-- for teach-out/consortium arrangements; worth a sanity spot-check in
-- the write-up rather than assuming they're an error.
DROP VIEW IF EXISTS v_completions_trend_by_award_level;
CREATE VIEW v_completions_trend_by_award_level AS
SELECT
    c.year,
    l.label AS award_level,
    SUM(c.awards_6digit) AS completions
FROM v_il_cc_completions c
JOIN lookup_award_level l ON l.code = c.award_level
WHERE COALESCE(c.majornum, 1) = 1 AND c.race = 99 AND c.sex = 99
GROUP BY c.year, l.label
ORDER BY c.year, l.label;

-- Top CIP-6 program areas by total completions across the full period --
-- a starting point for "which programs produce the most completions"
-- analysis. cipcode_6digit is Urban Institute's numeric encoding of the
-- 6-digit CIP code; a human-readable CIP title lookup is not yet built
-- (IPEDS/NCES publish a CIP code dictionary separately -- flagged as
-- follow-up work, not fabricated here).
DROP VIEW IF EXISTS v_completions_top_programs;
CREATE VIEW v_completions_top_programs AS
SELECT
    cipcode_6digit,
    SUM(awards_6digit) AS total_completions
FROM v_il_cc_completions
WHERE COALESCE(majornum, 1) = 1 AND race = 99 AND sex = 99
GROUP BY cipcode_6digit
ORDER BY total_completions DESC;
