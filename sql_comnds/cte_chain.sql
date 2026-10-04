WITH
reference_date AS (
    -- Stage 0: stable reference date for historical dataset
    SELECT (MAX(order_purchase_timestamp)::DATE + 1) AS as_of_date
    FROM olist_orders
),

order_base AS (
    -- Stage 1: one row per order, mapped to the real customer with order_total and status flags
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp                          AS purchase_ts,
        (o.order_status = 'canceled')                       AS is_canceled,
        (o.order_status NOT IN ('canceled', 'unavailable')) AS is_valid,
        COALESCE(i.order_total, 0)                          AS order_total
    FROM olist_orders o
    JOIN olist_customers c USING (customer_id)
    LEFT JOIN (
        SELECT order_id,
               SUM(COALESCE(price, 0) + COALESCE(freight_value, 0)) AS order_total
        FROM olist_order_items
        GROUP BY order_id
    ) i USING (order_id)
),

order_rolling AS (
    -- Stage 2: rolling 30-day AVG order_total per customer (window over valid orders)
    SELECT
        ob.*,
        AVG(order_total) FILTER (WHERE is_valid) OVER (
            PARTITION BY customer_unique_id
            ORDER BY purchase_ts
            RANGE BETWEEN INTERVAL '30 days' PRECEDING AND CURRENT ROW
        ) AS avg_order_value_30d
    FROM order_base ob
),

customer_rfm AS (
    -- Stage 3: aggregate to customer level: RFM, first order date, cancellation rate, latest rolling AOV
    SELECT
        r.customer_unique_id,
        MIN(r.purchase_ts)::DATE                                    AS first_order_date,
        (rd.as_of_date - (MAX(r.purchase_ts) FILTER (WHERE r.is_valid))::DATE) AS recency_days,
        COUNT(*) FILTER (WHERE r.is_valid)                          AS frequency,
        COALESCE(SUM(r.order_total) FILTER (WHERE r.is_valid), 0)   AS monetary,
        ROUND(COUNT(*) FILTER (WHERE r.is_canceled)::NUMERIC / COUNT(*), 4) AS cancellation_rate,
        (ARRAY_AGG(r.avg_order_value_30d ORDER BY r.purchase_ts DESC)
             FILTER (WHERE r.is_valid))[1]                          AS avg_order_value_30d
    FROM order_rolling r
    CROSS JOIN reference_date rd
    GROUP BY r.customer_unique_id, rd.as_of_date
),

category_revenue AS (
    -- Stage 4: revenue per customer and product category (valid orders only)
    SELECT
        ob.customer_unique_id,
        COALESCE(p.product_category_name, 'unknown') AS category,
        SUM(oi.price)                                AS category_revenue
    FROM olist_order_items oi
    JOIN order_base ob USING (order_id)
    LEFT JOIN olist_products p USING (product_id)
    WHERE ob.is_valid
    GROUP BY ob.customer_unique_id, COALESCE(p.product_category_name, 'unknown')
),

top_category AS (
    -- Stage 5: top-1 category per customer by revenue (ties broken alphabetically)
    SELECT customer_unique_id, category AS preferred_category
    FROM (
        SELECT
            customer_unique_id,
            category,
            ROW_NUMBER() OVER (
                PARTITION BY customer_unique_id
                ORDER BY category_revenue DESC, category
            ) AS rn
        FROM category_revenue
    ) t
    WHERE rn = 1
)

-- Stage 6: final feature table (one row per customer)
SELECT
    f.customer_unique_id,
    f.recency_days,
    f.frequency,
    f.monetary,
    DATE_TRUNC('quarter', f.first_order_date)::DATE AS cohort_quarter,
    f.avg_order_value_30d,
    f.cancellation_rate,
    tc.preferred_category
FROM customer_rfm f
LEFT JOIN top_category tc USING (customer_unique_id)
ORDER BY f.monetary DESC
LIMIT 15;