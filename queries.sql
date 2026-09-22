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
-- 3. Product category ABC analysis
-- ------------------------------------------
WITH category_sales AS (
    SELECT
        category,
        SUM(qty) AS units_sold,
        SUM(amount) AS non_cancelled_gross_revenue
    FROM amazon_sales
    WHERE status <> 'Cancelled'
      AND status NOT LIKE 'Pending%'
      AND amount IS NOT NULL
    GROUP BY category
),
category_shares AS (
    SELECT
        category,
        units_sold,
        non_cancelled_gross_revenue,
        100.0 * non_cancelled_gross_revenue
            / SUM(non_cancelled_gross_revenue) OVER ()
            AS revenue_share_pct,
        100.0 * SUM(non_cancelled_gross_revenue) OVER (
            ORDER BY non_cancelled_gross_revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / SUM(non_cancelled_gross_revenue) OVER ()
            AS cumulative_revenue_share_pct
    FROM category_sales
)
SELECT
    category,
    units_sold,
    ROUND(non_cancelled_gross_revenue::numeric, 2) AS non_cancelled_gross_revenue,
    ROUND(revenue_share_pct::numeric, 2) AS revenue_share_pct,
    ROUND(cumulative_revenue_share_pct::numeric, 2)
        AS cumulative_revenue_share_pct,
    CASE 
        WHEN cumulative_revenue_share_pct <= 80 THEN 'A'
        WHEN cumulative_revenue_share_pct <= 95 THEN 'B'
        ELSE 'C'
    END AS abc_class
FROM category_shares
ORDER BY non_cancelled_gross_revenue DESC;


-- ------------------------------------------
-- 4. Monthly non-cancelled gross value trend
-- ------------------------------------------
WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', order_date)::date AS sales_month,
        COUNT(*) AS total_orders,
        SUM(units) AS total_units,
        COUNT(DISTINCT order_date) AS days_with_data,
        SUM(order_amount) AS non_cancelled_gross_revenue,
        AVG(order_amount) AS avg_order_value
    FROM vw_order_metrics
    WHERE order_stage NOT IN ('Cancelled', 'Pending')
        AND order_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date)::date
)
SELECT
    sales_month,
    total_orders,
    total_units,
    days_with_data,
    ROUND(non_cancelled_gross_revenue::numeric, 2)
        AS non_cancelled_gross_revenue,
    ROUND(
        (non_cancelled_gross_revenue / NULLIF(days_with_data, 0))::numeric,
        2
    ) AS avg_daily_gross_value,
    ROUND(avg_order_value::numeric, 2) AS avg_order_value,
    ROUND(
        100.0 * (
            non_cancelled_gross_revenue
            - LAG(non_cancelled_gross_revenue) OVER (ORDER BY sales_month)
        )
        / NULLIF(
            LAG(non_cancelled_gross_revenue) OVER (ORDER BY sales_month),
            0
        ),
        2
    ) AS gross_value_mom_pct
FROM monthly_sales
ORDER BY sales_month;
