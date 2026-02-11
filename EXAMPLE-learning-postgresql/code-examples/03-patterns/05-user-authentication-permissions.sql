-- Pattern: User Authentication and Role-Based Permissions

\c patterns_demo

-- Users table
CREATE TABLE auth_users (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,  -- NEVER store plain text passwords!
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    last_login_at TIMESTAMPTZ,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Roles
CREATE TABLE roles (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- User-Role junction table (many-to-many)
CREATE TABLE user_roles (
    user_id INTEGER REFERENCES auth_users(id) ON DELETE CASCADE,
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    assigned_by INTEGER REFERENCES auth_users(id),
    PRIMARY KEY (user_id, role_id)
);

-- Permissions
CREATE TABLE permissions (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    resource VARCHAR(50) NOT NULL,  -- e.g., 'posts', 'users', 'settings'
    action VARCHAR(20) NOT NULL,    -- e.g., 'create', 'read', 'update', 'delete'
    description TEXT,
    UNIQUE (resource, action)
);

-- Role-Permission junction table (many-to-many)
CREATE TABLE role_permissions (
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    permission_id INTEGER REFERENCES permissions(id) ON DELETE CASCADE,
    granted_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id, permission_id)
);

-- Password reset tokens
CREATE TABLE password_reset_tokens (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES auth_users(id) ON DELETE CASCADE,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Login history (audit log)
CREATE TABLE login_history (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES auth_users(id) ON DELETE CASCADE,
    ip_address INET,
    user_agent TEXT,
    success BOOLEAN NOT NULL,
    failure_reason TEXT,
    logged_in_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Session management
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INTEGER NOT NULL REFERENCES auth_users(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data

-- Create roles
INSERT INTO roles (name, description)
VALUES
    ('admin', 'Full system access'),
    ('editor', 'Can create and edit content'),
    ('moderator', 'Can moderate user content'),
    ('user', 'Basic user permissions');

-- Create permissions
INSERT INTO permissions (name, resource, action, description)
VALUES
    -- User management
    ('manage_users', 'users', 'manage', 'Full user management'),
    ('view_users', 'users', 'read', 'View user information'),

    -- Content management
    ('create_posts', 'posts', 'create', 'Create new posts'),
    ('edit_posts', 'posts', 'update', 'Edit posts'),
    ('delete_posts', 'posts', 'delete', 'Delete posts'),
    ('view_posts', 'posts', 'read', 'View posts'),
    ('publish_posts', 'posts', 'publish', 'Publish posts'),

    -- Comments
    ('create_comments', 'comments', 'create', 'Create comments'),
    ('moderate_comments', 'comments', 'moderate', 'Moderate comments'),
    ('delete_comments', 'comments', 'delete', 'Delete comments'),

    -- Settings
    ('manage_settings', 'settings', 'manage', 'Manage system settings'),
    ('view_settings', 'settings', 'read', 'View system settings');

-- Assign permissions to roles

-- Admin: All permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT
    (SELECT id FROM roles WHERE name = 'admin'),
    id
FROM permissions;

-- Editor: Content management
INSERT INTO role_permissions (role_id, permission_id)
SELECT
    (SELECT id FROM roles WHERE name = 'editor'),
    id
FROM permissions
WHERE resource IN ('posts', 'comments') AND action != 'delete';

-- Moderator: View and moderate
INSERT INTO role_permissions (role_id, permission_id)
SELECT
    (SELECT id FROM roles WHERE name = 'moderator'),
    id
FROM permissions
WHERE name IN ('view_users', 'view_posts', 'moderate_comments', 'delete_comments');

-- User: Basic permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT
    (SELECT id FROM roles WHERE name = 'user'),
    id
FROM permissions
WHERE name IN ('view_posts', 'create_comments');

-- Create sample users (passwords should be hashed with bcrypt/argon2 in production!)
-- Example: In application code: password_hash = bcrypt.hash('password123')
INSERT INTO auth_users (username, email, password_hash, is_verified)
VALUES
    ('admin_alice', 'alice@admin.com', '$2b$12$EXAMPLE_HASH_1', TRUE),
    ('editor_bob', 'bob@editor.com', '$2b$12$EXAMPLE_HASH_2', TRUE),
    ('mod_charlie', 'charlie@mod.com', '$2b$12$EXAMPLE_HASH_3', TRUE),
    ('user_diana', 'diana@user.com', '$2b$12$EXAMPLE_HASH_4', TRUE),
    ('user_eve', 'eve@user.com', '$2b$12$EXAMPLE_HASH_5', FALSE);

-- Assign roles to users
INSERT INTO user_roles (user_id, role_id)
VALUES
    (1, (SELECT id FROM roles WHERE name = 'admin')),
    (2, (SELECT id FROM roles WHERE name = 'editor')),
    (3, (SELECT id FROM roles WHERE name = 'moderator')),
    (4, (SELECT id FROM roles WHERE name = 'user')),
    (5, (SELECT id FROM roles WHERE name = 'user'));

-- Helper function: Check if user has permission
CREATE OR REPLACE FUNCTION user_has_permission(
    p_user_id INTEGER,
    p_permission_name VARCHAR(50)
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM user_roles ur
        JOIN role_permissions rp ON ur.role_id = rp.role_id
        JOIN permissions p ON rp.permission_id = p.id
        WHERE ur.user_id = p_user_id
        AND p.name = p_permission_name
    );
END;
$$ LANGUAGE plpgsql;

-- Helper function: Get all permissions for a user
CREATE OR REPLACE FUNCTION get_user_permissions(p_user_id INTEGER)
RETURNS TABLE(
    permission_name VARCHAR(50),
    resource VARCHAR(50),
    action VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        p.name,
        p.resource,
        p.action
    FROM user_roles ur
    JOIN role_permissions rp ON ur.role_id = rp.role_id
    JOIN permissions p ON rp.permission_id = p.id
    WHERE ur.user_id = p_user_id
    ORDER BY p.resource, p.action;
END;
$$ LANGUAGE plpgsql;

-- Function: Record login attempt
CREATE OR REPLACE FUNCTION record_login(
    p_username VARCHAR(50),
    p_ip_address INET,
    p_user_agent TEXT,
    p_success BOOLEAN,
    p_failure_reason TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_user_id INTEGER;
BEGIN
    -- Get user ID
    SELECT id INTO v_user_id
    FROM auth_users
    WHERE username = p_username;

    IF v_user_id IS NULL THEN
        -- User doesn't exist
        INSERT INTO login_history (user_id, ip_address, user_agent, success, failure_reason)
        VALUES (-1, p_ip_address, p_user_agent, FALSE, 'user_not_found');
        RETURN NULL;
    END IF;

    -- Record login attempt
    INSERT INTO login_history (user_id, ip_address, user_agent, success, failure_reason)
    VALUES (v_user_id, p_ip_address, p_user_agent, p_success, p_failure_reason);

    IF p_success THEN
        -- Reset failed attempts and update last login
        UPDATE auth_users
        SET
            failed_login_attempts = 0,
            last_login_at = CURRENT_TIMESTAMP,
            locked_until = NULL
        WHERE id = v_user_id;
    ELSE
        -- Increment failed attempts
        UPDATE auth_users
        SET failed_login_attempts = failed_login_attempts + 1
        WHERE id = v_user_id;

        -- Lock account after 5 failed attempts
        UPDATE auth_users
        SET locked_until = CURRENT_TIMESTAMP + INTERVAL '30 minutes'
        WHERE id = v_user_id
        AND failed_login_attempts >= 5;
    END IF;

    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Check if user account is locked
CREATE OR REPLACE FUNCTION is_account_locked(p_username VARCHAR(50))
RETURNS BOOLEAN AS $$
DECLARE
    v_locked_until TIMESTAMPTZ;
BEGIN
    SELECT locked_until INTO v_locked_until
    FROM auth_users
    WHERE username = p_username;

    RETURN v_locked_until IS NOT NULL AND v_locked_until > CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Function: Create password reset token
CREATE OR REPLACE FUNCTION create_password_reset_token(p_user_id INTEGER)
RETURNS TEXT AS $$
DECLARE
    v_token TEXT;
BEGIN
    -- Generate random token (in production, use cryptographically secure random)
    v_token := encode(gen_random_bytes(32), 'hex');

    -- Invalidate old tokens
    UPDATE password_reset_tokens
    SET used_at = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id
    AND used_at IS NULL
    AND expires_at > CURRENT_TIMESTAMP;

    -- Create new token (expires in 1 hour)
    INSERT INTO password_reset_tokens (user_id, token, expires_at)
    VALUES (p_user_id, v_token, CURRENT_TIMESTAMP + INTERVAL '1 hour');

    RETURN v_token;
END;
$$ LANGUAGE plpgsql;

-- Queries

-- Check if admin_alice has permission to manage users
SELECT user_has_permission(1, 'manage_users');  -- TRUE

-- Check if user_diana has permission to delete posts
SELECT user_has_permission(4, 'delete_posts');  -- FALSE

-- Get all permissions for editor_bob
SELECT * FROM get_user_permissions(2);

-- View all users with their roles
SELECT
    u.username,
    u.email,
    u.is_active,
    u.is_verified,
    array_agg(r.name) AS roles
FROM auth_users u
LEFT JOIN user_roles ur ON u.id = ur.user_id
LEFT JOIN roles r ON ur.role_id = r.id
GROUP BY u.id, u.username, u.email, u.is_active, u.is_verified
ORDER BY u.username;

-- View role permissions
SELECT
    r.name AS role,
    p.resource,
    p.action,
    p.description
FROM roles r
JOIN role_permissions rp ON r.id = rp.role_id
JOIN permissions p ON rp.permission_id = p.id
ORDER BY r.name, p.resource, p.action;

-- Test login recording
SELECT record_login('admin_alice', '192.168.1.100'::INET, 'Mozilla/5.0', TRUE);
SELECT record_login('user_diana', '192.168.1.101'::INET, 'Chrome/90', FALSE, 'invalid_password');

-- View login history
SELECT
    u.username,
    lh.ip_address,
    lh.success,
    lh.failure_reason,
    lh.logged_in_at
FROM login_history lh
JOIN auth_users u ON lh.user_id = u.id
ORDER BY lh.logged_in_at DESC
LIMIT 20;

-- Check for locked accounts
SELECT
    username,
    email,
    failed_login_attempts,
    locked_until,
    locked_until > CURRENT_TIMESTAMP AS is_locked
FROM auth_users
WHERE locked_until IS NOT NULL
ORDER BY locked_until DESC;

-- Security analytics

-- Most failed login attempts by user
SELECT
    u.username,
    u.email,
    COUNT(*) AS failed_attempts,
    MAX(lh.logged_in_at) AS last_attempt
FROM auth_users u
JOIN login_history lh ON u.id = lh.user_id
WHERE lh.success = FALSE
GROUP BY u.id, u.username, u.email
ORDER BY failed_attempts DESC;

-- Most common failure reasons
SELECT
    failure_reason,
    COUNT(*) AS count
FROM login_history
WHERE success = FALSE
GROUP BY failure_reason
ORDER BY count DESC;

-- Users who haven't verified their email
SELECT
    username,
    email,
    created_at,
    NOW() - created_at AS time_since_signup
FROM auth_users
WHERE is_verified = FALSE
ORDER BY created_at DESC;

-- Active sessions
SELECT
    u.username,
    s.ip_address,
    s.created_at,
    s.expires_at,
    s.expires_at > CURRENT_TIMESTAMP AS is_valid
FROM user_sessions s
JOIN auth_users u ON s.user_id = u.id
WHERE s.expires_at > CURRENT_TIMESTAMP
ORDER BY s.created_at DESC;

-- Role usage statistics
SELECT
    r.name AS role,
    COUNT(ur.user_id) AS user_count
FROM roles r
LEFT JOIN user_roles ur ON r.id = ur.role_id
GROUP BY r.id, r.name
ORDER BY user_count DESC;

-- Users with multiple roles
SELECT
    u.username,
    array_agg(r.name ORDER BY r.name) AS roles,
    COUNT(ur.role_id) AS role_count
FROM auth_users u
JOIN user_roles ur ON u.id = ur.user_id
JOIN roles r ON ur.role_id = r.id
GROUP BY u.id, u.username
HAVING COUNT(ur.role_id) > 1;

-- Cleanup: Remove expired password reset tokens
DELETE FROM password_reset_tokens
WHERE expires_at < CURRENT_TIMESTAMP
OR used_at IS NOT NULL;

-- Cleanup: Remove expired sessions
DELETE FROM user_sessions
WHERE expires_at < CURRENT_TIMESTAMP;
