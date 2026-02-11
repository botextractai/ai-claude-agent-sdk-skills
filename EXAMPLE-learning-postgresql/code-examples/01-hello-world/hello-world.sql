-- PostgreSQL Hello World Example
-- This script demonstrates basic PostgreSQL operations

-- Create a database
CREATE DATABASE hello_world;

-- Connect to the database
\c hello_world

-- Create a simple table
CREATE TABLE greetings (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL,
    language VARCHAR(20) DEFAULT 'English',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO greetings (message, language)
VALUES
    ('Hello, World!', 'English'),
    ('¡Hola, Mundo!', 'Spanish'),
    ('Bonjour, Monde!', 'French'),
    ('Hallo, Welt!', 'German'),
    ('こんにちは、世界！', 'Japanese'),
    ('Привет, мир!', 'Russian'),
    ('你好，世界！', 'Chinese'),
    ('مرحبا بالعالم', 'Arabic');

-- Query all greetings
SELECT * FROM greetings;

-- Query specific language
SELECT message FROM greetings WHERE language = 'Spanish';

-- Count total greetings
SELECT COUNT(*) AS total_greetings FROM greetings;

-- Count greetings by language
SELECT language, COUNT(*) AS count
FROM greetings
GROUP BY language
ORDER BY count DESC;

-- Update a greeting
UPDATE greetings
SET message = 'Hello, PostgreSQL World!'
WHERE language = 'English';

-- Verify the update
SELECT * FROM greetings WHERE language = 'English';

-- Delete a greeting
DELETE FROM greetings WHERE language = 'Arabic';

-- Verify deletion
SELECT COUNT(*) FROM greetings;

-- Display final results
SELECT
    language,
    message,
    created_at
FROM greetings
ORDER BY created_at;
