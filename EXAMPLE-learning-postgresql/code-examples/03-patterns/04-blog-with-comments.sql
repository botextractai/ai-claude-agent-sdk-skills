-- Pattern: Blog with Comments and Nested Replies

\c patterns_demo

-- Users (authors and commenters)
CREATE TABLE blog_users (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    bio TEXT,
    avatar_url TEXT,
    is_author BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Blog posts
CREATE TABLE blog_posts (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    author_id INTEGER NOT NULL REFERENCES blog_users(id),
    title TEXT NOT NULL,
    slug VARCHAR(200) NOT NULL UNIQUE,
    excerpt TEXT,
    content TEXT NOT NULL,
    featured_image_url TEXT,
    is_published BOOLEAN DEFAULT FALSE,
    published_at TIMESTAMPTZ,
    view_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Post tags
CREATE TABLE tags (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    slug VARCHAR(50) NOT NULL UNIQUE
);

-- Junction table for post-tag relationship
CREATE TABLE post_tags (
    post_id INTEGER REFERENCES blog_posts(id) ON DELETE CASCADE,
    tag_id INTEGER REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, tag_id)
);

-- Comments (with support for nested replies)
CREATE TABLE comments (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES blog_posts(id) ON DELETE CASCADE,
    author_id INTEGER NOT NULL REFERENCES blog_users(id),
    parent_id INTEGER REFERENCES comments(id) ON DELETE CASCADE,  -- NULL for top-level comments
    content TEXT NOT NULL,
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Comment likes
CREATE TABLE comment_likes (
    comment_id INTEGER REFERENCES comments(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES blog_users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (comment_id, user_id)
);

-- Post views (for analytics)
CREATE TABLE post_views (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES blog_posts(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES blog_users(id) ON DELETE SET NULL,  -- NULL for anonymous
    ip_address INET,
    user_agent TEXT,
    viewed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data

-- Users
INSERT INTO blog_users (username, email, display_name, is_author, bio)
VALUES
    ('alice_dev', 'alice@example.com', 'Alice Johnson', TRUE, 'Senior PostgreSQL Developer'),
    ('bob_writer', 'bob@example.com', 'Bob Smith', TRUE, 'Technical Writer'),
    ('charlie_reader', 'charlie@example.com', 'Charlie Brown', FALSE, 'Database enthusiast'),
    ('diana_admin', 'diana@example.com', 'Diana Prince', FALSE, 'Learning PostgreSQL');

-- Tags
INSERT INTO tags (name, slug)
VALUES
    ('PostgreSQL', 'postgresql'),
    ('Database Design', 'database-design'),
    ('Performance', 'performance'),
    ('Best Practices', 'best-practices'),
    ('Tutorials', 'tutorials');

-- Posts
INSERT INTO blog_posts (author_id, title, slug, excerpt, content, is_published, published_at)
VALUES
    (1, 'Getting Started with PostgreSQL Indexes',
     'getting-started-with-postgresql-indexes',
     'Learn how to speed up your queries with proper indexing',
     'Full content about indexes... (truncated for example)',
     TRUE,
     NOW() - INTERVAL '5 days'),

    (1, 'Advanced Transaction Patterns',
     'advanced-transaction-patterns',
     'Mastering ACID compliance in PostgreSQL',
     'Full content about transactions... (truncated for example)',
     TRUE,
     NOW() - INTERVAL '2 days'),

    (2, '10 Common PostgreSQL Mistakes',
     '10-common-postgresql-mistakes',
     'Avoid these pitfalls when working with PostgreSQL',
     'Full content about mistakes... (truncated for example)',
     TRUE,
     NOW() - INTERVAL '1 day'),

    (1, 'Upcoming: Query Optimization Guide',
     'query-optimization-guide',
     'Coming soon: A comprehensive guide to query optimization',
     'Draft content...',
     FALSE,
     NULL);

-- Post tags
INSERT INTO post_tags (post_id, tag_id)
VALUES
    (1, 1), (1, 3), (1, 5),  -- Indexes post
    (2, 1), (2, 4),           -- Transactions post
    (3, 1), (3, 4), (3, 5);   -- Mistakes post

-- Comments (with nested replies)
INSERT INTO comments (post_id, author_id, parent_id, content)
VALUES
    -- Top-level comments on post 1
    (1, 3, NULL, 'Great article! This really helped me understand indexes better.'),
    (1, 4, NULL, 'Could you explain more about GIN indexes?'),

    -- Replies to comments
    (1, 1, 2, 'Sure! GIN indexes are great for JSON, arrays, and full-text search. I''ll write a follow-up post.'),
    (1, 4, 3, 'Thank you! Looking forward to it.'),

    -- Comments on post 2
    (2, 3, NULL, 'ACID compliance is so important. Thanks for covering this.'),
    (2, 4, NULL, 'What about savepoints? Are they commonly used?'),
    (2, 1, 6, 'Savepoints are useful for partial rollbacks. Great question!'),

    -- Comments on post 3
    (3, 3, NULL, 'I''ve made mistake #3 before! Good reminder.');

-- Comment likes
INSERT INTO comment_likes (comment_id, user_id)
VALUES
    (1, 1), (1, 2), (1, 4),  -- 3 likes on first comment
    (2, 1),                  -- 1 like
    (3, 3), (3, 4);          -- 2 likes

-- Post views
INSERT INTO post_views (post_id, user_id, ip_address)
SELECT
    1,
    CASE WHEN i % 3 = 0 THEN NULL ELSE (i % 4) + 1 END,  -- Some anonymous, some logged in
    ('192.168.1.' || (i % 255))::INET
FROM generate_series(1, 150) AS i;

INSERT INTO post_views (post_id, user_id, ip_address)
SELECT
    2,
    CASE WHEN i % 3 = 0 THEN NULL ELSE (i % 4) + 1 END,
    ('192.168.1.' || (i % 255))::INET
FROM generate_series(1, 89) AS i;

INSERT INTO post_views (post_id, user_id, ip_address)
SELECT
    3,
    CASE WHEN i % 3 = 0 THEN NULL ELSE (i % 4) + 1 END,
    ('192.168.1.' || (i % 255))::INET
FROM generate_series(1, 200) AS i;

-- Update view counts
UPDATE blog_posts p
SET view_count = (
    SELECT COUNT(*) FROM post_views WHERE post_id = p.id
);

-- Queries

-- Get published posts with author and comment count
SELECT
    p.title,
    u.display_name AS author,
    p.published_at,
    p.view_count,
    COUNT(DISTINCT c.id) AS comment_count,
    array_agg(DISTINCT t.name) AS tags
FROM blog_posts p
JOIN blog_users u ON p.author_id = u.id
LEFT JOIN comments c ON p.id = c.post_id
LEFT JOIN post_tags pt ON p.id = pt.post_id
LEFT JOIN tags t ON pt.tag_id = t.id
WHERE p.is_published = TRUE
GROUP BY p.id, p.title, u.display_name, p.published_at, p.view_count
ORDER BY p.published_at DESC;

-- Get a single post with all details
WITH post_data AS (
    SELECT
        p.id,
        p.title,
        p.slug,
        p.content,
        p.published_at,
        p.view_count,
        u.display_name AS author_name,
        u.avatar_url AS author_avatar,
        u.bio AS author_bio
    FROM blog_posts p
    JOIN blog_users u ON p.author_id = u.id
    WHERE p.slug = 'getting-started-with-postgresql-indexes'
    AND p.is_published = TRUE
)
SELECT
    pd.*,
    array_agg(DISTINCT t.name) AS tags
FROM post_data pd
LEFT JOIN post_tags pt ON pd.id = pt.post_id
LEFT JOIN tags t ON pt.tag_id = t.id
GROUP BY pd.id, pd.title, pd.slug, pd.content, pd.published_at, pd.view_count,
         pd.author_name, pd.author_avatar, pd.author_bio;

-- Get comments for a post (including nested replies)
WITH RECURSIVE comment_tree AS (
    -- Top-level comments
    SELECT
        c.id,
        c.post_id,
        c.author_id,
        c.parent_id,
        c.content,
        c.created_at,
        u.display_name AS author_name,
        u.avatar_url AS author_avatar,
        1 AS depth,
        ARRAY[c.id] AS path,
        (SELECT COUNT(*) FROM comment_likes WHERE comment_id = c.id) AS like_count
    FROM comments c
    JOIN blog_users u ON c.author_id = u.id
    WHERE c.post_id = 1
    AND c.parent_id IS NULL

    UNION ALL

    -- Nested replies
    SELECT
        c.id,
        c.post_id,
        c.author_id,
        c.parent_id,
        c.content,
        c.created_at,
        u.display_name,
        u.avatar_url,
        ct.depth + 1,
        ct.path || c.id,
        (SELECT COUNT(*) FROM comment_likes WHERE comment_id = c.id)
    FROM comments c
    JOIN blog_users u ON c.author_id = u.id
    JOIN comment_tree ct ON c.parent_id = ct.id
)
SELECT
    id,
    content,
    author_name,
    author_avatar,
    depth,
    like_count,
    created_at,
    REPEAT('  ', depth - 1) || author_name AS indented_author  -- Visual indentation
FROM comment_tree
ORDER BY path;

-- Popular posts (by views)
SELECT
    p.title,
    u.display_name AS author,
    p.view_count,
    COUNT(DISTINCT c.id) AS comment_count,
    p.published_at
FROM blog_posts p
JOIN blog_users u ON p.author_id = u.id
LEFT JOIN comments c ON p.id = c.post_id
WHERE p.is_published = TRUE
GROUP BY p.id, p.title, u.display_name, p.view_count, p.published_at
ORDER BY p.view_count DESC
LIMIT 10;

-- Posts by tag
SELECT
    t.name AS tag,
    p.title AS post_title,
    u.display_name AS author,
    p.view_count
FROM tags t
JOIN post_tags pt ON t.id = pt.tag_id
JOIN blog_posts p ON pt.post_id = p.id
JOIN blog_users u ON p.author_id = u.id
WHERE t.slug = 'postgresql'
AND p.is_published = TRUE
ORDER BY p.published_at DESC;

-- Most active commenters
SELECT
    u.display_name AS commenter,
    COUNT(c.id) AS comment_count,
    MIN(c.created_at) AS first_comment,
    MAX(c.created_at) AS latest_comment
FROM blog_users u
JOIN comments c ON u.id = c.author_id
GROUP BY u.id, u.display_name
ORDER BY comment_count DESC;

-- Most liked comments
SELECT
    c.content,
    u.display_name AS author,
    p.title AS post_title,
    COUNT(cl.user_id) AS like_count
FROM comments c
JOIN blog_users u ON c.author_id = u.id
JOIN blog_posts p ON c.post_id = p.id
LEFT JOIN comment_likes cl ON c.id = cl.comment_id
GROUP BY c.id, c.content, u.display_name, p.title
ORDER BY like_count DESC
LIMIT 10;

-- Related posts (by shared tags)
SELECT
    p2.title AS related_post,
    p2.slug,
    COUNT(DISTINCT pt2.tag_id) AS shared_tags
FROM blog_posts p1
JOIN post_tags pt1 ON p1.id = pt1.post_id
JOIN post_tags pt2 ON pt1.tag_id = pt2.tag_id
JOIN blog_posts p2 ON pt2.post_id = p2.id
WHERE p1.slug = 'getting-started-with-postgresql-indexes'
AND p2.id != p1.id
AND p2.is_published = TRUE
GROUP BY p2.id, p2.title, p2.slug
ORDER BY shared_tags DESC, p2.published_at DESC
LIMIT 5;

-- Analytics: Posts performance summary
SELECT
    u.display_name AS author,
    COUNT(p.id) AS total_posts,
    SUM(p.view_count) AS total_views,
    AVG(p.view_count) AS avg_views_per_post,
    COUNT(DISTINCT c.id) AS total_comments
FROM blog_users u
JOIN blog_posts p ON u.id = p.author_id
LEFT JOIN comments c ON p.id = c.post_id
WHERE p.is_published = TRUE
GROUP BY u.id, u.display_name
ORDER BY total_views DESC;

-- Function to increment view count
CREATE OR REPLACE FUNCTION record_post_view(
    p_post_id INTEGER,
    p_user_id INTEGER DEFAULT NULL,
    p_ip_address INET DEFAULT NULL
)
RETURNS void AS $$
BEGIN
    -- Record the view
    INSERT INTO post_views (post_id, user_id, ip_address)
    VALUES (p_post_id, p_user_id, p_ip_address);

    -- Increment view count
    UPDATE blog_posts
    SET view_count = view_count + 1
    WHERE id = p_post_id;
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT record_post_view(1, 3, '192.168.1.100'::INET);
SELECT view_count FROM blog_posts WHERE id = 1;
