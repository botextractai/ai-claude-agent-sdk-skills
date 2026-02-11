-- Pattern: Multi-Tenant SaaS Application
-- Isolate data for different customers (tenants)

\c patterns_demo

-- Tenants (organizations/companies using the SaaS)
CREATE TABLE tenants (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    subdomain VARCHAR(50) NOT NULL UNIQUE,
    plan VARCHAR(20) NOT NULL CHECK (plan IN ('free', 'starter', 'professional', 'enterprise')),
    max_users INTEGER NOT NULL DEFAULT 5,
    is_active BOOLEAN DEFAULT TRUE,
    trial_ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Users (scoped to tenants)
CREATE TABLE tenant_users (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    username VARCHAR(50) NOT NULL,
    password_hash TEXT NOT NULL,
    is_admin BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (tenant_id, email),
    UNIQUE (tenant_id, username)
);

-- Projects (scoped to tenants)
CREATE TABLE projects (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    owner_id INTEGER NOT NULL REFERENCES tenant_users(id),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'archived', 'deleted')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_owner_tenant CHECK (
        (SELECT tenant_id FROM tenant_users WHERE id = owner_id) = tenant_id
    )
);

-- Tasks (scoped to tenants via projects)
CREATE TABLE tasks (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    assigned_to INTEGER REFERENCES tenant_users(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'todo' CHECK (status IN ('todo', 'in_progress', 'done', 'cancelled')),
    priority VARCHAR(10) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    due_date DATE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_project_tenant CHECK (
        (SELECT tenant_id FROM projects WHERE id = project_id) = tenant_id
    ),
    CONSTRAINT fk_assignee_tenant CHECK (
        assigned_to IS NULL OR (SELECT tenant_id FROM tenant_users WHERE id = assigned_to) = tenant_id
    )
);

-- Activity log (audit trail per tenant)
CREATE TABLE activity_log (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES tenant_users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    resource_id INTEGER,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Tenant settings (custom configuration per tenant)
CREATE TABLE tenant_settings (
    tenant_id INTEGER PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE,
    settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for tenant_id (critical for multi-tenant performance!)
CREATE INDEX idx_tenant_users_tenant_id ON tenant_users(tenant_id);
CREATE INDEX idx_projects_tenant_id ON projects(tenant_id);
CREATE INDEX idx_tasks_tenant_id ON tasks(tenant_id);
CREATE INDEX idx_activity_log_tenant_id ON activity_log(tenant_id);

-- Enable Row-Level Security (RLS)
ALTER TABLE tenant_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- Create policies for Row-Level Security
-- Users can only see data from their tenant

CREATE POLICY tenant_isolation_policy ON tenant_users
    USING (tenant_id = current_setting('app.current_tenant_id')::INTEGER);

CREATE POLICY tenant_isolation_policy ON projects
    USING (tenant_id = current_setting('app.current_tenant_id')::INTEGER);

CREATE POLICY tenant_isolation_policy ON tasks
    USING (tenant_id = current_setting('app.current_tenant_id')::INTEGER);

CREATE POLICY tenant_isolation_policy ON activity_log
    USING (tenant_id = current_setting('app.current_tenant_id')::INTEGER);

-- Insert sample data

-- Create tenants
INSERT INTO tenants (name, subdomain, plan, max_users)
VALUES
    ('Acme Corporation', 'acme', 'professional', 50),
    ('TechStart Inc', 'techstart', 'starter', 10),
    ('Enterprise Solutions', 'enterprise', 'enterprise', 500);

-- Users for Acme Corporation (tenant_id = 1)
INSERT INTO tenant_users (tenant_id, email, username, password_hash, is_admin)
VALUES
    (1, 'alice@acme.com', 'alice', '$2b$12$HASH1', TRUE),
    (1, 'bob@acme.com', 'bob', '$2b$12$HASH2', FALSE),
    (1, 'charlie@acme.com', 'charlie', '$2b$12$HASH3', FALSE);

-- Users for TechStart Inc (tenant_id = 2)
INSERT INTO tenant_users (tenant_id, email, username, password_hash, is_admin)
VALUES
    (2, 'diana@techstart.com', 'diana', '$2b$12$HASH4', TRUE),
    (2, 'eve@techstart.com', 'eve', '$2b$12$HASH5', FALSE);

-- Users for Enterprise Solutions (tenant_id = 3)
INSERT INTO tenant_users (tenant_id, email, username, password_hash, is_admin)
VALUES
    (3, 'frank@enterprise.com', 'frank', '$2b$12$HASH6', TRUE);

-- Projects for Acme Corporation
INSERT INTO projects (tenant_id, name, description, owner_id)
VALUES
    (1, 'Website Redesign', 'Redesign company website', 1),
    (1, 'Mobile App', 'Develop mobile application', 1),
    (1, 'Marketing Campaign', 'Q1 marketing campaign', 2);

-- Projects for TechStart Inc
INSERT INTO projects (tenant_id, name, description, owner_id)
VALUES
    (2, 'Product Launch', 'Launch new product', 4),
    (2, 'Customer Research', 'Conduct customer surveys', 5);

-- Tasks for Acme Corporation
INSERT INTO tasks (tenant_id, project_id, title, assigned_to, status, priority, due_date)
VALUES
    (1, 1, 'Design mockups', 2, 'in_progress', 'high', CURRENT_DATE + INTERVAL '7 days'),
    (1, 1, 'Implement homepage', 3, 'todo', 'high', CURRENT_DATE + INTERVAL '14 days'),
    (1, 2, 'Setup development environment', 2, 'done', 'medium', CURRENT_DATE - INTERVAL '2 days'),
    (1, 2, 'Create API endpoints', 3, 'in_progress', 'high', CURRENT_DATE + INTERVAL '10 days');

-- Tasks for TechStart Inc
INSERT INTO tasks (tenant_id, project_id, title, assigned_to, status, priority, due_date)
VALUES
    (2, 4, 'Create landing page', 5, 'in_progress', 'urgent', CURRENT_DATE + INTERVAL '3 days'),
    (2, 4, 'Setup analytics', 4, 'todo', 'medium', CURRENT_DATE + INTERVAL '5 days');

-- Tenant settings
INSERT INTO tenant_settings (tenant_id, settings)
VALUES
    (1, '{"theme": "dark", "notifications": {"email": true, "slack": true}, "timezone": "America/New_York"}'::jsonb),
    (2, '{"theme": "light", "notifications": {"email": true}, "timezone": "America/Los_Angeles"}'::jsonb),
    (3, '{"theme": "light", "notifications": {"email": true, "slack": true, "sms": true}, "timezone": "Europe/London"}'::jsonb);

-- Functions

-- Function to log activity
CREATE OR REPLACE FUNCTION log_activity(
    p_tenant_id INTEGER,
    p_user_id INTEGER,
    p_action TEXT,
    p_resource_type VARCHAR(50),
    p_resource_id INTEGER,
    p_details JSONB DEFAULT NULL
)
RETURNS void AS $$
BEGIN
    INSERT INTO activity_log (tenant_id, user_id, action, resource_type, resource_id, details)
    VALUES (p_tenant_id, p_user_id, p_action, p_resource_type, p_resource_id, p_details);
END;
$$ LANGUAGE plpgsql;

-- Function to check tenant user limit
CREATE OR REPLACE FUNCTION check_user_limit()
RETURNS TRIGGER AS $$
DECLARE
    v_current_users INTEGER;
    v_max_users INTEGER;
BEGIN
    SELECT COUNT(*), t.max_users
    INTO v_current_users, v_max_users
    FROM tenant_users tu
    JOIN tenants t ON tu.tenant_id = t.id
    WHERE tu.tenant_id = NEW.tenant_id
    GROUP BY t.max_users;

    IF v_current_users >= v_max_users THEN
        RAISE EXCEPTION 'User limit reached for tenant %', NEW.tenant_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_user_limit
BEFORE INSERT ON tenant_users
FOR EACH ROW
EXECUTE FUNCTION check_user_limit();

-- Demo: Using Row-Level Security

-- Set tenant context for Acme Corporation (tenant_id = 1)
SET app.current_tenant_id = 1;

-- Query users (only sees Acme users)
SELECT id, username, email FROM tenant_users;

-- Query projects (only sees Acme projects)
SELECT id, name, owner_id FROM projects;

-- Query tasks (only sees Acme tasks)
SELECT id, title, status FROM tasks;

-- Switch to TechStart Inc (tenant_id = 2)
SET app.current_tenant_id = 2;

-- Now sees only TechStart data
SELECT id, username, email FROM tenant_users;
SELECT id, name, owner_id FROM projects;
SELECT id, title, status FROM tasks;

-- Reset tenant context
RESET app.current_tenant_id;

-- Queries (without RLS, for admin view)

-- View all tenants with user counts
SELECT
    t.name AS tenant_name,
    t.subdomain,
    t.plan,
    COUNT(DISTINCT tu.id) AS user_count,
    t.max_users,
    COUNT(DISTINCT p.id) AS project_count,
    COUNT(DISTINCT tk.id) AS task_count
FROM tenants t
LEFT JOIN tenant_users tu ON t.id = tu.tenant_id
LEFT JOIN projects p ON t.id = p.tenant_id
LEFT JOIN tasks tk ON t.id = tk.tenant_id
GROUP BY t.id, t.name, t.subdomain, t.plan, t.max_users
ORDER BY t.name;

-- Tenant activity summary
SELECT
    t.name AS tenant,
    u.username,
    al.action,
    al.resource_type,
    al.created_at
FROM activity_log al
JOIN tenants t ON al.tenant_id = t.id
LEFT JOIN tenant_users u ON al.user_id = u.id
ORDER BY al.created_at DESC
LIMIT 20;

-- Task completion rate by tenant
SELECT
    t.name AS tenant,
    COUNT(*) AS total_tasks,
    COUNT(*) FILTER (WHERE tk.status = 'done') AS completed_tasks,
    ROUND(
        COUNT(*) FILTER (WHERE tk.status = 'done')::NUMERIC /
        NULLIF(COUNT(*), 0) * 100,
        2
    ) AS completion_rate
FROM tenants t
LEFT JOIN tasks tk ON t.id = tk.tenant_id
GROUP BY t.id, t.name
ORDER BY completion_rate DESC;

-- Overdue tasks by tenant
SELECT
    t.name AS tenant,
    p.name AS project,
    tk.title AS task,
    tk.due_date,
    CURRENT_DATE - tk.due_date AS days_overdue,
    u.username AS assigned_to
FROM tasks tk
JOIN tenants t ON tk.tenant_id = t.id
JOIN projects p ON tk.project_id = p.id
LEFT JOIN tenant_users u ON tk.assigned_to = u.id
WHERE tk.due_date < CURRENT_DATE
AND tk.status NOT IN ('done', 'cancelled')
ORDER BY days_overdue DESC;

-- Tenant resource usage (for billing)
CREATE VIEW tenant_usage AS
SELECT
    t.id AS tenant_id,
    t.name AS tenant_name,
    t.plan,
    COUNT(DISTINCT tu.id) AS active_users,
    t.max_users,
    COUNT(DISTINCT p.id) AS project_count,
    COUNT(DISTINCT tk.id) AS task_count,
    COUNT(DISTINCT al.id) AS activity_count
FROM tenants t
LEFT JOIN tenant_users tu ON t.id = tu.tenant_id AND tu.is_active = TRUE
LEFT JOIN projects p ON t.id = p.tenant_id AND p.status = 'active'
LEFT JOIN tasks tk ON t.id = tk.tenant_id
LEFT JOIN activity_log al ON t.id = al.tenant_id
WHERE t.is_active = TRUE
GROUP BY t.id, t.name, t.plan, t.max_users;

SELECT * FROM tenant_usage;

-- Tenants approaching user limit
SELECT
    name AS tenant,
    plan,
    active_users,
    max_users,
    ROUND((active_users::NUMERIC / max_users) * 100, 1) AS usage_percent
FROM tenant_usage
WHERE active_users::NUMERIC / max_users > 0.8
ORDER BY usage_percent DESC;

-- Performance note: Always include tenant_id in WHERE clauses
-- Good query (uses index):
EXPLAIN ANALYZE
SELECT * FROM tasks WHERE tenant_id = 1 AND status = 'todo';

-- Bad query (full table scan):
-- EXPLAIN ANALYZE
-- SELECT * FROM tasks WHERE status = 'todo';

-- Security best practices for multi-tenant apps:
-- 1. Always filter by tenant_id in queries
-- 2. Use Row-Level Security policies
-- 3. Set tenant context at application level (SET app.current_tenant_id)
-- 4. Index all tenant_id columns
-- 5. Validate tenant_id in foreign key relationships
-- 6. Log all cross-tenant access attempts (security audit)
-- 7. Implement rate limiting per tenant
-- 8. Backup data per tenant for easy restoration
