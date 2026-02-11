-- PostgreSQL Data Types Examples

-- Create a database for examples
CREATE DATABASE core_concepts_demo;
\c core_concepts_demo

-- Numeric Types
CREATE TABLE numeric_examples (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    small_int SMALLINT,          -- -32,768 to 32,767
    regular_int INTEGER,         -- Standard integer
    big_int BIGINT,              -- Very large numbers
    exact_decimal NUMERIC(10, 2), -- Exact decimal (for money)
    float_approx REAL,           -- Floating point (approximate)
    double_approx DOUBLE PRECISION -- Double precision float
);

INSERT INTO numeric_examples (small_int, regular_int, big_int, exact_decimal, float_approx, double_approx)
VALUES (100, 1000000, 9223372036854775807, 12345.67, 3.14159, 2.718281828459045);

SELECT * FROM numeric_examples;

-- Character Types
CREATE TABLE text_examples (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    unlimited_text TEXT,              -- Best choice for most strings
    limited_varchar VARCHAR(50),      -- Max 50 characters
    fixed_char CHAR(5)                -- Always 5 characters (padded with spaces)
);

INSERT INTO text_examples (unlimited_text, limited_varchar, fixed_char)
VALUES
    ('This is a very long text that can be any length without restriction', 'Limited to 50', 'ABC'),
    ('Another long text', 'Short', 'XY');

SELECT * FROM text_examples;

-- Date and Time Types
CREATE TABLE datetime_examples (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    just_date DATE,                  -- Calendar date only
    just_time TIME,                  -- Time of day only
    timestamp_no_tz TIMESTAMP,       -- Date + time (avoid this!)
    timestamp_with_tz TIMESTAMPTZ,   -- Date + time with timezone (preferred!)
    time_interval INTERVAL           -- Duration
);

INSERT INTO datetime_examples (just_date, just_time, timestamp_no_tz, timestamp_with_tz, time_interval)
VALUES
    ('2025-02-10', '14:30:00', '2025-02-10 14:30:00', '2025-02-10 14:30:00+00', '2 days 3 hours'),
    (CURRENT_DATE, CURRENT_TIME, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, '1 year 6 months');

SELECT * FROM datetime_examples;

-- Demonstrate timezone handling
SELECT
    timestamp_with_tz,
    timestamp_with_tz AT TIME ZONE 'America/New_York' AS new_york_time,
    timestamp_with_tz AT TIME ZONE 'Europe/London' AS london_time,
    timestamp_with_tz AT TIME ZONE 'Asia/Tokyo' AS tokyo_time
FROM datetime_examples;

-- Boolean Type
CREATE TABLE boolean_examples (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task TEXT NOT NULL,
    is_completed BOOLEAN DEFAULT FALSE,
    is_important BOOLEAN DEFAULT FALSE
);

INSERT INTO boolean_examples (task, is_completed, is_important)
VALUES
    ('Write documentation', TRUE, TRUE),
    ('Fix bug', FALSE, TRUE),
    ('Review code', FALSE, FALSE);

SELECT * FROM boolean_examples WHERE is_important = TRUE AND is_completed = FALSE;

-- JSON Types
CREATE TABLE json_examples (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    regular_json JSON,    -- Text-based JSON
    binary_json JSONB     -- Binary JSON (preferred - faster, indexable)
);

INSERT INTO json_examples (regular_json, binary_json)
VALUES
    ('{"name": "Alice", "age": 30, "city": "New York"}',
     '{"name": "Alice", "age": 30, "city": "New York"}'::jsonb),
    ('{"name": "Bob", "age": 25, "hobbies": ["reading", "gaming"]}',
     '{"name": "Bob", "age": 25, "hobbies": ["reading", "gaming"]}'::jsonb);

-- Query JSON data
SELECT
    id,
    binary_json->>'name' AS name,
    binary_json->>'age' AS age,
    binary_json->>'city' AS city
FROM json_examples;

-- Query nested JSON
SELECT
    binary_json->>'name' AS name,
    binary_json->'hobbies' AS hobbies
FROM json_examples
WHERE binary_json ? 'hobbies';

-- Array Types
CREATE TABLE array_examples (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title TEXT NOT NULL,
    tags TEXT[],                    -- Array of text
    ratings INTEGER[]               -- Array of integers
);

INSERT INTO array_examples (title, tags, ratings)
VALUES
    ('PostgreSQL Tutorial', ARRAY['database', 'sql', 'postgresql'], ARRAY[5, 4, 5, 5]),
    ('Python Guide', ARRAY['python', 'programming', 'tutorial'], ARRAY[5, 5, 4]);

-- Query array data
SELECT title, tags FROM array_examples;

-- Find records where array contains a specific value
SELECT title FROM array_examples WHERE 'postgresql' = ANY(tags);

-- Get array length
SELECT title, array_length(tags, 1) AS tag_count FROM array_examples;

-- UUID Type
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE uuid_examples (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    username TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO uuid_examples (username)
VALUES ('alice'), ('bob'), ('charlie');

SELECT * FROM uuid_examples;

-- Special Types
CREATE TABLE special_types (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ip_address INET,              -- IP address
    mac_address MACADDR,          -- MAC address
    network_cidr CIDR             -- Network address
);

INSERT INTO special_types (ip_address, mac_address, network_cidr)
VALUES
    ('192.168.1.1', '08:00:2b:01:02:03', '192.168.1.0/24'),
    ('10.0.0.50', '08:00:2b:01:02:04', '10.0.0.0/8');

SELECT * FROM special_types;

-- Demonstrate IP operations
SELECT
    ip_address,
    ip_address << network_cidr AS is_in_network
FROM special_types;
