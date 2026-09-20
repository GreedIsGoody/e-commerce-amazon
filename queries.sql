-- ==========================================
-- E-Commerce Amazon Sales Analysis
-- Database: PostgreSQL / amazon_sales
-- ==========================================

-- ==========================================
-- Order-level analytical mart
-- One record = one order
-- ==========================================

CREATE OR REPLACE VIEW vw_order_metrics AS
SELECT 
    order_id,
    MIN(date)::date AS order_date,
    MIN(status) AS status,
    MIN(fulfilment) AS fulfilment,
    MIN(sales_channel) AS sales_channel,
    MIN(ship_service_level) AS ship_service_level,
    MIN(ship_state) AS ship_state,
    MIN(ship_city) AS ship_city,
    BOOL_OR(b2b) AS is_b2b,
    COUNT(*) AS line_items,
    SUM(qty) AS units,
    SUM(amount) AS order_amount, 
    CASE 
        WHEN MIN(status) = 'Cancelled' THEN 'Cancelled'
        WHEN MIN(status) LIKE 'Shipped - Returned%' THEN 'Returned'
        WHEN MIN(status) LIKE 'Shipped - Returning%' THEN 'Returning'
        WHEN MIN(status) LIKE 'Shipped - Delivered%' THEN 'Delivered'
        WHEN MIN(status) = 'Shipped' THEN 'Shipped'
        WHEN MIN(status) LIKE 'Pending%' THEN 'Pending'
        ELSE 'In progress'
    END AS order_stage
FROM amazon_sales
GROUP BY order_id;

-- Data-quality check: expected total_orders = 120378
SELECT
    COUNT(*) AS total_orders,
    SUM(units) AS total_units,
    ROUND(SUM(order_amount)::numeric, 2) AS gross_order_value,
    ROUND(AVG(order_amount)::numeric, 2) AS avg_order_value
FROM vw_order_metrics;

-- ------------------------------------------
-- 1. Order funnel and cancellation rate
-- ------------------------------------------

WITH funnel AS (
    SELECT
        order_stage,
        COUNT(*) AS total_orders,
        SUM(units) AS total_units,
        SUM(order_amount) AS gross_order_value
    FROM vw_order_metrics
    GROUP BY order_stage
),
totals AS (
    SELECT COUNT(*) AS all_orders
    FROM vw_order_metrics
)
SELECT
    f.order_stage,
    f.total_orders,
    ROUND(f.total_orders * 100.0 / t.all_orders, 2) AS order_share_pct,
    f.total_units,
    ROUND(f.gross_order_value::numeric, 2) AS gross_order_value,
    ROUND((f.gross_order_value / NULLIF(f.total_orders, 0))::numeric, 2)
        AS avg_order_value
FROM funnel AS f
CROSS JOIN totals AS t
ORDER BY f.total_orders DESC;

-- Cancellation KPI
SELECT
    COUNT(*) FILTER (WHERE order_stage = 'Cancelled') AS cancelled_orders,
    COUNT(*) AS total_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE order_stage = 'Cancelled')
        / COUNT(*),
        2
    ) AS cancellation_rate_pct,
    ROUND(
        SUM(order_amount) FILTER (WHERE order_stage = 'Cancelled')::numeric,
        2
    ) AS cancelled_gross_order_value
FROM vw_order_metrics;

-- ------------------------------------------
-- 2. Fulfillment channel performance
-- ------------------------------------------
SELECT
    fulfilment,
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (WHERE order_stage = 'Cancelled') AS cancelled_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE order_stage = 'Cancelled')
        / COUNT(*),
        2
    ) AS cancellation_rate_pct,

    COUNT(*) FILTER (WHERE order_stage = 'Returned') AS returned_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE order_stage = 'Returned')
        / COUNT(*),
        2
    ) AS return_rate_pct,

    ROUND(
        AVG(order_amount) FILTER (
            WHERE order_stage NOT IN ('Cancelled', 'Pending')
        )::numeric,
        2
    ) AS avg_order_value,

    ROUND(
        SUM(order_amount) FILTER (
            WHERE order_stage NOT IN ('Cancelled', 'Pending')
        )::numeric,
        2
    ) AS non_cancelled_gross_value
FROM vw_order_metrics
GROUP BY fulfilment
ORDER BY total_orders DESC;
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
    WHERE status <> 'Cancelled'
      AND status NOT LIKE 'Pending%'
      AND amount IS NOT NULL
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
WHERE status <> 'Cancelled'
  AND status NOT LIKE 'Pending%'
  AND date IS NOT NULL
GROUP BY sales_month
ORDER BY sales_month;


