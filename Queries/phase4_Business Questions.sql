-- ============================================
-- CINEMETRICS Phase 5 — Business Questions
-- ============================================

-- BQ1: "Where should we invest our next $100M budget?"
-- Find genres with best avg ROI for mid-budget films ($50M–$150M)
SELECT
    g.genre_name,
    COUNT(m.movie_id)               AS films_in_range,
    ROUND(AVG(m.roi), 2)            AS avg_roi,
    ROUND(AVG(m.profit)/1000000, 1) AS avg_profit_millions,
    ROUND(AVG(m.vote_average), 2)   AS avg_rating
FROM movies m
JOIN movie_genres mg ON m.movie_id = mg.movie_id
JOIN genres g        ON mg.genre_id = g.genre_id
WHERE m.budget BETWEEN 50000000 AND 150000000
  AND m.roi IS NOT NULL
GROUP BY g.genre_name
HAVING COUNT(m.movie_id) >= 5
ORDER BY avg_roi DESC;


-- BQ2: "Which director should we hire for a guaranteed hit?"
-- Directors with best avg rating AND positive ROI (min 3 films)
WITH director_data AS (
    SELECT
        m.vote_average,
        m.roi,
        m.revenue,
        crew_member->>'name' AS director_name
    FROM movies m
    JOIN credits c ON m.movie_id = c.movie_id,
    json_array_elements(c.crew_raw::json) AS crew_member
    WHERE crew_member->>'job' = 'Director'
      AND m.roi IS NOT NULL
      AND m.vote_count > 200
)
SELECT
    director_name,
    COUNT(*)                         AS total_films,
    ROUND(AVG(vote_average), 2)      AS avg_rating,
    ROUND(AVG(roi), 2)               AS avg_roi,
    ROUND(SUM(revenue)/1000000.0, 1) AS career_revenue_millions
FROM director_data
GROUP BY director_name
HAVING COUNT(*) >= 3
   AND AVG(roi) > 2
   AND AVG(vote_average) > 7
ORDER BY avg_rating DESC
LIMIT 10;


-- BQ3: "Is December really the best month to release a film?"
-- Avg revenue and ROI by release month
SELECT
    TO_CHAR(release_date, 'MM - Month') AS release_month,
    COUNT(*)                             AS total_releases,
    ROUND(AVG(revenue)/1000000.0, 1)     AS avg_revenue_millions,
    ROUND(AVG(roi), 2)                   AS avg_roi,
    ROUND(AVG(vote_average), 2)          AS avg_rating
FROM movies
WHERE release_date IS NOT NULL
  AND roi IS NOT NULL
GROUP BY TO_CHAR(release_date, 'MM - Month')
ORDER BY release_month;


-- BQ4: "What makes a film go from good to great?"
-- Compare top 10% rated films vs bottom 10% — budget, runtime, language
WITH rating_bands AS (
    SELECT
        title,
        vote_average,
        budget,
        runtime,
        original_language,
        NTILE(10) OVER (ORDER BY vote_average) AS decile
    FROM movies
    WHERE vote_count > 200
      AND budget > 0
      AND runtime > 0
)
SELECT
    CASE
        WHEN decile = 10 THEN 'Top 10%'
        WHEN decile = 1  THEN 'Bottom 10%'
    END                                  AS rating_band,
    COUNT(*)                             AS total_films,
    ROUND(AVG(vote_average), 2)          AS avg_rating,
    ROUND(AVG(budget)/1000000.0, 1)      AS avg_budget_millions,
    ROUND(AVG(runtime), 1)               AS avg_runtime_mins
FROM rating_bands
WHERE decile IN (1, 10)
GROUP BY decile
ORDER BY decile DESC;


-- BQ5: "Which low-budget films massively outperformed expectations?"
-- Hidden gems: budget under $10M, ROI over 10x, rating over 6.5
SELECT
    m.title,
    EXTRACT(YEAR FROM m.release_date)  AS year,
    ROUND(m.budget/1000000.0, 2)       AS budget_millions,
    ROUND(m.revenue/1000000.0, 1)      AS revenue_millions,
    m.roi,
    m.vote_average,
    g.genre_name
FROM movies m
JOIN movie_genres mg ON m.movie_id = mg.movie_id
JOIN genres g        ON mg.genre_id = g.genre_id
WHERE m.budget BETWEEN 1000000 AND 10000000
  AND m.roi > 10
  AND m.vote_average > 6.5
ORDER BY m.roi DESC
LIMIT 15;


-- BQ6: "Has the film industry actually grown or just inflated?"
-- Revenue trend with movie count — quality vs quantity over decades
SELECT
    (EXTRACT(YEAR FROM release_date)::INTEGER / 10) * 10  AS decade,
    COUNT(*)                                               AS total_films,
    ROUND(AVG(revenue)/1000000.0, 1)                       AS avg_revenue_millions,
    ROUND(AVG(budget)/1000000.0, 1)                        AS avg_budget_millions,
    ROUND(AVG(vote_average), 2)                            AS avg_rating,
    ROUND(AVG(roi), 2)                                     AS avg_roi
FROM movies
WHERE release_date IS NOT NULL
  AND revenue > 0
  AND budget > 0
GROUP BY decade
ORDER BY decade;