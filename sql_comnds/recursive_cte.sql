WITH RECURSIVE referral_depth AS (
    -- ANCHOR: root customers, які не були referred іншими customers
    SELECT
        c.customer_id,
        1 AS depth,
        ARRAY[c.customer_id]::TEXT[] AS path_ids,
        c.customer_id::TEXT AS path_text
    FROM olist_customers AS c
    WHERE NOT EXISTS (
        SELECT 1
        FROM hw5_referrals AS r
        WHERE r.referred_customer_id = c.customer_id
    )

    UNION ALL

    -- RECURSIVE: перейти від referrer до його referred customers
    SELECT
        r.referred_customer_id AS customer_id,
        rd.depth + 1 AS depth,
        rd.path_ids || r.referred_customer_id AS path_ids,
        rd.path_text || ' -> ' || r.referred_customer_id AS path_text
    FROM hw5_referrals AS r
    JOIN referral_depth AS rd
        ON rd.customer_id = r.referrer_customer_id
    WHERE NOT r.referred_customer_id = ANY(rd.path_ids)
      AND rd.depth < 50
)
SELECT
    depth,
    COUNT(*) AS n_customers,
    MAX(path_text) AS sample_path
FROM referral_depth
GROUP BY depth
ORDER BY depth;
