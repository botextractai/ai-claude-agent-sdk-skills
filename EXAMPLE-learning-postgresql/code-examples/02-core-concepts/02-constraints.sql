-- PostgreSQL Constraints Examples
-- Constraints enforce data integrity rules

\c core_concepts_demo

-- NOT NULL Constraint
-- Ensures a column always has a value
CREATE TABLE users (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(50) NOT NULL,       -- Username is required
    email TEXT NOT NULL,                 -- Email is required
    bio TEXT,                            -- Bio is optional
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- This will succeed
INSERT INTO users (username, email) VALUES ('alice', 'alice@example.com');

-- This will fail - username cannot be NULL
-- INSERT INTO users (email) VALUES ('bob@example.com');

-- UNIQUE Constraint
-- Ensures no two rows have the same value
CREATE TABLE products (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku VARCHAR(20) NOT NULL UNIQUE,     -- SKU must be unique
    name TEXT NOT NULL,
    price NUMERIC(10, 2) NOT NULL
);

INSERT INTO products (sku, name, price) VALUES ('PROD-001', 'Widget', 19.99);

-- This will fail - duplicate SKU
-- INSERT INTO products (sku, name, price) VALUES ('PROD-001', 'Gadget', 29.99);

-- PRIMARY KEY Constraint
-- Uniquely identifies each row (NOT NULL + UNIQUE)
CREATE TABLE customers (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  -- Auto-incrementing ID
    customer_number VARCHAR(20) UNIQUE NOT NULL,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE
);

-- Composite primary key (multiple columns together form the key)
CREATE TABLE order_items (
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (order_id, product_id)  -- Both columns together are unique
);

-- FOREIGN KEY Constraint
-- Establishes relationships between tables
CREATE TABLE orders (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id),  -- Must match a customer ID
    order_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    total_amount NUMERIC(10, 2) NOT NULL
);

-- Insert test data
INSERT INTO customers (customer_number, name, email)
VALUES ('CUST-001', 'Alice Johnson', 'alice@example.com');

-- This will succeed - customer_id 1 exists
INSERT INTO orders (customer_id, total_amount) VALUES (1, 99.99);

-- This will fail - customer_id 999 doesn't exist
-- INSERT INTO orders (customer_id, total_amount) VALUES (999, 50.00);

-- Foreign Key Actions
CREATE TABLE departments (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE employees (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    department_id INTEGER
        REFERENCES departments(id)
        ON DELETE CASCADE           -- Delete employees when department is deleted
        ON UPDATE CASCADE           -- Update employee's department_id if department's id changes
);

-- Insert test data
INSERT INTO departments (name) VALUES ('Engineering'), ('Marketing');
INSERT INTO employees (name, department_id) VALUES
    ('Alice', 1),
    ('Bob', 1),
    ('Charlie', 2);

-- Delete a department - employees in that department are also deleted
DELETE FROM departments WHERE name = 'Marketing';

-- Verify Charlie was deleted
SELECT * FROM employees;

-- Other Foreign Key Actions
CREATE TABLE projects (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    manager_id INTEGER
        REFERENCES employees(id)
        ON DELETE SET NULL          -- Set manager_id to NULL when employee is deleted
);

INSERT INTO projects (name, manager_id) VALUES ('Project Alpha', 1);

-- Delete Alice - Project Alpha's manager_id becomes NULL
DELETE FROM employees WHERE name = 'Alice';
SELECT * FROM projects;

-- CHECK Constraint
-- Enforces custom business rules
CREATE TABLE inventory (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name TEXT NOT NULL,
    price NUMERIC(10, 2) NOT NULL CHECK (price > 0),                    -- Price must be positive
    discount_percent INTEGER CHECK (discount_percent BETWEEN 0 AND 100), -- Discount: 0-100%
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0), -- Stock can't be negative
    rating NUMERIC(3, 2) CHECK (rating >= 0 AND rating <= 5)            -- Rating: 0.00 to 5.00
);

-- This will succeed
INSERT INTO inventory (product_name, price, discount_percent, stock_quantity, rating)
VALUES ('Laptop', 999.99, 10, 50, 4.5);

-- These will fail
-- INSERT INTO inventory (product_name, price) VALUES ('Tablet', -50);           -- Negative price
-- INSERT INTO inventory (product_name, price, discount_percent) VALUES ('Phone', 799, 150); -- Invalid discount

-- Multi-column CHECK constraint
CREATE TABLE date_ranges (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_name TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    CHECK (end_date >= start_date)  -- End date must be after or equal to start date
);

INSERT INTO date_ranges (event_name, start_date, end_date)
VALUES ('Conference', '2025-03-01', '2025-03-03');

-- This will fail - end date before start date
-- INSERT INTO date_ranges (event_name, start_date, end_date)
-- VALUES ('Workshop', '2025-04-10', '2025-04-05');

-- DEFAULT Values
CREATE TABLE posts (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'draft',                  -- Default status
    view_count INTEGER DEFAULT 0,                        -- Default view count
    is_published BOOLEAN DEFAULT FALSE,                  -- Default not published
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,    -- Auto timestamp
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Insert without specifying defaults
INSERT INTO posts (title, content) VALUES ('My First Post', 'Hello, World!');

-- Defaults are automatically applied
SELECT * FROM posts;

-- Generated Columns
CREATE TABLE rectangles (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    width NUMERIC(10, 2) NOT NULL CHECK (width > 0),
    height NUMERIC(10, 2) NOT NULL CHECK (height > 0),
    area NUMERIC(10, 2) GENERATED ALWAYS AS (width * height) STORED,
    perimeter NUMERIC(10, 2) GENERATED ALWAYS AS (2 * (width + height)) STORED
);

INSERT INTO rectangles (width, height) VALUES (10, 20), (5.5, 3.2);

-- Area and perimeter are automatically calculated
SELECT * FROM rectangles;

-- Exclusion Constraint
-- Prevents overlapping ranges
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE room_bookings (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_number INTEGER NOT NULL,
    booking_range TSTZRANGE NOT NULL,
    EXCLUDE USING GIST (
        room_number WITH =,
        booking_range WITH &&
    )  -- Prevent overlapping bookings for the same room
);

-- Insert a booking
INSERT INTO room_bookings (room_number, booking_range)
VALUES (101, '[2025-03-01 09:00, 2025-03-01 11:00)');

-- This succeeds - different time
INSERT INTO room_bookings (room_number, booking_range)
VALUES (101, '[2025-03-01 11:00, 2025-03-01 13:00)');

-- This fails - overlapping booking for same room
-- INSERT INTO room_bookings (room_number, booking_range)
-- VALUES (101, '[2025-03-01 10:00, 2025-03-01 12:00)');

-- Combining Multiple Constraints
CREATE TABLE user_accounts (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE
        CHECK (length(username) >= 3 AND username ~ '^[a-zA-Z0-9_]+$'),  -- Alphanumeric + underscore, min 3 chars
    email TEXT NOT NULL UNIQUE
        CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z]{2,}$'),  -- Valid email format
    age INTEGER CHECK (age >= 18 AND age <= 120),                        -- Age between 18 and 120
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- This succeeds
INSERT INTO user_accounts (username, email, age)
VALUES ('alice_2025', 'alice@example.com', 25);

-- These fail
-- INSERT INTO user_accounts (username, email, age) VALUES ('ab', 'invalid', 15);  -- Username too short, invalid email, age < 18

-- View all constraints on a table
SELECT
    conname AS constraint_name,
    contype AS constraint_type
FROM pg_constraint
WHERE conrelid = 'user_accounts'::regclass;
