# Contact Center Insights Dashboard

## [Open the live dashboard](https://anas-abdelhafeez.github.io/contact-center-insights-dashboard/)

<a href="https://anas-abdelhafeez.github.io/contact-center-insights-dashboard/"><img src="screenshots/tab_1_Problem.png" alt="Contact center dashboard" width="720"></a>

https://anas-abdelhafeez.github.io/contact-center-insights-dashboard/

A personal portfolio project: what drives customer satisfaction in a contact center, and where call centers lose callers. Public data only. Not client work.

## The story (7 tabs)
Problem, Impact, Where, Who, Why, When, Fix.

| Problem | Impact | Where |
|---|---|---|
| ![](screenshots/tab_1_Problem.png) | ![](screenshots/tab_2_Impact.png) | ![](screenshots/tab_3_Where.png) |

| Who | Why | When | Fix |
|---|---|---|---|
| ![](screenshots/tab_4_Who.png) | ![](screenshots/tab_5_Why.png) | ![](screenshots/tab_6_When.png) | ![](screenshots/tab_7_Fix.png) |

## Key findings
- CSAT 80.9% and NPS +53.3 across 28,816 survey responses (2020-2025). Answer satisfaction is the weakest score (66.2%), agent service the strongest (89.5%).
- Answer quality is the strongest driver of overall satisfaction (33% weight in the regression), then job knowledge (27%). Wait time and agent service are about 17% each.
- 3,232 customers rated the agent well but the answer poorly. Only 44.1% of them were satisfied, against 97% when both were good.
- Detractors rate the answer poor 68% of the time, against 18.6% of all customers.
- Medi-Cal county call centers, Jan-Sep 2026: about 14.3M calls, 34 counties. 25.3% of calls were abandoned in September (call-weighted). Abandonment tracks wait time (correlation 62%), not call volume.
- Big gaps between counties: San Francisco 1.3% abandonment, Tulare 47% with a 124-minute wait.

## Method
- Cleaned the survey (valid five-point answers, scores 1-5, NPS groups, month, hour, weekday) and aggregated Medi-Cal files by county and month.
- Drivers: Pearson correlations and a standardized linear regression on overall satisfaction (about 64% of variance explained).
- Dashboard: single HTML page with ECharts. Power BI file and Excel workbook cover the same data. SQL playbook for PostgreSQL.

## Data sources and credit
- NYC 311 customer satisfaction survey, 2020-2025 (NYC Open Data). 28,816 responses. No personal data: only ratings, language, timestamps.
- Medi-Cal call center data, California Department of Health Care Services open data (call volume, wait and abandonment by county, Jan-Sep 2026).
- `data/SYNTHETIC_qa_*.csv` are **made-up practice data** for the SQL QA section. They are not real and not linked to any company.
- This repo keeps only a 200-row random sample of the survey (`data/NYC311_survey_sample_200rows.csv`). Full data is at the sources above.

## Files
| Path | What |
|---|---|
| `index.html` | The dashboard (GitHub Pages) |
| `screenshots/` | One screenshot per tab |
| `sql/CSAT_QA_PostgreSQL_playbook.sql` | PostgreSQL queries |
| `excel/Contact_Center_Data_and_Summary.xlsx` | Data and summary workbook |
| `powerbi/Contact_Center_CSAT_Dashboard.pbix` | Power BI report, 7 pages in story order |
| `data/` | Medi-Cal monthly county file, 200-row survey sample, synthetic QA files |

## Honest limits
- Correlations are not causes. Some language groups are small (Korean: 97 responses).
- County wait and abandonment are reported averages, not call-level data.
- **The PBIX has not been opened in Power BI Desktop or the Power BI service.** Its data model was read back with an independent open-source reader: 2 tables, 28,816 survey rows and 306 county-month rows, 27 measures, and the totals match the source data. Page layout and visuals were not rendered, so how the report looks is unverified. It uses basic visuals, so it does not match the HTML dashboard (no gauge, heatmaps, bubble chart or correlation matrix).
- The SQL playbook was run end to end on a local PostgreSQL 16 test server with the full survey and the synthetic QA files: no errors, and the CSAT result (80.87%) matches the dashboard. It has not been run on any other database setup.
- The QA section uses synthetic data only.
- The Pages version loads the ECharts library from a CDN.
