-- ============================================
-- CINEMETRICS Phase 4 — Advanced Analysis
-- ============================================

-- A1: Rank movies by revenue WITHIN each genre
-- (window function over a partition)
SELECT
    g.genre_name,
    m.title,
    ROUND(m.revenue / 1000000.0, 1)  AS revenue_millions,
    RANK() OVER (
        PARTITION BY g.genre_name
        ORDER BY m.revenue DESC
    )                                 AS rank_in_genre
FROM movies m
JOIN movie_genres mg ON m.movie_id = mg.movie_id
JOIN genres g        ON mg.genre_id = g.genre_id
WHERE m.revenue > 0
ORDER BY g.genre_name, rank_in_genre
LIMIT 40;

-- A2: Running total of revenue by release year
SELECT
    EXTRACT(YEAR FROM release_date)       AS year,
    ROUND(SUM(revenue)/1000000.0, 1)      AS yearly_revenue_millions,
    ROUND(SUM(SUM(revenue)) OVER (
        ORDER BY EXTRACT(YEAR FROM release_date)
    ) / 1000000.0, 1)                     AS running_total_millions
FROM movies
WHERE release_date IS NOT NULL
  AND revenue > 0
GROUP BY year
ORDER BY year;

-- A3: Movie rating percentile — where does each film rank?
SELECT
    title,
    vote_average,
    vote_count,
    ROUND(
        PERCENT_RANK() OVER (ORDER BY vote_average)::NUMERIC * 100
    , 1)                              AS rating_percentile,
    NTILE(10) OVER 
        (ORDER BY vote_average)       AS decile
FROM movies
WHERE vote_count > 500
ORDER BY vote_average DESC
LIMIT 20;

-- A4: Director ROI analysis using CTE
-- (parse director from crew JSON)
WITH director_data AS (
    SELECT
        m.movie_id,
        m.title,
        m.budget,
        m.revenue,
        m.roi,
        m.vote_average,
        crew_member->>'name' AS director_name
    FROM movies m
    JOIN credits c ON m.movie_id = c.movie_id,
    json_array_elements(c.crew_raw::json) AS crew_member
    WHERE crew_member->>'job' = 'Director'
      AND m.roi IS NOT NULL
),
director_stats AS (
    SELECT
        director_name,
        COUNT(*)                        AS total_films,
        ROUND(AVG(roi), 2)              AS avg_roi,
        ROUND(AVG(vote_average), 2)     AS avg_rating,
        ROUND(SUM(revenue)/1000000.0,1) AS total_revenue_millions
    FROM director_data
    GROUP BY director_name
    HAVING COUNT(*) >= 3
)
SELECT *
FROM director_stats
ORDER BY avg_roi DESC
LIMIT 15;

-- A5: Genre revenue share using CTE
WITH genre_revenue AS (
    SELECT
        g.genre_name,
        SUM(m.revenue)              AS total_revenue
    FROM movies m
    JOIN movie_genres mg ON m.movie_id = mg.movie_id
    JOIN genres g        ON mg.genre_id = g.genre_id
    WHERE m.revenue > 0
    GROUP BY g.genre_name
),
total AS (
    SELECT SUM(total_revenue) AS grand_total
    FROM genre_revenue
)
SELECT
    gr.genre_name,
    ROUND(gr.total_revenue / 1000000000.0, 2) AS revenue_billions,
    ROUND(gr.total_revenue * 100.0 / t.grand_total, 2) AS revenue_share_pct
FROM genre_revenue gr, total t
ORDER BY revenue_billions DESC;

-- A6: Movies that outperformed their genre average ROI
SELECT
    m.title,
    g.genre_name,
    m.roi,
    ROUND(genre_avg.avg_genre_roi, 2)   AS genre_avg_roi,
    ROUND(m.roi - genre_avg.avg_genre_roi, 2) AS roi_above_average
FROM movies m
JOIN movie_genres mg ON m.movie_id = mg.movie_id
JOIN genres g ON mg.genre_id = g.genre_id
JOIN (
    SELECT
        mg2.genre_id,
        AVG(m2.roi) AS avg_genre_roi
    FROM movies m2
    JOIN movie_genres mg2 ON m2.movie_id = mg2.movie_id
    WHERE m2.roi IS NOT NULL
    GROUP BY mg2.genre_id
) AS genre_avg ON mg.genre_id = genre_avg.genre_id
WHERE m.roi IS NOT NULL
  AND m.roi > genre_avg.avg_genre_roi
ORDER BY roi_above_average DESC
LIMIT 15;

-- A7: Year-over-year revenue growth using LAG
WITH yearly AS (
    SELECT
        EXTRACT(YEAR FROM release_date)  AS yr,
        ROUND(SUM(revenue)/1000000.0, 1) AS revenue_millions
    FROM movies
    WHERE release_date IS NOT NULL
      AND revenue > 0
      AND EXTRACT(YEAR FROM release_date) BETWEEN 1990 AND 2016
    GROUP BY yr
)
SELECT
    yr,
    revenue_millions,
    LAG(revenue_millions) OVER (ORDER BY yr) AS prev_year_revenue,
    ROUND(
        (revenue_millions - LAG(revenue_millions) OVER (ORDER BY yr))
        / NULLIF(LAG(revenue_millions) OVER (ORDER BY yr), 0) * 100
    , 1)                                      AS yoy_growth_pct
FROM yearly
ORDER BY yr;

-- A8: Top actor by total revenue (from cast JSON)
WITH actor_data AS (
    SELECT
        cast_member->>'name'             AS actor_name,
        (cast_member->>'order')::INTEGER AS billing_order,
        m.revenue
    FROM credits c
    JOIN movies m ON c.movie_id = m.movie_id,
    json_array_elements(c.cast_raw::json) AS cast_member
    WHERE m.revenue > 0
      AND (cast_member->>'order')::INTEGER < 3
),
actor_stats AS (
    SELECT
        actor_name,
        COUNT(*)                         AS total_films,
        ROUND(SUM(revenue)/1000000.0, 1) AS total_revenue_millions,
        ROUND(AVG(revenue)/1000000.0, 1) AS avg_revenue_millions
    FROM actor_data
    GROUP BY actor_name
    HAVING COUNT(*) >= 5
)
SELECT *
FROM actor_stats
ORDER BY total_revenue_millions DESC
LIMIT 15;