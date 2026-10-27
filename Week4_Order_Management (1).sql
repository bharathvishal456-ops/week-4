-- Week 4: Order Management System (MySQL)
CREATE DATABASE IF NOT EXISTS order_management_db;
USE order_management_db;

DROP TABLE IF EXISTS Order_Details;
DROP TABLE IF EXISTS Orders;
DROP TABLE IF EXISTS Product;
DROP TABLE IF EXISTS Customer;

CREATE TABLE Customer (
    Customer_ID INT PRIMARY KEY AUTO_INCREMENT,
    Customer_Name VARCHAR(100) NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE,
    Phone VARCHAR(15) NOT NULL UNIQUE
);

CREATE TABLE Product (
    Product_ID INT PRIMARY KEY AUTO_INCREMENT,
    Product_Name VARCHAR(100) NOT NULL,
    Price DECIMAL(10,2) NOT NULL CHECK (Price > 0)
);

CREATE TABLE Orders (
    Order_ID INT PRIMARY KEY AUTO_INCREMENT,
    Customer_ID INT NOT NULL,
    Order_Date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Total_Amount DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (Total_Amount >= 0),
    Order_Status VARCHAR(20) NOT NULL DEFAULT 'Pending'
        CHECK (Order_Status IN ('Pending','Shipped','Delivered','Cancelled')),
    FOREIGN KEY (Customer_ID) REFERENCES Customer(Customer_ID)
);

CREATE TABLE Order_Details (
    Order_Detail_ID INT PRIMARY KEY AUTO_INCREMENT,
    Order_ID INT NOT NULL,
    Product_ID INT NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    Price DECIMAL(10,2) NOT NULL CHECK (Price > 0),
    UNIQUE (Order_ID, Product_ID),
    FOREIGN KEY (Order_ID) REFERENCES Orders(Order_ID) ON DELETE CASCADE,
    FOREIGN KEY (Product_ID) REFERENCES Product(Product_ID)
);

-- Sample customers
INSERT INTO Customer (Customer_Name, Email, Phone) VALUES
('Arun Kumar','arun@example.com','9000000001'),
('Priya Devi','priya@example.com','9000000002'),
('Karthik Raj','karthik@example.com','9000000003');

-- Sample products
INSERT INTO Product (Product_Name, Price) VALUES
('Keyboard',750.00),
('Mouse',450.00),
('Monitor',8500.00),
('USB Cable',250.00),
('Headphones',1200.00);

-- Sample orders
INSERT INTO Orders (Customer_ID, Order_Date, Total_Amount, Order_Status) VALUES
(1,'2026-10-01 10:00:00',1200.00,'Delivered'),
(2,'2026-10-03 11:30:00',9000.00,'Shipped'),
(1,'2026-10-05 14:15:00',1500.00,'Pending'),
(3,'2026-10-08 09:45:00',1650.00,'Delivered');

-- Sample order details
INSERT INTO Order_Details (Order_ID, Product_ID, Quantity, Price) VALUES
(1,1,1,750.00),
(1,2,1,450.00),
(2,3,1,8500.00),
(2,4,2,250.00),
(3,1,2,750.00),
(4,2,1,450.00),
(4,5,1,1200.00);

-- Recalculate order totals from details (recommended after inserts/changes)
UPDATE Orders o
SET Total_Amount = (
    SELECT COALESCE(SUM(od.Quantity * od.Price), 0)
    FROM Order_Details od
    WHERE od.Order_ID = o.Order_ID
);

-- Create a new order for a customer
INSERT INTO Orders (Customer_ID, Total_Amount, Order_Status)
VALUES (2, 0, 'Pending');

-- Add multiple products to the new order (replace Order_ID as needed)
INSERT INTO Order_Details (Order_ID, Product_ID, Quantity, Price) VALUES
(LAST_INSERT_ID(), 1, 1, 750.00),
(LAST_INSERT_ID(), 2, 2, 450.00);

-- Recalculate total for the most recently created order
UPDATE Orders
SET Total_Amount = (
    SELECT COALESCE(SUM(Quantity * Price), 0)
    FROM Order_Details
    WHERE Order_ID = Orders.Order_ID
)
WHERE Order_ID = (SELECT MAX(Order_ID) FROM (SELECT Order_ID FROM Orders) AS x);

-- Update order status
UPDATE Orders SET Order_Status = 'Shipped' WHERE Order_ID = 3;

-- Update quantity of an ordered product
UPDATE Order_Details
SET Quantity = 3
WHERE Order_ID = 3 AND Product_ID = 1;

-- Recalculate total after quantity update
UPDATE Orders o
SET Total_Amount = (
    SELECT COALESCE(SUM(od.Quantity * od.Price), 0)
    FROM Order_Details od
    WHERE od.Order_ID = o.Order_ID
)
WHERE o.Order_ID = 3;

-- Delete cancelled orders (Order_Details rows are removed by ON DELETE CASCADE)
DELETE FROM Orders WHERE Order_Status = 'Cancelled';

-- Complete order information with customer and product details
SELECT o.Order_ID, c.Customer_Name, c.Email, o.Order_Date, o.Order_Status,
       p.Product_Name, od.Quantity, od.Price,
       (od.Quantity * od.Price) AS Line_Total, o.Total_Amount
FROM Orders o
JOIN Customer c ON c.Customer_ID = o.Customer_ID
JOIN Order_Details od ON od.Order_ID = o.Order_ID
JOIN Product p ON p.Product_ID = od.Product_ID
ORDER BY o.Order_ID, od.Order_Detail_ID;

-- Customer order history
SELECT c.Customer_ID, c.Customer_Name, o.Order_ID, o.Order_Date,
       o.Order_Status, o.Total_Amount
FROM Customer c
LEFT JOIN Orders o ON o.Customer_ID = c.Customer_ID
ORDER BY c.Customer_ID, o.Order_Date;

-- Product-wise order report
SELECT p.Product_ID, p.Product_Name, od.Order_ID, od.Quantity, od.Price,
       od.Quantity * od.Price AS Line_Total
FROM Product p
JOIN Order_Details od ON od.Product_ID = p.Product_ID
ORDER BY p.Product_Name, od.Order_ID;

-- Number of times each product was ordered (number of order lines)
SELECT p.Product_Name, COUNT(od.Order_Detail_ID) AS Times_Ordered
FROM Product p
LEFT JOIN Order_Details od ON od.Product_ID = p.Product_ID
GROUP BY p.Product_ID, p.Product_Name
ORDER BY Times_Ordered DESC;

-- Total quantity of products sold
SELECT p.Product_Name, COALESCE(SUM(od.Quantity), 0) AS Total_Quantity_Sold
FROM Product p
LEFT JOIN Order_Details od ON od.Product_ID = p.Product_ID
GROUP BY p.Product_ID, p.Product_Name
ORDER BY Total_Quantity_Sold DESC;

-- Customer(s) with maximum number of orders
SELECT c.Customer_ID, c.Customer_Name, COUNT(o.Order_ID) AS Number_Of_Orders
FROM Customer c
LEFT JOIN Orders o ON o.Customer_ID = c.Customer_ID
GROUP BY c.Customer_ID, c.Customer_Name
HAVING COUNT(o.Order_ID) = (
    SELECT MAX(order_count)
    FROM (
        SELECT COUNT(*) AS order_count
        FROM Orders
        GROUP BY Customer_ID
    ) AS counts
);

-- Total spending by each customer (excluding cancelled orders)
SELECT c.Customer_Name,
       COALESCE(SUM(CASE WHEN o.Order_Status <> 'Cancelled' THEN o.Total_Amount ELSE 0 END),0)
       AS Total_Spending
FROM Customer c
LEFT JOIN Orders o ON o.Customer_ID = c.Customer_ID
GROUP BY c.Customer_ID, c.Customer_Name;

-- Average order value (excluding cancelled orders)
SELECT AVG(Total_Amount) AS Average_Order_Value
FROM Orders
WHERE Order_Status <> 'Cancelled';

-- Total sales amount (excluding cancelled orders)
SELECT COALESCE(SUM(Total_Amount),0) AS Total_Sales_Amount
FROM Orders
WHERE Order_Status <> 'Cancelled';
