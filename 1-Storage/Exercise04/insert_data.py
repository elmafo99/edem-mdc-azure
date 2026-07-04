"""
Exercise 04 - Insert data into the Azure SQL Database provisioned with Terraform.

Reads the CSV files from Exercise02/data and loads them into four tables
(customers, products, orders, order_details) in the Azure SQL Database.

Requirements:
    pip install pyodbc python-dotenv

You also need the "ODBC Driver 18 for SQL Server" installed locally.
"""

import os
import csv
import pyodbc
from dotenv import load_dotenv

load_dotenv()

SERVER = os.getenv("SQL_SERVER_FQDN")
DATABASE = os.getenv("SQL_DATABASE_NAME")
USERNAME = os.getenv("SQL_ADMIN_LOGIN")
PASSWORD = os.getenv("SQL_ADMIN_PASSWORD")

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "Exercise02", "data")

CONNECTION_STRING = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    f"SERVER=tcp:{SERVER},1433;"
    f"DATABASE={DATABASE};"
    f"UID={USERNAME};"
    f"PWD={PASSWORD};"
    "Encrypt=yes;"
    "TrustServerCertificate=no;"
    "Connection Timeout=30;"
)

TABLES_DDL = {
    "customers": """
        IF OBJECT_ID('dbo.customers', 'U') IS NULL
        CREATE TABLE dbo.customers (
            CustomerID INT PRIMARY KEY,
            Name NVARCHAR(100),
            Email NVARCHAR(100),
            JoinDate DATE,
            Location NVARCHAR(100)
        )
    """,
    "products": """
        IF OBJECT_ID('dbo.products', 'U') IS NULL
        CREATE TABLE dbo.products (
            ProductID INT PRIMARY KEY,
            Name NVARCHAR(100),
            Category NVARCHAR(100),
            Price DECIMAL(10, 2),
            Stock INT
        )
    """,
    "orders": """
        IF OBJECT_ID('dbo.orders', 'U') IS NULL
        CREATE TABLE dbo.orders (
            OrderID INT PRIMARY KEY,
            CustomerID INT,
            OrderDate DATE,
            TotalAmount DECIMAL(10, 2)
        )
    """,
    "order_details": """
        IF OBJECT_ID('dbo.order_details', 'U') IS NULL
        CREATE TABLE dbo.order_details (
            OrderID INT,
            ProductID INT,
            Quantity INT,
            Price DECIMAL(10, 2)
        )
    """,
}

INSERT_STATEMENTS = {
    "customers": """
        INSERT INTO dbo.customers (CustomerID, Name, Email, JoinDate, Location)
        VALUES (?, ?, ?, ?, ?)
    """,
    "products": """
        INSERT INTO dbo.products (ProductID, Name, Category, Price, Stock)
        VALUES (?, ?, ?, ?, ?)
    """,
    "orders": """
        INSERT INTO dbo.orders (OrderID, CustomerID, OrderDate, TotalAmount)
        VALUES (?, ?, ?, ?)
    """,
    "order_details": """
        INSERT INTO dbo.order_details (OrderID, ProductID, Quantity, Price)
        VALUES (?, ?, ?, ?)
    """,
}


def read_csv(file_name):
    path = os.path.join(DATA_DIR, file_name)
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        next(reader)  # skip header
        return list(reader)


def load_table(cursor, table_name, csv_file):
    cursor.execute(f"SELECT COUNT(*) FROM dbo.{table_name}")
    if cursor.fetchone()[0] > 0:
        print(f"Skipping {table_name}: already has data")
        return

    rows = read_csv(csv_file)
    cursor.executemany(INSERT_STATEMENTS[table_name], rows)
    print(f"Inserted {len(rows)} rows into {table_name}")


def main():
    print(f"Connecting to {SERVER}/{DATABASE}...")
    with pyodbc.connect(CONNECTION_STRING) as conn:
        cursor = conn.cursor()

        for ddl in TABLES_DDL.values():
            cursor.execute(ddl)
        conn.commit()
        print("Tables ready.")

        load_table(cursor, "customers", "customers.csv")
        load_table(cursor, "products", "products.csv")
        load_table(cursor, "orders", "orders.csv")
        load_table(cursor, "order_details", "order_details.csv")
        conn.commit()

    print("Done.")


if __name__ == "__main__":
    main()
