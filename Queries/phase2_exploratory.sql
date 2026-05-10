

-- ============================================
-- CINEMETRICS — Phase 3: Exploratory Queries
-- ============================================

-- Q1: Top 10 highest grossing movies of all time
SELECT 
    title,
    ROUND(revenue / 1000000.0, 1) AS revenue_millions,
    ROUND(budget / 1000000.0, 1)  AS budget_millions,
    vote_average
FROM movies
WHERE revenue > 0
ORDER BY revenue DESC
LIMIT 10;

-- Q2: Average rating by genre
SELECT 
    g.genre_name,
    COUNT(m.movie_id)              AS total_movies,
    ROUND(AVG(m.vote_average), 2)  AS avg_rating,
    ROUND(AVG(m.vote_count), 0)    AS avg_votes
FROM movies m
JOIN movie_genres mg ON m.movie_id = mg.movie_id
JOIN genres g        ON mg.genre_id = g.genre_id
WHERE m.vote_count > 100
GROUP BY g.genre_name
ORDER BY avg_rating DESC;

-- Q3: Movies released per year (last 30 years)
SELECT 
    EXTRACT(YEAR FROM release_date) AS release_year,
    COUNT(*)                         AS movies_released,
    ROUND(AVG(vote_average), 2)      AS avg_rating
FROM movies
WHERE release_date >= '1995-01-01'
  AND release_date IS NOT NULL
GROUP BY release_year
ORDER BY release_year DESC;

-- Q4: Top 10 most profitable movies
SELECT 
    title,
    ROUND(budget / 1000000.0, 1)   AS budget_millions,
    ROUND(revenue / 1000000.0, 1)  AS revenue_millions,
    ROUND(profit / 1000000.0, 1)   AS profit_millions,
    roi
FROM movies
WHERE profit IS NOT NULL
ORDER BY profit DESC
LIMIT 10;

-- Q5: Top 10 best ROI movies (min budget $1M to filter micro films)
SELECT 
    title,
    ROUND(budget / 1000000.0, 2)   AS budget_millions,
    ROUND(revenue / 1000000.0, 2)  AS revenue_millions,
    roi
FROM movies
WHERE roi IS NOT NULL
  AND budget >= 1000000
ORDER BY roi DESC
LIMIT 10;

-- Q6: Genre popularity — which genres have the most movies?
SELECT 
    g.genre_name,
    COUNT(m.movie_id)              AS total_movies,
    ROUND(AVG(m.roi), 2)           AS avg_roi,
    ROUND(AVG(m.vote_average), 2)  AS avg_rating
FROM movies m
JOIN movie_genres mg ON m.movie_id = mg.movie_id
JOIN genres g        ON mg.genre_id = g.genre_id
GROUP BY g.genre_name
ORDER BY total_movies DESC;

-- Q7: Language distribution — top 10 languages
SELECT 
    original_language,
    COUNT(*)                        AS total_movies,
    ROUND(AVG(vote_average), 2)     AS avg_rating
FROM movies
GROUP BY original_language
ORDER BY total_movies DESC
LIMIT 10;

-- Q8: Movies with highest vote count (most reviewed)
SELECT 
    title,
    vote_count,
    vote_average,
    EXTRACT(YEAR FROM release_date) AS year
FROM movies
ORDER BY vote_count DESC
LIMIT 10;