
-- Query 1 
SELECT *
FROM amazon_sale_report
LIMIT 10;


-- Query 2 

SELECT
    category,
    COUNT(*) AS total_orders
FROM amazon_sale_report
GROUP BY category
ORDER BY total_orders DESC
LIMIT 10;


-- Query 3 
SELECT
    fulfilment,
    COUNT(*)                  AS total_orders,
    SUM(qty)                  AS total_units_sold,
    ROUND(SUM(amount), 2)     AS total_revenue
FROM amazon_sale_report
WHERE status NOT LIKE '%Cancelled%'
  AND status NOT LIKE '%Pending%'
GROUP BY fulfilment
ORDER BY total_revenue DESC
LIMIT 10;


-- Query 4 
SELECT
    DATE_FORMAT(DATE_PARSE(date, '%m-%d-%y'), '%Y-%m') AS month,
    COUNT(*)              AS total_orders,
    ROUND(SUM(amount), 2) AS total_revenue
FROM amazon_sale_report
WHERE status NOT LIKE '%Cancelled%'
  AND status NOT LIKE '%Pending%'
GROUP BY DATE_FORMAT(DATE_PARSE(date, '%m-%d-%y'), '%Y-%m')
ORDER BY month ASC
LIMIT 10;


-- Query 5 
WITH ranked AS (
    SELECT
        category,
        sku,
        ROUND(SUM(amount), 2) AS total_revenue,
        SUM(qty)              AS total_units_sold,
        RANK() OVER (
            PARTITION BY category
            ORDER BY SUM(amount) DESC
        ) AS rnk
    FROM amazon_sale_report
    WHERE status NOT LIKE '%Cancelled%'
      AND status NOT LIKE '%Pending%'
      AND qty > 0
    GROUP BY category, sku
)
SELECT
    category,
    sku,
    total_revenue,
    total_units_sold,
    rnk
FROM ranked
WHERE rnk <= 5
ORDER BY category, rnk
LIMIT 10;
