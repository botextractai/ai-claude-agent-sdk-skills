-- Pattern: E-commerce Order Management
-- Complete schema for an online store

\c patterns_demo

-- Customers
CREATE TABLE customers (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    phone VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Customer addresses
CREATE TABLE addresses (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    address_type VARCHAR(20) NOT NULL CHECK (address_type IN ('billing', 'shipping')),
    street_line1 TEXT NOT NULL,
    street_line2 TEXT,
    city TEXT NOT NULL,
    state VARCHAR(50) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(50) NOT NULL DEFAULT 'USA',
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Product categories
CREATE TABLE categories (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    parent_id INTEGER REFERENCES categories(id) ON DELETE CASCADE
);

-- Products
CREATE TABLE products (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku VARCHAR(50) NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    cost NUMERIC(10, 2) CHECK (cost >= 0),
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    weight_kg NUMERIC(8, 3),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Product images
CREATE TABLE product_images (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    display_order INTEGER DEFAULT 0,
    is_primary BOOLEAN DEFAULT FALSE
);

-- Orders
CREATE TABLE orders (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_number VARCHAR(50) NOT NULL UNIQUE,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')),
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    shipping_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    shipping_address_id INTEGER REFERENCES addresses(id),
    billing_address_id INTEGER REFERENCES addresses(id),
    payment_method VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMPTZ,
    shipped_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ
);

-- Order items
CREATE TABLE order_items (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL,
    discount_amount NUMERIC(10, 2) DEFAULT 0,
    subtotal NUMERIC(10, 2) GENERATED ALWAYS AS (quantity * unit_price - COALESCE(discount_amount, 0)) STORED,
    UNIQUE (order_id, product_id)
);

-- Shopping cart
CREATE TABLE cart_items (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    added_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (customer_id, product_id)
);

-- Discount codes
CREATE TABLE discount_codes (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value NUMERIC(10, 2) NOT NULL,
    min_order_amount NUMERIC(10, 2),
    max_discount_amount NUMERIC(10, 2),
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    usage_limit INTEGER,
    usage_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE
);

-- Insert sample data

-- Customers
INSERT INTO customers (email, first_name, last_name, phone)
VALUES
    ('alice@example.com', 'Alice', 'Johnson', '555-0101'),
    ('bob@example.com', 'Bob', 'Smith', '555-0102'),
    ('charlie@example.com', 'Charlie', 'Brown', '555-0103');

-- Addresses
INSERT INTO addresses (customer_id, address_type, street_line1, city, state, postal_code, is_default)
VALUES
    (1, 'shipping', '123 Main St', 'New York', 'NY', '10001', TRUE),
    (1, 'billing', '123 Main St', 'New York', 'NY', '10001', TRUE),
    (2, 'shipping', '456 Oak Ave', 'Los Angeles', 'CA', '90001', TRUE);

-- Categories
INSERT INTO categories (name, description)
VALUES
    ('Electronics', 'Electronic devices and accessories'),
    ('Books', 'Physical and digital books'),
    ('Clothing', 'Apparel and accessories');

INSERT INTO categories (name, parent_id)
VALUES
    ('Laptops', 1),
    ('Smartphones', 1),
    ('Fiction', 2),
    ('Non-Fiction', 2);

-- Products
INSERT INTO products (sku, name, description, category_id, price, cost, stock_quantity)
VALUES
    ('LAP-001', 'Pro Laptop 15"', 'High-performance laptop', 4, 1299.99, 800.00, 25),
    ('PHN-001', 'SmartPhone X', 'Latest smartphone model', 5, 899.99, 500.00, 50),
    ('BOK-001', 'PostgreSQL Mastery', 'Complete PostgreSQL guide', 7, 49.99, 15.00, 100),
    ('BOK-002', 'Database Design', 'Learn database design patterns', 7, 39.99, 12.00, 75),
    ('CLO-001', 'Developer T-Shirt', 'Comfortable coding shirt', 3, 24.99, 8.00, 200);

-- Product images
INSERT INTO product_images (product_id, image_url, display_order, is_primary)
VALUES
    (1, 'https://example.com/images/laptop-1.jpg', 1, TRUE),
    (1, 'https://example.com/images/laptop-2.jpg', 2, FALSE),
    (2, 'https://example.com/images/phone-1.jpg', 1, TRUE);

-- Discount codes
INSERT INTO discount_codes (code, description, discount_type, discount_value, min_order_amount, start_date, end_date, usage_limit)
VALUES
    ('WELCOME10', '10% off first order', 'percentage', 10.00, 50.00, NOW(), NOW() + INTERVAL '30 days', 1000),
    ('SAVE20', '$20 off orders over $100', 'fixed', 20.00, 100.00, NOW(), NOW() + INTERVAL '60 days', 500);

-- Function to create a new order from cart
CREATE OR REPLACE FUNCTION checkout_cart(p_customer_id INTEGER, p_shipping_address_id INTEGER, p_billing_address_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_order_id INTEGER;
    v_order_number VARCHAR(50);
    v_subtotal NUMERIC(10, 2);
BEGIN
    -- Generate order number
    v_order_number := 'ORD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(nextval('orders_id_seq')::TEXT, 6, '0');

    -- Create order
    INSERT INTO orders (order_number, customer_id, shipping_address_id, billing_address_id, status)
    VALUES (v_order_number, p_customer_id, p_shipping_address_id, p_billing_address_id, 'pending')
    RETURNING id INTO v_order_id;

    -- Transfer cart items to order items
    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    SELECT
        v_order_id,
        ci.product_id,
        ci.quantity,
        p.price
    FROM cart_items ci
    JOIN products p ON ci.product_id = p.id
    WHERE ci.customer_id = p_customer_id;

    -- Calculate order total
    SELECT SUM(subtotal) INTO v_subtotal
    FROM order_items
    WHERE order_id = v_order_id;

    -- Update order totals (simplified - no tax calculation)
    UPDATE orders
    SET
        subtotal = v_subtotal,
        shipping_amount = 10.00, -- Flat rate shipping
        tax_amount = v_subtotal * 0.08, -- 8% tax
        total_amount = v_subtotal + 10.00 + (v_subtotal * 0.08)
    WHERE id = v_order_id;

    -- Clear cart
    DELETE FROM cart_items WHERE customer_id = p_customer_id;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update product stock when order is paid
CREATE OR REPLACE FUNCTION update_stock_on_payment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'paid' AND OLD.status != 'paid' THEN
        -- Reduce stock for each order item
        UPDATE products p
        SET stock_quantity = stock_quantity - oi.quantity
        FROM order_items oi
        WHERE oi.order_id = NEW.id
        AND p.id = oi.product_id;

        -- Set paid_at timestamp
        NEW.paid_at = CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_payment_trigger
BEFORE UPDATE OF status ON orders
FOR EACH ROW
EXECUTE FUNCTION update_stock_on_payment();

-- Test the workflow

-- Add items to cart
INSERT INTO cart_items (customer_id, product_id, quantity)
VALUES
    (1, 1, 1),  -- Laptop
    (1, 3, 2);  -- Books

-- View cart
SELECT
    c.first_name || ' ' || c.last_name AS customer,
    p.name AS product,
    ci.quantity,
    p.price,
    (ci.quantity * p.price) AS line_total
FROM cart_items ci
JOIN customers c ON ci.customer_id = c.id
JOIN products p ON ci.product_id = p.id
WHERE c.id = 1;

-- Checkout (create order)
SELECT checkout_cart(1, 1, 1);

-- View the order
SELECT
    o.order_number,
    c.first_name || ' ' || c.last_name AS customer,
    o.status,
    o.subtotal,
    o.tax_amount,
    o.shipping_amount,
    o.total_amount
FROM orders o
JOIN customers c ON o.customer_id = c.id;

-- View order items
SELECT
    o.order_number,
    p.name AS product,
    oi.quantity,
    oi.unit_price,
    oi.subtotal
FROM order_items oi
JOIN orders o ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id;

-- Process payment (mark as paid)
UPDATE orders
SET status = 'paid'
WHERE order_number LIKE 'ORD-%'
AND status = 'pending';

-- Verify stock was reduced
SELECT name, stock_quantity FROM products WHERE id IN (1, 3);

-- Sales analytics

-- Total revenue
SELECT
    SUM(total_amount) AS total_revenue,
    COUNT(*) AS total_orders,
    AVG(total_amount) AS average_order_value
FROM orders
WHERE status = 'paid';

-- Revenue by category
SELECT
    cat.name AS category,
    SUM(oi.subtotal) AS revenue,
    SUM(oi.quantity) AS units_sold
FROM order_items oi
JOIN products p ON oi.product_id = p.id
JOIN categories cat ON p.category_id = cat.id
JOIN orders o ON oi.order_id = o.id
WHERE o.status = 'paid'
GROUP BY cat.id, cat.name
ORDER BY revenue DESC;

-- Top customers
SELECT
    c.first_name || ' ' || c.last_name AS customer,
    COUNT(o.id) AS order_count,
    SUM(o.total_amount) AS total_spent
FROM customers c
JOIN orders o ON c.id = o.customer_id
WHERE o.status IN ('paid', 'shipped', 'delivered')
GROUP BY c.id, c.first_name, c.last_name
ORDER BY total_spent DESC;

-- Low stock alerts
SELECT
    name,
    sku,
    stock_quantity
FROM products
WHERE stock_quantity < 30
AND is_active = TRUE
ORDER BY stock_quantity;
