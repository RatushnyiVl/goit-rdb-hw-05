DROP TABLE IF EXISTS olist_order_items CASCADE;
DROP TABLE IF EXISTS olist_orders      CASCADE;
DROP TABLE IF EXISTS olist_customers   CASCADE;
DROP TABLE IF EXISTS olist_products    CASCADE;
DROP TABLE IF EXISTS olist_sellers     CASCADE;

CREATE TABLE olist_customers (
    customer_id              TEXT PRIMARY KEY,
    customer_unique_id       TEXT NOT NULL,
    customer_zip_code_prefix INTEGER,
    customer_city            TEXT,
    customer_state           CHAR(2) NOT NULL
);

CREATE TABLE olist_orders (
    order_id                      TEXT PRIMARY KEY,
    customer_id                   TEXT NOT NULL REFERENCES olist_customers(customer_id),
    order_status                  TEXT NOT NULL,
    order_purchase_timestamp      TIMESTAMP NOT NULL,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    
    CHECK (order_status IN (
        'created', 'approved', 'invoiced', 'processing',
        'shipped', 'delivered', 'unavailable', 'canceled'
    ))
);

CREATE TABLE olist_products (
    product_id                 TEXT PRIMARY KEY,
    product_category_name      TEXT,
    product_name_length        INTEGER CHECK (product_name_length IS NULL OR product_name_length >= 0),
    product_description_length INTEGER CHECK (product_description_length IS NULL OR product_description_length >= 0),
    product_photos_qty         INTEGER CHECK (product_photos_qty IS NULL OR product_photos_qty >= 0),
    product_weight_g           INTEGER CHECK (product_weight_g IS NULL OR product_weight_g >= 0),
    product_length_cm          INTEGER CHECK (product_length_cm IS NULL OR product_length_cm >= 0),
    product_height_cm          INTEGER CHECK (product_height_cm IS NULL OR product_height_cm >= 0),
    product_width_cm           INTEGER CHECK (product_width_cm IS NULL OR product_width_cm >= 0)
);

CREATE TABLE olist_sellers (
    seller_id              TEXT PRIMARY KEY,
    seller_zip_code_prefix INTEGER,
    seller_city            TEXT,
    seller_state           CHAR(2) NOT NULL
);

CREATE TABLE olist_order_items (
    order_id            TEXT NOT NULL REFERENCES olist_orders(order_id),
    order_item_id       INTEGER NOT NULL,
    product_id          TEXT REFERENCES olist_products(product_id),
    seller_id           TEXT REFERENCES olist_sellers(seller_id),
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(12, 2) CHECK (price IS NULL OR price >= 0),
    freight_value       NUMERIC(12, 2) CHECK (freight_value IS NULL OR freight_value >= 0),
    PRIMARY KEY (order_id, order_item_id)
);
