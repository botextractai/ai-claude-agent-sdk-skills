-- PostgreSQL Indexes Examples
-- Indexes speed up queries by creating efficient lookup structures

\c core_concepts_demo

-- Create a sample table with data
CREATE TABLE users_large (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    first_name TEXT,
    last_name TEXT,
    city TEXT,
    country TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data (in production this would be thousands/millions of rows)
INSERT INTO users_large (username, email, first_name, last_name, city, country)
SELECT
    'user' || i,
    'user' || i || '@example.com',
    'FirstName' || i,
    'LastName' || i,
    CASE (i % 5)
        WHEN 0 THEN 'New York'
        WHEN 1 THEN 'London'
        WHEN 2 THEN 'Tokyo'
        WHEN 3 THEN 'Paris'
        ELSE 'Berlin'
    END,
    CASE (i % 3)
        WHEN 0 THEN 'USA'
        WHEN 1 THEN 'UK'
        ELSE 'Japan'
    END
FROM generate_series(1, 10000) AS i;

-- Query without index (slow on large tables)
EXPLAIN ANALYZE
SELECT * FROM users_large WHERE city = 'Tokyo';

-- B-tree Index (Default)
-- Good for equality and range queries
CREATE INDEX idx_users_city ON users_large(city);

-- Now the query uses the index (much faster)
EXPLAIN ANALYZE
SELECT * FROM users_large WHERE city = 'Tokyo';

-- Index on foreign key
CREATE TABLE posts (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users_large(id),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create index on foreign key for faster joins
CREATE INDEX idx_posts_user_id ON posts(user_id);

-- Composite Index
-- Index on multiple columns (order matters!)
CREATE INDEX idx_users_country_city ON users_large(country, city);

-- This query benefits from the composite index
EXPLAIN ANALYZE
SELECT * FROM users_large WHERE country = 'USA' AND city = 'New York';

-- This query also benefits (uses leftmost column)
EXPLAIN ANALYZE
SELECT * FROM users_large WHERE country = 'USA';

-- This query does NOT benefit much (skips leftmost column)
EXPLAIN ANALYZE
SELECT * FROM users_large WHERE city = 'New York';

-- Unique Index
-- Automatically created by UNIQUE constraint, but can be explicit
CREATE UNIQUE INDEX idx_users_email_unique ON users_large(email);

-- Partial Index
-- Indexes only rows that meet a condition (smaller, faster)
CREATE INDEX idx_active_users ON users_large(email) WHERE is_active = TRUE;

-- This query benefits from the partial index
EXPLAIN ANALYZE
SELECT * FROM users_large WHERE email LIKE '%example%' AND is_active = TRUE;

-- Another partial index example
CREATE INDEX idx_recent_posts ON posts(created_at)
WHERE created_at >= '2025-01-01';

-- Expression Index
-- Indexes computed values
CREATE INDEX idx_users_lower_username ON users_large(LOWER(username));

-- This query benefits from the expression index
EXPLAIN ANALYZE
SELECT * FROM users_large WHERE LOWER(username) = 'user1234';

-- Another expression index
CREATE INDEX idx_users_full_name ON users_large((first_name || ' ' || last_name));

EXPLAIN ANALYZE
SELECT * FROM users_large WHERE (first_name || ' ' || last_name) = 'FirstName100 LastName100';

-- GIN Index (Generalized Inverted Index)
-- Great for JSON, arrays, and full-text search

-- Array example
CREATE TABLE articles (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tags TEXT[]
);

INSERT INTO articles (title, content, tags)
SELECT
    'Article ' || i,
    'Content for article ' || i,
    ARRAY['tag' || (i % 10), 'category' || (i % 5)]
FROM generate_series(1, 1000) AS i;

-- Create GIN index on array column
CREATE INDEX idx_articles_tags ON articles USING GIN(tags);

-- Fast array containment search
EXPLAIN ANALYZE
SELECT * FROM articles WHERE tags @> ARRAY['tag5'];

-- JSONB example
CREATE TABLE events (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_data JSONB NOT NULL
);

INSERT INTO events (event_data)
SELECT jsonb_build_object(
    'user_id', i,
    'event_type', CASE (i % 3) WHEN 0 THEN 'login' WHEN 1 THEN 'logout' ELSE 'purchase' END,
    'timestamp', NOW()
)
FROM generate_series(1, 1000) AS i;

-- Create GIN index on JSONB column
CREATE INDEX idx_events_data ON events USING GIN(event_data);

-- Fast JSONB containment search
EXPLAIN ANALYZE
SELECT * FROM events WHERE event_data @> '{"event_type": "purchase"}'::jsonb;

-- Full-Text Search Index
ALTER TABLE articles ADD COLUMN search_vector tsvector;

UPDATE articles
SET search_vector = to_tsvector('english', title || ' ' || content);

-- Create GIN index for full-text search
CREATE INDEX idx_articles_search ON articles USING GIN(search_vector);

-- Fast full-text search
EXPLAIN ANALYZE
SELECT title, ts_rank(search_vector, query) AS rank
FROM articles, to_tsquery('english', 'article & content') AS query
WHERE search_vector @@ query
ORDER BY rank DESC
LIMIT 10;

-- GiST Index (Generalized Search Tree)
-- Good for geometric data, ranges, and text similarity

-- Range example with room bookings
CREATE TABLE bookings (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_number INTEGER NOT NULL,
    booking_period TSTZRANGE NOT NULL
);

-- Create GiST index for range searches
CREATE INDEX idx_bookings_period ON bookings USING GIST(booking_period);

INSERT INTO bookings (room_number, booking_period)
SELECT
    (i % 10) + 100,
    tstzrange(
        CURRENT_TIMESTAMP + (i || ' hours')::interval,
        CURRENT_TIMESTAMP + ((i + 2) || ' hours')::interval
    )
FROM generate_series(1, 1000) AS i;

-- Fast range overlap search
EXPLAIN ANALYZE
SELECT * FROM bookings
WHERE booking_period && tstzrange('2025-02-10 12:00:00+00', '2025-02-10 14:00:00+00');

-- BRIN Index (Block Range Index)
-- Efficient for very large tables with naturally ordered data
CREATE TABLE sensor_readings (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sensor_id INTEGER NOT NULL,
    reading NUMERIC(10, 2) NOT NULL,
    recorded_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Insert time-series data
INSERT INTO sensor_readings (sensor_id, reading, recorded_at)
SELECT
    (i % 100) + 1,
    random() * 100,
    CURRENT_TIMESTAMP - ((1000000 - i) || ' minutes')::interval
FROM generate_series(1, 100000) AS i;

-- Create BRIN index (very small, efficient for time-series)
CREATE INDEX idx_sensor_readings_time ON sensor_readings USING BRIN(recorded_at);

-- Fast time-range queries
EXPLAIN ANALYZE
SELECT AVG(reading) FROM sensor_readings
WHERE recorded_at >= CURRENT_TIMESTAMP - INTERVAL '7 days';

-- Covering Index (Index-Only Scan)
-- Includes all columns needed by the query
CREATE INDEX idx_users_covering ON users_large(country, city, username);

-- This query only touches the index (index-only scan)
EXPLAIN ANALYZE
SELECT country, city, username
FROM users_large
WHERE country = 'USA';

-- Managing Indexes

-- View all indexes on a table
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'users_large';

-- Check index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan;

-- Find unused indexes
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND schemaname = 'public'
AND indexname NOT LIKE '%_pkey'; -- Exclude primary keys

-- Reindex (rebuild an index)
REINDEX INDEX idx_users_city;

-- Reindex entire table
REINDEX TABLE users_large;

-- Drop an unused index
-- DROP INDEX idx_users_city;

-- Index Maintenance Tips

-- 1. Monitor index bloat
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;

-- 2. Analyze table statistics (helps query planner)
ANALYZE users_large;

-- 3. View table and index sizes
SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size(tablename::regclass)) AS total_size,
    pg_size_pretty(pg_relation_size(tablename::regclass)) AS table_size,
    pg_size_pretty(pg_total_relation_size(tablename::regclass) - pg_relation_size(tablename::regclass)) AS indexes_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(tablename::regclass) DESC;

-- Best Practices Summary
-- 1. Index foreign keys for faster joins
-- 2. Index columns used in WHERE, JOIN, and ORDER BY
-- 3. Use composite indexes for multi-column queries (leftmost first)
-- 4. Use partial indexes for frequently filtered subsets
-- 5. Use GIN for JSON, arrays, and full-text search
-- 6. Use BRIN for large time-series data
-- 7. Monitor index usage and remove unused indexes
-- 8. Don't over-index - each index slows down writes
