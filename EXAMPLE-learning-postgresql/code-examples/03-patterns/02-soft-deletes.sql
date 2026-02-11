-- Pattern: Soft Deletes
-- Mark records as deleted instead of removing them

\c patterns_demo

-- Basic soft delete pattern
CREATE TABLE users (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    deleted_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Insert sample users
INSERT INTO users (username, email)
VALUES
    ('alice', 'alice@example.com'),
    ('bob', 'bob@example.com'),
    ('charlie', 'charlie@example.com');

SELECT * FROM users;

-- "Delete" a user (soft delete)
UPDATE users
SET deleted_at = CURRENT_TIMESTAMP
WHERE username = 'bob';

-- Query only active users
SELECT * FROM users WHERE deleted_at IS NULL;

-- Query deleted users
SELECT * FROM users WHERE deleted_at IS NOT NULL;

-- View for active users only
CREATE VIEW active_users AS
SELECT id, username, email, created_at
FROM users
WHERE deleted_at IS NULL;

-- Use the view
SELECT * FROM active_users;

-- Restore a soft-deleted user
UPDATE users
SET deleted_at = NULL
WHERE username = 'bob';

SELECT * FROM active_users;

-- Handling unique constraints with soft deletes
-- Problem: Can't have two users with same username if one is soft-deleted

DROP TABLE users CASCADE;

CREATE TABLE users (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email TEXT NOT NULL,
    deleted_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    -- Unique only for non-deleted users
    CONSTRAINT unique_active_username UNIQUE (username) WHERE (deleted_at IS NULL),
    CONSTRAINT unique_active_email UNIQUE (email) WHERE (deleted_at IS NULL)
);

INSERT INTO users (username, email)
VALUES
    ('alice', 'alice@example.com'),
    ('bob', 'bob@example.com');

-- Soft delete bob
UPDATE users SET deleted_at = CURRENT_TIMESTAMP WHERE username = 'bob';

-- Now we can create a new user with the same username
INSERT INTO users (username, email)
VALUES ('bob', 'bob_new@example.com');

SELECT * FROM users;

-- Soft deletes with cascading
CREATE TABLE posts (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    deleted_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

INSERT INTO posts (user_id, title, content)
SELECT
    u.id,
    'Post by ' || u.username,
    'Content of post by ' || u.username
FROM active_users u;

-- Function to cascade soft deletes
CREATE OR REPLACE FUNCTION soft_delete_user_cascade()
RETURNS TRIGGER AS $$
BEGIN
    -- When a user is soft-deleted, soft-delete their posts too
    IF NEW.deleted_at IS NOT NULL AND (OLD.deleted_at IS NULL OR OLD.deleted_at IS DISTINCT FROM NEW.deleted_at) THEN
        UPDATE posts
        SET deleted_at = NEW.deleted_at
        WHERE user_id = NEW.id AND deleted_at IS NULL;
    END IF;

    -- When a user is restored, restore their posts too
    IF NEW.deleted_at IS NULL AND OLD.deleted_at IS NOT NULL THEN
        UPDATE posts
        SET deleted_at = NULL
        WHERE user_id = NEW.id AND deleted_at = OLD.deleted_at;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_soft_delete_cascade
AFTER UPDATE OF deleted_at ON users
FOR EACH ROW
EXECUTE FUNCTION soft_delete_user_cascade();

-- Test cascading soft delete
UPDATE users SET deleted_at = CURRENT_TIMESTAMP WHERE username = 'alice';

-- Alice's posts are also soft-deleted
SELECT p.title, p.deleted_at, u.username, u.deleted_at
FROM posts p
JOIN users u ON p.user_id = u.id;

-- Restore alice and her posts
UPDATE users SET deleted_at = NULL WHERE username = 'alice';

-- Posts are restored
SELECT p.title, p.deleted_at IS NULL AS is_active
FROM posts p
JOIN users u ON p.user_id = u.id
WHERE u.username = 'alice';

-- Automatic cleanup: Permanently delete old soft-deleted records
CREATE OR REPLACE FUNCTION cleanup_old_soft_deleted()
RETURNS void AS $$
BEGIN
    -- Delete users soft-deleted more than 90 days ago
    DELETE FROM users
    WHERE deleted_at < NOW() - INTERVAL '90 days';

    -- Delete posts soft-deleted more than 90 days ago
    DELETE FROM posts
    WHERE deleted_at < NOW() - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- Schedule this function to run periodically (use pg_cron extension or external scheduler)

-- Analytics: Track deletion patterns
CREATE VIEW deletion_stats AS
SELECT
    'users' AS table_name,
    COUNT(*) FILTER (WHERE deleted_at IS NULL) AS active_count,
    COUNT(*) FILTER (WHERE deleted_at IS NOT NULL) AS deleted_count,
    COUNT(*) AS total_count
FROM users
UNION ALL
SELECT
    'posts',
    COUNT(*) FILTER (WHERE deleted_at IS NULL),
    COUNT(*) FILTER (WHERE deleted_at IS NOT NULL),
    COUNT(*)
FROM posts;

SELECT * FROM deletion_stats;

-- Advanced: Track who deleted the record
ALTER TABLE users ADD COLUMN deleted_by INTEGER;
ALTER TABLE posts ADD COLUMN deleted_by INTEGER;

-- Helper function to soft delete with tracking
CREATE OR REPLACE FUNCTION soft_delete_user(p_user_id INTEGER, p_deleted_by INTEGER)
RETURNS void AS $$
BEGIN
    UPDATE users
    SET
        deleted_at = CURRENT_TIMESTAMP,
        deleted_by = p_deleted_by
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- Benefits:
-- 1. Data recovery - restore accidentally deleted records
-- 2. Audit trail - know when and who deleted data
-- 3. Referential integrity - maintain foreign key relationships
-- 4. Analytics - analyze deleted records

-- Trade-offs:
-- 1. Unique constraints become complex
-- 2. Must always filter deleted_at IS NULL in queries
-- 3. Database grows larger (store deleted records)
-- 4. More complex application logic
