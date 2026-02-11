-- Pattern: Timestamped Records
-- Automatically track when records are created and updated

CREATE DATABASE patterns_demo;
\c patterns_demo

-- Basic timestamped table
CREATE TABLE posts (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Function to automatically update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the function before updates
CREATE TRIGGER update_posts_updated_at
BEFORE UPDATE ON posts
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Test the pattern
INSERT INTO posts (title, content)
VALUES ('First Post', 'This is my first post');

SELECT * FROM posts;

-- Wait a moment, then update
SELECT pg_sleep(2);

UPDATE posts
SET content = 'This is my updated first post'
WHERE title = 'First Post';

-- updated_at is automatically updated
SELECT
    title,
    created_at,
    updated_at,
    updated_at - created_at AS time_since_creation
FROM posts;

-- More complex example with user tracking
CREATE TABLE articles (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by INTEGER NOT NULL, -- User who created it
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by INTEGER, -- User who last updated it
    version INTEGER DEFAULT 1 NOT NULL -- Track number of updates
);

-- Function to update timestamps and version
CREATE OR REPLACE FUNCTION update_article_metadata()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    NEW.version = OLD.version + 1;
    -- In real application, NEW.updated_by would be set by application code
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_articles_metadata
BEFORE UPDATE ON articles
FOR EACH ROW
EXECUTE FUNCTION update_article_metadata();

-- Test with versioning
INSERT INTO articles (title, content, created_by)
VALUES ('PostgreSQL Tips', 'Tip 1: Use indexes wisely', 1);

SELECT * FROM articles;

-- Update the article
UPDATE articles
SET content = 'Tip 1: Use indexes wisely. Tip 2: Use transactions.'
WHERE title = 'PostgreSQL Tips';

-- Version incremented, updated_at changed
SELECT title, version, created_at, updated_at FROM articles;

-- Query recently updated articles
SELECT
    title,
    updated_at,
    NOW() - updated_at AS time_since_update
FROM articles
WHERE updated_at > NOW() - INTERVAL '1 hour'
ORDER BY updated_at DESC;

-- Reusable approach: Apply to multiple tables
CREATE TABLE comments (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    article_id INTEGER REFERENCES articles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Reuse the same trigger function
CREATE TRIGGER update_comments_updated_at
BEFORE UPDATE ON comments
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Benefits demonstrated:
-- 1. Audit trail - know when data was created and changed
-- 2. Sorting - sort by recency
-- 3. Analytics - track activity patterns
-- 4. Debugging - identify stale or recently changed data

SELECT
    'posts' AS table_name,
    COUNT(*) AS total_records,
    MAX(created_at) AS last_created,
    MAX(updated_at) AS last_updated
FROM posts
UNION ALL
SELECT
    'articles',
    COUNT(*),
    MAX(created_at),
    MAX(updated_at)
FROM articles;
