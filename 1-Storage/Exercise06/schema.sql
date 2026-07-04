-- 1. Schema
CREATE SCHEMA IF NOT EXISTS shop;

-- 2. Tablas
CREATE TABLE shop.customers (
    customer_id INTEGER PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(150) NOT NULL,
    join_date   DATE NOT NULL,
    location    VARCHAR(100)
);

CREATE TABLE shop.products (
    product_id INTEGER PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    category   VARCHAR(50),
    price      NUMERIC(10, 2) NOT NULL,
    stock      INTEGER NOT NULL
);

CREATE TABLE shop.orders (
    order_id     INTEGER PRIMARY KEY,
    customer_id  INTEGER NOT NULL REFERENCES shop.customers(customer_id),
    order_date   DATE NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL
);

CREATE TABLE shop.order_details (
    order_id   INTEGER NOT NULL REFERENCES shop.orders(order_id),
    product_id INTEGER NOT NULL REFERENCES shop.products(product_id),
    quantity   INTEGER NOT NULL,
    price      NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (order_id, product_id)
);

-- 3. Datos de ejemplo
INSERT INTO shop.customers (customer_id, name, email, join_date, location) VALUES
    (101, 'John Doe', 'john.doe@example.com', '2022-05-14', 'New York'),
    (102, 'Jane Smith', 'jane.smith@example.com', '2023-01-22', 'Los Angeles'),
    (103, 'Emily Johnson', 'emily.j@example.com', '2021-11-30', 'Chicago'),
    (104, 'Michael Brown', 'michael.b@example.com', '2020-08-17', 'Houston'),
    (105, 'Sarah Wilson', 'sarah.w@example.com', '2023-03-10', 'San Francisco');

INSERT INTO shop.products (product_id, name, category, price, stock) VALUES
    (201, 'T-Shirt', 'Men', 19.99, 150),
    (202, 'T-Shirt', 'Women', 18.99, 120),
    (203, 'Jeans', 'Men', 39.99, 80),
    (204, 'Jeans', 'Women', 42.99, 90),
    (205, 'Sneakers', 'Unisex', 59.99, 60);

INSERT INTO shop.orders (order_id, customer_id, order_date, total_amount) VALUES
    (301, 101, '2024-03-15', 79.98),
    (302, 103, '2024-03-16', 42.99),
    (303, 102, '2024-03-18', 59.99),
    (304, 105, '2024-03-19', 19.99),
    (305, 104, '2024-03-20', 39.99);

INSERT INTO shop.order_details (order_id, product_id, quantity, price) VALUES
    (301, 201, 2, 19.99),
    (302, 204, 1, 42.99),
    (303, 205, 1, 59.99),
    (304, 202, 1, 18.99),
    (305, 203, 1, 39.99);
