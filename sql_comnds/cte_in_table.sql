DROP TABLE IF EXISTS hw5_referrals CASCADE;

CREATE TABLE hw5_referrals (
    referrer_customer_id TEXT NOT NULL REFERENCES olist_customers(customer_id),
    referred_customer_id TEXT NOT NULL REFERENCES olist_customers(customer_id),
    referred_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (referred_customer_id),
    CHECK (referrer_customer_id <> referred_customer_id)
);

WITH ordered_customers AS (
    SELECT
        customer_id,
        ROW_NUMBER() OVER (ORDER BY customer_id) AS rn
    FROM olist_customers
    ORDER BY customer_id
    LIMIT 10
)
INSERT INTO hw5_referrals (referrer_customer_id, referred_customer_id)
SELECT
    prev.customer_id AS referrer_customer_id,
    nxt.customer_id AS referred_customer_id
FROM ordered_customers AS prev
JOIN ordered_customers AS nxt
    ON nxt.rn = prev.rn + 1
ON CONFLICT (referred_customer_id) DO NOTHING;