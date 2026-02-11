-- PostgreSQL Hello World Exercises
-- Practice basic PostgreSQL operations

-- Exercise 1: Create a Database
-- Create a database called 'bookstore'
CREATE DATABASE bookstore;

-- Connect to the database
\c bookstore

-- Exercise 2: Create a Table
-- Create a 'books' table with columns: id, title, author, price, published_year
CREATE TABLE books (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    price NUMERIC(10, 2) NOT NULL CHECK (price > 0),
    published_year INTEGER CHECK (published_year >= 1000 AND published_year <= 2100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Exercise 3: Insert Data
-- Add 5 books to your table
INSERT INTO books (title, author, price, published_year)
VALUES
    ('The PostgreSQL Handbook', 'Jane Developer', 49.99, 2023),
    ('Database Design Patterns', 'John Smith', 39.50, 2022),
    ('SQL Mastery', 'Alice Chen', 29.99, 2024),
    ('Advanced PostgreSQL', 'Bob Johnson', 59.99, 2023),
    ('Data Modeling 101', 'Carol Martinez', 34.95, 2021);

-- Verify the data was inserted
SELECT * FROM books;

-- Exercise 4: Query Data
-- Find all books published after 2020
SELECT title, author, published_year
FROM books
WHERE published_year > 2020
ORDER BY published_year DESC;

-- Find books with price less than $40
SELECT title, price
FROM books
WHERE price < 40
ORDER BY price;

-- Find all books by author containing 'John'
SELECT title, author
FROM books
WHERE author LIKE '%John%';

-- Exercise 5: Update Data
-- Update the price of one book (increase by 10%)
UPDATE books
SET price = price * 1.10
WHERE title = 'SQL Mastery';

-- Verify the update
SELECT title, price FROM books WHERE title = 'SQL Mastery';

-- Exercise 6: Delete Data
-- Remove a book from the table
DELETE FROM books WHERE published_year = 2021;

-- Verify deletion
SELECT COUNT(*) AS total_books FROM books;

-- Display all remaining books
SELECT * FROM books ORDER BY published_year DESC;

-- Bonus Exercises

-- Bonus 1: Calculate average book price
SELECT AVG(price) AS average_price FROM books;

-- Bonus 2: Find the most expensive book
SELECT title, author, price
FROM books
ORDER BY price DESC
LIMIT 1;

-- Bonus 3: Count books per year
SELECT published_year, COUNT(*) AS book_count
FROM books
GROUP BY published_year
ORDER BY published_year DESC;

-- Bonus 4: Add a new column for ISBN
ALTER TABLE books ADD COLUMN isbn VARCHAR(13);

-- Update ISBN for existing books
UPDATE books
SET isbn = '978' || LPAD(id::TEXT, 10, '0')
WHERE isbn IS NULL;

-- Verify the new column
SELECT title, isbn FROM books;

-- Bonus 5: Create an index on the author column
CREATE INDEX idx_books_author ON books(author);

-- View table structure including the new index
\d books
