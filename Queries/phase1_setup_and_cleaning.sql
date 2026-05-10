

-- Fix runtime column type
ALTER TABLE movies ALTER COLUMN runtime TYPE NUMERIC(6,1);

-- Import movies
COPY movies (
    budget, genres_raw, homepage, movie_id, keywords_raw,
    original_language, original_title, overview,
    popularity, production_companies_raw, production_countries_raw,
    release_date, revenue, runtime, spoken_languages_raw,
    status, tagline, title, vote_average, vote_count
)
FROM 'D:/Cinemetrics/Data/tmdb_5000_movies.csv'
DELIMITER ','
CSV HEADER;

-- Import credits
COPY credits (movie_id, title, cast_raw, crew_raw)
FROM 'D:/Cinemetrics/Data/tmdb_5000_credits.csv'
DELIMITER ','
CSV HEADER;

-- Verify both tables
SELECT 'movies' AS table_name, COUNT(*) AS row_count FROM movies
UNION ALL
SELECT 'credits', COUNT(*) FROM credits;

-- Quick data preview
SELECT movie_id, title, budget, revenue, vote_average, release_date
FROM movies
LIMIT 5;

-- Overall null/zero check
SELECT
    COUNT(*)                                      AS total_movies,
    COUNT(*) FILTER (WHERE budget = 0)            AS zero_budget,
    COUNT(*) FILTER (WHERE revenue = 0)           AS zero_revenue,
    COUNT(*) FILTER (WHERE budget > 0 
                     AND revenue > 0)             AS usable_for_roi,
    COUNT(*) FILTER (WHERE overview IS NULL)      AS null_overview,
    COUNT(*) FILTER (WHERE tagline IS NULL)       AS null_tagline,
    COUNT(*) FILTER (WHERE release_date IS NULL)  AS null_release_date,
    COUNT(*) FILTER (WHERE runtime IS NULL)       AS null_runtime,
    COUNT(*) FILTER (WHERE original_language 
                           IS NULL)               AS null_language
FROM movies;

-- Replace NULL overviews and taglines with empty string
UPDATE movies
SET overview = ''
WHERE overview IS NULL;

UPDATE movies
SET tagline = ''
WHERE tagline IS NULL;

UPDATE movies
SET homepage = ''
WHERE homepage IS NULL;

-- Add roi as a computed-ready column
ALTER TABLE movies ADD COLUMN roi NUMERIC(12,4);

-- Populate it (only where both budget and revenue are > 0)
UPDATE movies
SET roi = ROUND((revenue::NUMERIC / NULLIF(budget, 0)), 4)
WHERE budget > 0 AND revenue > 0;

ALTER TABLE movies ADD COLUMN profit BIGINT;

UPDATE movies
SET profit = revenue - budget
WHERE budget > 0 AND revenue > 0;

-- Step 5a: Populate genres lookup table from JSON
INSERT INTO genres (genre_id, genre_name)
SELECT DISTINCT
    (genre->>'id')::INTEGER   AS genre_id,
    genre->>'name'            AS genre_name
FROM movies,
     json_array_elements(genres_raw::json) AS genre
WHERE genres_raw IS NOT NULL
  AND genres_raw != '[]'
ON CONFLICT DO NOTHING;

-- Step 5b: Populate movie_genres bridge table
INSERT INTO movie_genres (movie_id, genre_id)
SELECT DISTINCT
    movie_id,
    (genre->>'id')::INTEGER AS genre_id
FROM movies,
     json_array_elements(genres_raw::json) AS genre
WHERE genres_raw IS NOT NULL
  AND genres_raw != '[]'
ON CONFLICT DO NOTHING;

-- Check genres populated correctly
SELECT genre_id, genre_name FROM genres ORDER BY genre_name;

-- Check movie_genres bridge
SELECT COUNT(*) AS total_mappings FROM movie_genres;

-- Check ROI and profit populated
SELECT title, budget, revenue, profit, roi
FROM movies
WHERE roi IS NOT NULL
ORDER BY roi DESC
LIMIT 10;

-- Final clean data count
SELECT
    COUNT(*)                               AS total,
    COUNT(*) FILTER (WHERE roi IS NOT NULL) AS has_roi,
    COUNT(*)  FILTER (WHERE profit IS NOT NULL) AS has_profit
FROM movies;

SELECT genre_id, genre_name FROM genres ORDER BY genre_name;


