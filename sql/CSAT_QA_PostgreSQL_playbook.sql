-- Anas operational analytics portfolio, 23 Nov 2026
-- PostgreSQL 12+. Sections A/B use real NYC311 survey data.
-- Section C uses a separately authored synthetic QA practice table.
-- Do not join these sources to Medi-Cal or Detroit agency records.

-- A. Import the original 13-column NYC CSV in its original column order.
CREATE TABLE nyc311_raw (
  survey_year text, campaign text, channel text, survey_type text,
  start_time text, completion_time text, survey_language text,
  overall_satisfaction text, wait_time text,
  agent_customer_service text, agent_job_knowledge text,
  answer_satisfaction text, nps text
);
-- In psql, use your local path:
-- \copy nyc311_raw FROM 'NYC311_CSAT_REAL_2020-2025.csv' WITH (FORMAT csv, HEADER true);
-- Keep the raw table unchanged. No reliable unique response ID is supplied.
-- Identical rows are review flags, not automatic grounds for deletion.

CREATE VIEW nyc311_clean AS
SELECT *,
  CASE WHEN btrim(overall_satisfaction) IN
    ('Strongly Agree','Agree','Neutral','Disagree','Strongly Disagree')
    THEN btrim(overall_satisfaction) END AS overall_valid,
  CASE WHEN btrim(overall_satisfaction) IN ('Strongly Agree','Agree') THEN 1
       WHEN btrim(overall_satisfaction) IN
         ('Neutral','Disagree','Strongly Disagree') THEN 0 END AS satisfied,
  CASE WHEN btrim(agent_job_knowledge) IN
    ('Strongly Agree','Agree','Neutral','Disagree','Strongly Disagree')
    THEN btrim(agent_job_knowledge) END AS knowledge_valid,
  CASE WHEN btrim(agent_customer_service) IN
    ('Strongly Agree','Agree','Neutral','Disagree','Strongly Disagree')
    THEN btrim(agent_customer_service) END AS service_valid,
  -- Strip only the known directional marks, preserve the language itself.
  btrim(translate(survey_language, U&'\200E\200F', '')) AS language_clean
FROM nyc311_raw;

-- Inspect quality and denominator before reporting.
SELECT count(*) AS imported_rows,
       count(overall_valid) AS valid_overall_responses,
       count(*) FILTER (WHERE knowledge_valid IS NULL) AS invalid_knowledge,
       count(*) FILTER (WHERE service_valid IS NULL) AS invalid_service
FROM nyc311_clean;

-- CSAT here is an analyst-defined positive-agreement rate, not an official
-- NYC published KPI, nor an arithmetic mean of a 1-5 score.
SELECT count(satisfied) AS valid_responses,
       sum(satisfied) AS satisfied_responses,
       round(100.0 * sum(satisfied) / nullif(count(satisfied),0),2) AS csat_pct
FROM nyc311_clean;

-- Campaign comparison: campaign numbers repeat across years.
SELECT survey_year, campaign, count(satisfied) AS valid_responses,
       round(100.0 * sum(satisfied) / nullif(count(satisfied),0),2) AS csat_pct
FROM nyc311_clean
GROUP BY survey_year, campaign
ORDER BY survey_year, campaign;

-- Segment size and uncertainty: Wilson 95% interval. The interval reflects
-- binomial sampling uncertainty, NOT selection bias/non-response bias.
WITH grouped AS (
 SELECT language_clean, count(satisfied)::numeric AS n,
        sum(satisfied)::numeric AS s
 FROM nyc311_clean GROUP BY language_clean
), rates AS (
 SELECT *, s/nullif(n,0) AS p FROM grouped WHERE n > 0
)
SELECT language_clean, n,
 round(100*p,2) AS csat_pct,
 round(100*(p+3.8416/(2*n)-1.96*sqrt(p*(1-p)/n+3.8416/(4*n*n)))
       /(1+3.8416/n),2) AS ci_low_pct,
 round(100*(p+3.8416/(2*n)+1.96*sqrt(p*(1-p)/n+3.8416/(4*n*n)))
       /(1+3.8416/n),2) AS ci_high_pct,
 CASE WHEN n < 30 THEN 'small sample: do not rank' ELSE 'review mix/bias' END AS flag
FROM rates ORDER BY n DESC;

-- B. Driver screening, not causal proof. All ratings share one survey.
-- Wait Time is perceived wait agreement, NOT elapsed wait in seconds.
WITH dimensions AS (
 SELECT c.satisfied, c.survey_year, c.campaign,
        d.driver, d.rating
 FROM nyc311_clean c
 CROSS JOIN LATERAL (VALUES
   ('perceived_wait', btrim(c.wait_time)),
   ('agent_knowledge', c.knowledge_valid),
   ('agent_service', c.service_valid),
   ('answer_satisfaction', btrim(c.answer_satisfaction))
 ) AS d(driver,rating)
), grouped AS (
 SELECT driver,
   CASE WHEN rating IN ('Strongly Agree','Agree') THEN 'positive'
        WHEN rating IN ('Disagree','Strongly Disagree') THEN 'negative'
        WHEN rating = 'Neutral' THEN 'neutral' ELSE 'invalid/missing' END AS band,
   count(satisfied) AS n, sum(satisfied) AS satisfied_n
 FROM dimensions GROUP BY 1,2
)
SELECT driver, band, n,
 round(100.0*satisfied_n/nullif(n,0),2) AS csat_pct,
 n-satisfied_n AS non_positive_overall_n
FROM grouped ORDER BY driver,band;
-- To check campaign mix, group by survey_year/campaign too. Avoid interpreting
-- overlapping driver totals as additive unique customers.
-- Overall non-positive includes neutral; call it dissatisfaction only if
-- a separate negative-only definition has been used.

-- C. QA extension. This is a proposed schema, NOT a field in NYC data.
-- One final audit per interaction. Use separate calibration records elsewhere.
CREATE TABLE qa_audits (
 audit_id bigint PRIMARY KEY,
 interaction_id text NOT NULL UNIQUE,
 audited_at date NOT NULL,
 agent_id text NOT NULL,
 category text NOT NULL,
 channel text NOT NULL,
 assessor_id text NOT NULL,
 rubric_version text NOT NULL,
 critical_fail boolean NOT NULL,
 source_type text NOT NULL CHECK (source_type IN ('synthetic','real_authorized'))
);
CREATE TABLE qa_items (
 audit_id bigint REFERENCES qa_audits(audit_id),
 criterion text NOT NULL,
 earned_points numeric NOT NULL,
 possible_points numeric NOT NULL CHECK (possible_points > 0),
 PRIMARY KEY (audit_id, criterion),
 CHECK (earned_points >= 0 AND earned_points <= possible_points)
);
-- Import the accompanying demo files in psql:
-- \copy qa_audits FROM 'SYNTHETIC_qa_audits.csv' WITH (FORMAT csv, HEADER true);
-- \copy qa_items FROM 'SYNTHETIC_qa_items.csv' WITH (FORMAT csv, HEADER true);
-- N/A criteria have no qa_items row and therefore contribute no denominator.
-- Weights are encoded as possible points. This is an authored practice rubric.
-- Critical compliance fail sets the effective audit score to zero by design.
CREATE VIEW qa_scored AS
SELECT a.*, x.earned, x.possible,
 100.0*x.earned/nullif(x.possible,0) AS raw_qa_pct,
 CASE WHEN a.critical_fail THEN 0::numeric
      ELSE 100.0*x.earned/nullif(x.possible,0) END AS effective_qa_pct
FROM qa_audits a
LEFT JOIN (
 SELECT audit_id, sum(earned_points) AS earned,
        sum(possible_points) AS possible
 FROM qa_items GROUP BY audit_id
) x USING (audit_id);

-- Equal-audit mean, not a hidden blend of rubrics or synthetic/real sources.
SELECT source_type, rubric_version, date_trunc('month',audited_at)::date AS month,
       count(*) AS all_audits, count(effective_qa_pct) AS scored_audits,
       round(avg(raw_qa_pct),2) AS raw_qa_pct,
       round(avg(effective_qa_pct),2) AS effective_qa_pct,
       round(100.0*count(*) FILTER (WHERE critical_fail)/nullif(count(*),0),2)
         AS critical_fail_pct
FROM qa_scored
GROUP BY 1,2,3 ORDER BY 1,2,3;

-- QA root-cause screening by category/channel/criterion. Points lost is a
-- prioritization signal. It is not a proven explanation for low CSAT.
SELECT a.source_type,a.rubric_version,a.category,a.channel,i.criterion,
       count(*) AS item_evaluations,
       sum(i.possible_points-i.earned_points) AS lost_points,
       round(100.0*sum(i.earned_points)/nullif(sum(i.possible_points),0),2)
         AS criterion_attainment_pct
FROM qa_audits a JOIN qa_items i USING(audit_id)
GROUP BY 1,2,3,4,5 ORDER BY lost_points DESC;
-- Add agent_id only for coaching after balancing case mix, tenure and sample.
-- Do not use the demo for ranking actual employees.

-- D. Optional DatabaseSample synthetic practice, after importing its own SQL.
-- Run separately in the schema that holds its tickets and csat_surveys tables.
-- SELECT t.channel, t.first_response_breached,
--   count(DISTINCT t.id) AS resolved_tickets,
--   count(s.csat_score) AS valid_survey_responses,
--   round(100.0*count(s.csat_score)/nullif(count(DISTINCT t.id),0),2)
--     AS survey_coverage_pct,
--   round(100.0*count(*) FILTER (WHERE s.csat_score IN (4,5)) /
--     nullif(count(s.csat_score),0),2) AS csat_pct
-- FROM tickets t LEFT JOIN csat_surveys s
-- ON s.ticket_id=t.id AND s.csat_score BETWEEN 1 AND 5
-- GROUP BY 1,2 ORDER BY 1,2;
-- Coverage is not a true invitation response rate without invitation counts.
-- The synthetic generator builds the speed-CSAT relationship into its data.
