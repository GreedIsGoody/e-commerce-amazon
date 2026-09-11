-- ==========================================
-- E-Commerce Amazon Sales Analysis
-- Database: PostgreSQL (salary_db / amazon_sales)
-- ==========================================

-- ------------------------------------------
-- 1. Order Status & Lost Revenue Overview
-- Evaluates order fulfillment rates, cancellations, and total gross revenue
-- ------------------------------------------
SELECT 
    status,
    COUNT(order_id) AS total_orders,
    SUM(qty) AS total_items,
    ROUND(SUM(amount)::numeric, 2) AS total_revenue,
    ROUND(AVG(amount)::numeric, 2) AS avg_order_value
FROM amazon_sales
GROUP BY status
ORDER BY total_revenue DESC NULLS LAST;


-- ------------------------------------------
-- 2. Fulfillment Channel Comparison (FBA vs FBM)
-- Compares Amazon Logistics (FBA) vs Merchant Delivery (FBM) order volume and share
-- ------------------------------------------
SELECT 
    fulfilment,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(amount)::numeric, 2) AS total_revenue,
    ROUND(
        (COUNT(order_id) * 100.0 / SUM(COUNT(order_id)) OVER ()), 2
    ) AS order_share_pct
FROM amazon_sales
WHERE status NOT IN ('Cancelled', 'Pending')
GROUP BY fulfilment;


-- ------------------------------------------
-- 3. Product Category Performance (ABC Revenue Analysis)
-- Calculates net revenue per category and its cumulative contribution percentage
-- ------------------------------------------
WITH category_sales AS (
    SELECT 
        category,
        SUM(qty) AS units_sold,
        ROUND(SUM(amount)::numeric, 2) AS revenue
    FROM amazon_sales
    WHERE status NOT IN ('Cancelled', 'Pending') AND amount IS NOT NULL
    GROUP BY category
)
SELECT 
    category,
    units_sold,
    revenue,
    ROUND(
        (revenue * 100.0 / SUM(revenue) OVER ()), 2
    ) AS revenue_share_pct
FROM category_sales
ORDER BY revenue DESC;


-- ------------------------------------------
-- 4. Monthly Sales & Average Order Value Trends
-- Tracks net monthly revenue, completed order volume, and AOV over time
-- ------------------------------------------
SELECT 
    DATE_TRUNC('month', date)::date AS sales_month,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(qty) AS total_units,
    ROUND(SUM(amount)::numeric, 2) AS monthly_revenue,
    ROUND((SUM(amount) / COUNT(DISTINCT order_id))::numeric, 2) AS avg_order_value
FROM amazon_sales
WHERE status NOT IN ('Cancelled', 'Pending') AND date IS NOT NULL
GROUP BY sales_month
ORDER BY sales_month;