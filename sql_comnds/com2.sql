INSERT INTO olist_customers
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix::INTEGER,
    customer_city,
    customer_state::CHAR(2)
FROM olist_customers_raw;


INSERT INTO olist_orders
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp::TIMESTAMP,
    order_approved_at::TIMESTAMP,
    order_delivered_carrier_date::TIMESTAMP,
    order_delivered_customer_date::TIMESTAMP,
    order_estimated_delivery_date::TIMESTAMP
FROM olist_orders_raw;


INSERT INTO olist_products
SELECT
    product_id,
    product_category_name,
    product_name_lenght::INTEGER,
    product_description_lenght::INTEGER,
    product_photos_qty::INTEGER,
    product_weight_g::INTEGER,
    product_length_cm::INTEGER,
    product_height_cm::INTEGER,
    product_width_cm::INTEGER
FROM olist_products_raw;


INSERT INTO olist_sellers
SELECT
    seller_id,
    seller_zip_code_prefix::INTEGER,
    seller_city,
    seller_state::CHAR(2)
FROM olist_sellers_raw;


INSERT INTO olist_order_items
SELECT
    order_id,
    order_item_id::INTEGER,
    product_id,
    seller_id,
    shipping_limit_date::TIMESTAMP,
    price::NUMERIC(12, 2),
    freight_value::NUMERIC(12, 2)
FROM olist_order_items_raw;

