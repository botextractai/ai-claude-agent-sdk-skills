-- PostgreSQL Transactions Examples
-- Transactions ensure ACID compliance: Atomicity, Consistency, Isolation, Durability

\c core_concepts_demo

-- Setup: Create accounts table for examples
CREATE TABLE accounts (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_number VARCHAR(20) NOT NULL UNIQUE,
    holder_name TEXT NOT NULL,
    balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO accounts (account_number, holder_name, balance)
VALUES
    ('ACC-001', 'Alice Johnson', 1000.00),
    ('ACC-002', 'Bob Smith', 500.00),
    ('ACC-003', 'Charlie Brown', 750.00);

-- Basic Transaction
-- BEGIN starts a transaction, COMMIT saves it, ROLLBACK undoes it

BEGIN;

UPDATE accounts
SET balance = balance - 100
WHERE account_number = 'ACC-001';

UPDATE accounts
SET balance = balance + 100
WHERE account_number = 'ACC-002';

COMMIT; -- Both updates are saved together

-- Verify the transfer
SELECT account_number, holder_name, balance FROM accounts;

-- Transaction with ROLLBACK
-- If something goes wrong, undo all changes

BEGIN;

UPDATE accounts
SET balance = balance - 200
WHERE account_number = 'ACC-001';

-- Oh no, we made a mistake!
ROLLBACK; -- Undo the update

-- Balance is unchanged
SELECT account_number, balance FROM accounts WHERE account_number = 'ACC-001';

-- Transaction with Error Handling
-- PostgreSQL automatically rolls back on errors

BEGIN;

UPDATE accounts
SET balance = balance - 500
WHERE account_number = 'ACC-001';

-- This will fail because Charlie's account doesn't have enough balance
-- (and we'd create a negative balance, violating the CHECK constraint)
UPDATE accounts
SET balance = balance - 1000
WHERE account_number = 'ACC-003';

-- The transaction is automatically aborted
-- Try to commit (this will fail because the transaction is already aborted)
-- COMMIT;

-- Check balances - Alice's deduction was rolled back automatically
SELECT account_number, balance FROM accounts;

-- Savepoints: Partial Rollbacks
-- Create checkpoints within a transaction

BEGIN;

UPDATE accounts
SET balance = balance - 50
WHERE account_number = 'ACC-001';

SAVEPOINT after_first_update;

UPDATE accounts
SET balance = balance + 50
WHERE account_number = 'ACC-002';

SAVEPOINT after_second_update;

-- This update might fail
UPDATE accounts
SET balance = balance + 50
WHERE account_number = 'ACC-003';

-- If we want to undo just the last update
ROLLBACK TO SAVEPOINT after_second_update;

-- First two updates are preserved
COMMIT;

-- Verify the results
SELECT account_number, balance FROM accounts;

-- Transaction Isolation Levels
-- Control how transactions see each other's changes

-- READ UNCOMMITTED (PostgreSQL treats this as READ COMMITTED)
-- READ COMMITTED (default) - see committed changes from other transactions
-- REPEATABLE READ - see snapshot from transaction start
-- SERIALIZABLE - strongest isolation, prevents all anomalies

-- Example: READ COMMITTED (default)
-- Open two psql sessions to see this in action

-- Session 1:
BEGIN;
UPDATE accounts SET balance = balance + 100 WHERE account_number = 'ACC-001';
-- Don't commit yet

-- Session 2 (in another terminal):
-- This will see the old balance until Session 1 commits
-- SELECT balance FROM accounts WHERE account_number = 'ACC-001';

-- Session 1:
COMMIT;

-- Session 2:
-- Now sees the updated balance
-- SELECT balance FROM accounts WHERE account_number = 'ACC-001';

-- Example: REPEATABLE READ
-- Sees a consistent snapshot throughout the transaction

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT balance FROM accounts WHERE account_number = 'ACC-001';

-- Even if another transaction commits changes, this transaction
-- continues to see the same snapshot

SELECT balance FROM accounts WHERE account_number = 'ACC-001';
-- Will return the same value as before

COMMIT;

-- Realistic Example: E-commerce Order Processing

CREATE TABLE products_inventory (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name TEXT NOT NULL,
    stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0),
    price NUMERIC(10, 2) NOT NULL
);

CREATE TABLE orders (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_name TEXT NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id),
    product_id INTEGER NOT NULL REFERENCES products_inventory(id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL
);

-- Insert sample products
INSERT INTO products_inventory (product_name, stock_quantity, price)
VALUES
    ('Laptop', 10, 999.99),
    ('Mouse', 50, 19.99),
    ('Keyboard', 30, 49.99);

-- Process an order (all-or-nothing transaction)
BEGIN;

-- Create order
INSERT INTO orders (customer_name, total_amount)
VALUES ('Alice Johnson', 0) -- Will update total later
RETURNING id;

-- Assume returned id is 1
-- Add order items and update inventory
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (1, 1, 1, 999.99);

UPDATE products_inventory
SET stock_quantity = stock_quantity - 1
WHERE id = 1 AND stock_quantity >= 1;

-- Check that update affected a row (stock was available)
-- If this returns 0, we should rollback
-- In application code, you'd check: IF FOUND THEN ... ELSE ROLLBACK

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (1, 2, 2, 19.99);

UPDATE products_inventory
SET stock_quantity = stock_quantity - 2
WHERE id = 2 AND stock_quantity >= 2;

-- Update order total
UPDATE orders
SET total_amount = (
    SELECT SUM(quantity * unit_price)
    FROM order_items
    WHERE order_id = 1
)
WHERE id = 1;

-- Mark order as confirmed
UPDATE orders SET status = 'confirmed' WHERE id = 1;

COMMIT;

-- Verify the order and inventory
SELECT * FROM orders;
SELECT * FROM order_items;
SELECT product_name, stock_quantity FROM products_inventory;

-- Bank Transfer Example (Classic ACID demonstration)

-- Reset balances
UPDATE accounts SET balance = 1000 WHERE account_number = 'ACC-001';
UPDATE accounts SET balance = 500 WHERE account_number = 'ACC-002';

-- Safe bank transfer function
DO $$
DECLARE
    v_from_account VARCHAR(20) := 'ACC-001';
    v_to_account VARCHAR(20) := 'ACC-002';
    v_amount NUMERIC(12, 2) := 250.00;
    v_from_balance NUMERIC(12, 2);
BEGIN
    -- Start transaction (implicit in function)

    -- Lock the accounts to prevent concurrent modifications
    SELECT balance INTO v_from_balance
    FROM accounts
    WHERE account_number = v_from_account
    FOR UPDATE;

    -- Check sufficient funds
    IF v_from_balance < v_amount THEN
        RAISE EXCEPTION 'Insufficient funds';
    END IF;

    -- Deduct from source
    UPDATE accounts
    SET balance = balance - v_amount
    WHERE account_number = v_from_account;

    -- Add to destination
    UPDATE accounts
    SET balance = balance + v_amount
    WHERE account_number = v_to_account;

    RAISE NOTICE 'Transfer successful: % from % to %', v_amount, v_from_account, v_to_account;

    -- Implicit COMMIT at end of function
END $$;

-- Verify transfer
SELECT account_number, balance FROM accounts WHERE account_number IN ('ACC-001', 'ACC-002');

-- Transaction with Row Locking
-- Prevents concurrent modifications

BEGIN;

-- Lock specific rows for update
SELECT * FROM accounts
WHERE account_number = 'ACC-001'
FOR UPDATE;

-- Other transactions trying to update this row will wait

UPDATE accounts
SET balance = balance - 100
WHERE account_number = 'ACC-001';

COMMIT; -- Releases the lock

-- Concurrent Transaction Example
-- Demonstrates isolation

-- Session 1:
BEGIN;
UPDATE accounts SET balance = balance + 100 WHERE account_number = 'ACC-001';
-- Wait before committing

-- Session 2 (in another terminal):
-- This will wait because Session 1 has locked the row
-- BEGIN;
-- UPDATE accounts SET balance = balance - 50 WHERE account_number = 'ACC-001';

-- Session 1:
COMMIT; -- Session 2 can now proceed

-- Transaction Best Practices Summary

-- 1. Keep transactions short
--    Long transactions lock resources and impact concurrency

-- 2. Always handle errors
--    Use ROLLBACK to undo partial changes

-- 3. Use appropriate isolation levels
--    READ COMMITTED for most cases
--    REPEATABLE READ when you need consistent reads
--    SERIALIZABLE for strict consistency (impacts performance)

-- 4. Use savepoints for complex transactions
--    Allows partial rollbacks

-- 5. Lock only what you need
--    FOR UPDATE locks rows
--    FOR SHARE allows concurrent reads but blocks writes

-- 6. Test concurrent scenarios
--    Use multiple sessions to test race conditions

-- Create a transaction log for audit
CREATE TABLE transaction_log (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_type TEXT NOT NULL,
    from_account VARCHAR(20),
    to_account VARCHAR(20),
    amount NUMERIC(12, 2),
    timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Complete example with logging
BEGIN;

-- Perform transfer
UPDATE accounts SET balance = balance - 75 WHERE account_number = 'ACC-001';
UPDATE accounts SET balance = balance + 75 WHERE account_number = 'ACC-002';

-- Log the transaction
INSERT INTO transaction_log (transaction_type, from_account, to_account, amount)
VALUES ('transfer', 'ACC-001', 'ACC-002', 75);

COMMIT;

-- View transaction history
SELECT * FROM transaction_log ORDER BY timestamp DESC;
