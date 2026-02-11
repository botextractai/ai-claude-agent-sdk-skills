-- PostgreSQL Relationships and Joins Examples

\c core_concepts_demo

-- One-to-Many Relationship
-- One customer can have many orders

CREATE TABLE customers (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    order_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    total_amount NUMERIC(10, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending'
);

-- Insert sample data
INSERT INTO customers (name, email)
VALUES
    ('Alice Johnson', 'alice@example.com'),
    ('Bob Smith', 'bob@example.com'),
    ('Charlie Brown', 'charlie@example.com');

INSERT INTO orders (customer_id, total_amount, status)
VALUES
    (1, 150.00, 'completed'),
    (1, 200.00, 'completed'),
    (2, 75.50, 'pending'),
    (1, 300.00, 'shipped');
-- Note: Customer 3 (Charlie) has no orders

-- INNER JOIN
-- Returns only rows with matches in both tables
SELECT
    c.name AS customer_name,
    c.email,
    o.id AS order_id,
    o.total_amount,
    o.status
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;

-- LEFT JOIN (LEFT OUTER JOIN)
-- Returns all rows from left table, with NULLs for non-matching right table
SELECT
    c.name AS customer_name,
    c.email,
    o.id AS order_id,
    o.total_amount,
    o.status
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id;
-- Charlie appears with NULL order values

-- Find customers with no orders
SELECT
    c.name AS customer_name,
    c.email
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE o.id IS NULL;

-- RIGHT JOIN (RIGHT OUTER JOIN)
-- Returns all rows from right table, with NULLs for non-matching left table
SELECT
    c.name AS customer_name,
    o.id AS order_id,
    o.total_amount
FROM customers c
RIGHT JOIN orders o ON c.id = o.customer_id;
-- All orders appear (same as INNER JOIN in this case since all orders have customers)

-- FULL OUTER JOIN
-- Returns all rows from both tables, with NULLs for non-matches
SELECT
    c.name AS customer_name,
    o.id AS order_id,
    o.total_amount
FROM customers c
FULL OUTER JOIN orders o ON c.id = o.customer_id;

-- Aggregate with JOIN
-- Count orders per customer
SELECT
    c.name AS customer_name,
    COUNT(o.id) AS total_orders,
    COALESCE(SUM(o.total_amount), 0) AS total_spent
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.name
ORDER BY total_spent DESC;

-- Many-to-Many Relationship
-- Students can enroll in many courses, courses can have many students

CREATE TABLE students (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    enrollment_date DATE DEFAULT CURRENT_DATE
);

CREATE TABLE courses (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title TEXT NOT NULL,
    code VARCHAR(10) NOT NULL UNIQUE,
    credits INTEGER NOT NULL
);

-- Junction/Bridge table
CREATE TABLE enrollments (
    student_id INTEGER REFERENCES students(id) ON DELETE CASCADE,
    course_id INTEGER REFERENCES courses(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    grade VARCHAR(2),
    PRIMARY KEY (student_id, course_id)
);

-- Insert sample data
INSERT INTO students (name, email)
VALUES
    ('Emma Wilson', 'emma@university.edu'),
    ('Liam Davis', 'liam@university.edu'),
    ('Olivia Martinez', 'olivia@university.edu');

INSERT INTO courses (title, code, credits)
VALUES
    ('Introduction to PostgreSQL', 'CS101', 3),
    ('Data Structures', 'CS102', 4),
    ('Database Design', 'CS201', 3),
    ('Advanced SQL', 'CS301', 4);

INSERT INTO enrollments (student_id, course_id, grade)
VALUES
    (1, 1, 'A'),
    (1, 2, 'B+'),
    (1, 3, 'A-'),
    (2, 1, 'B'),
    (2, 3, 'A'),
    (3, 2, 'A'),
    (3, 4, 'B+');

-- Which courses is Emma taking?
SELECT
    s.name AS student_name,
    c.title AS course_title,
    c.code,
    e.grade
FROM students s
JOIN enrollments e ON s.id = e.student_id
JOIN courses c ON e.course_id = c.id
WHERE s.name = 'Emma Wilson';

-- Which students are in CS101?
SELECT
    s.name AS student_name,
    s.email,
    e.grade
FROM courses c
JOIN enrollments e ON c.id = e.course_id
JOIN students s ON e.student_id = s.id
WHERE c.code = 'CS101';

-- Count enrollments per course
SELECT
    c.title AS course_title,
    c.code,
    COUNT(e.student_id) AS total_students
FROM courses c
LEFT JOIN enrollments e ON c.id = e.course_id
GROUP BY c.id, c.title, c.code
ORDER BY total_students DESC;

-- Students with their total credits
SELECT
    s.name AS student_name,
    SUM(c.credits) AS total_credits
FROM students s
JOIN enrollments e ON s.id = e.student_id
JOIN courses c ON e.course_id = c.id
GROUP BY s.id, s.name
ORDER BY total_credits DESC;

-- One-to-One Relationship
-- One user has one profile

CREATE TABLE users (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_profiles (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    first_name TEXT,
    last_name TEXT,
    bio TEXT,
    avatar_url TEXT,
    date_of_birth DATE,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (username, email)
VALUES
    ('alice2025', 'alice@example.com'),
    ('bob_smith', 'bob@example.com');

INSERT INTO user_profiles (user_id, first_name, last_name, bio)
VALUES
    (1, 'Alice', 'Johnson', 'Software developer and PostgreSQL enthusiast'),
    (2, 'Bob', 'Smith', 'Data scientist');

-- Join users with their profiles
SELECT
    u.username,
    u.email,
    p.first_name,
    p.last_name,
    p.bio
FROM users u
LEFT JOIN user_profiles p ON u.id = p.user_id;

-- Self-Join
-- Referencing the same table (e.g., employee hierarchy)

CREATE TABLE employees (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    position TEXT NOT NULL,
    manager_id INTEGER REFERENCES employees(id),
    salary NUMERIC(10, 2)
);

INSERT INTO employees (name, position, manager_id, salary)
VALUES
    ('Sarah CEO', 'CEO', NULL, 200000),
    ('David CTO', 'CTO', 1, 150000),
    ('Emily CFO', 'CFO', 1, 150000),
    ('Michael Dev', 'Senior Developer', 2, 100000),
    ('Jessica Dev', 'Developer', 4, 80000),
    ('Andrew Dev', 'Developer', 4, 75000);

-- List employees with their managers
SELECT
    e.name AS employee_name,
    e.position AS employee_position,
    m.name AS manager_name,
    m.position AS manager_position
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;

-- Count direct reports per manager
SELECT
    m.name AS manager_name,
    COUNT(e.id) AS direct_reports
FROM employees m
LEFT JOIN employees e ON m.id = e.manager_id
GROUP BY m.id, m.name
HAVING COUNT(e.id) > 0
ORDER BY direct_reports DESC;

-- Multiple Joins
-- Complex query joining multiple tables

CREATE TABLE categories (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE products (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    category_id INTEGER REFERENCES categories(id),
    price NUMERIC(10, 2) NOT NULL
);

CREATE TABLE order_items (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL
);

-- Insert sample data
INSERT INTO categories (name) VALUES ('Electronics'), ('Books'), ('Clothing');

INSERT INTO products (name, category_id, price)
VALUES
    ('Laptop', 1, 999.99),
    ('Smartphone', 1, 699.99),
    ('PostgreSQL Book', 2, 49.99),
    ('T-Shirt', 3, 19.99);

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES
    (1, 1, 1, 999.99),
    (1, 3, 2, 49.99),
    (2, 2, 1, 699.99),
    (3, 4, 3, 19.99);

-- Complex query: Customer orders with product details and categories
SELECT
    c.name AS customer_name,
    o.id AS order_id,
    o.order_date,
    p.name AS product_name,
    cat.name AS category_name,
    oi.quantity,
    oi.unit_price,
    (oi.quantity * oi.unit_price) AS line_total
FROM customers c
JOIN orders o ON c.id = o.customer_id
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
JOIN categories cat ON p.category_id = cat.id
ORDER BY c.name, o.id;

-- Revenue by category
SELECT
    cat.name AS category,
    SUM(oi.quantity * oi.unit_price) AS total_revenue,
    COUNT(DISTINCT o.customer_id) AS unique_customers
FROM categories cat
JOIN products p ON cat.id = p.category_id
JOIN order_items oi ON p.id = oi.product_id
JOIN orders o ON oi.order_id = o.id
GROUP BY cat.id, cat.name
ORDER BY total_revenue DESC;

-- Subquery in JOIN
-- Using subquery results in joins

SELECT
    c.name AS customer_name,
    customer_stats.total_orders,
    customer_stats.total_spent
FROM customers c
JOIN (
    SELECT
        customer_id,
        COUNT(*) AS total_orders,
        SUM(total_amount) AS total_spent
    FROM orders
    GROUP BY customer_id
) AS customer_stats ON c.id = customer_stats.customer_id;

-- CROSS JOIN
-- Cartesian product (every row combined with every other row)

CREATE TABLE colors (name TEXT PRIMARY KEY);
CREATE TABLE sizes (name TEXT PRIMARY KEY);

INSERT INTO colors (name) VALUES ('Red'), ('Blue'), ('Green');
INSERT INTO sizes (name) VALUES ('Small'), ('Medium'), ('Large');

-- Generate all color-size combinations
SELECT
    c.name AS color,
    s.name AS size
FROM colors c
CROSS JOIN sizes s
ORDER BY c.name, s.name;

-- LATERAL JOIN
-- Each row from left table produces multiple rows from right side

CREATE TABLE departments (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL
);

INSERT INTO departments (name) VALUES ('Engineering'), ('Sales'), ('Marketing');

-- Get top 2 highest paid employees per department
SELECT
    d.name AS department,
    e.name AS employee,
    e.salary
FROM departments d
LEFT JOIN LATERAL (
    SELECT name, salary
    FROM employees
    WHERE position LIKE '%' || d.name || '%'
    ORDER BY salary DESC
    LIMIT 2
) e ON true;

-- Common Table Expressions (CTEs) with Joins
-- Make complex queries readable

WITH high_value_customers AS (
    SELECT
        customer_id,
        COUNT(*) AS order_count,
        SUM(total_amount) AS total_spent
    FROM orders
    GROUP BY customer_id
    HAVING SUM(total_amount) > 200
)
SELECT
    c.name AS customer_name,
    c.email,
    hvc.order_count,
    hvc.total_spent
FROM customers c
JOIN high_value_customers hvc ON c.id = hvc.customer_id
ORDER BY hvc.total_spent DESC;

-- Recursive CTE (for hierarchical data)
WITH RECURSIVE employee_hierarchy AS (
    -- Base case: CEO (no manager)
    SELECT
        id,
        name,
        position,
        manager_id,
        1 AS level,
        name::TEXT AS path
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    -- Recursive case: employees with managers
    SELECT
        e.id,
        e.name,
        e.position,
        e.manager_id,
        eh.level + 1,
        eh.path || ' > ' || e.name
    FROM employees e
    JOIN employee_hierarchy eh ON e.manager_id = eh.id
)
SELECT
    REPEAT('  ', level - 1) || name AS employee_hierarchy,
    position,
    level,
    path
FROM employee_hierarchy
ORDER BY path;

-- Performance Tips for Joins
-- 1. Index foreign keys
-- 2. Use EXPLAIN ANALYZE to check query plans
-- 3. Filter early (WHERE before JOIN when possible)
-- 4. Use EXISTS instead of IN for subqueries

-- Example: Efficient subquery
SELECT c.name
FROM customers c
WHERE EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id = c.id
    AND o.total_amount > 100
);
