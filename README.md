# HW5: Feature engineering на PostgreSQL (Olist)

Домашня робота з PostgreSQL на датасеті **Brazilian E-Commerce Public Dataset by Olist**: CTE-chain pipeline для побудови клієнтських фіч, recursive CTE для referral-дерева, Materialized View та порівняння планів виконання через `EXPLAIN (ANALYZE, BUFFERS)`.

## Джерело даних

- Датасет: [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle).
- Використовуються 5 таблиць із 9 доступних:

| CSV-файл | Таблиця в БД | Опис |
|---|---|---|
| `olist_customers_dataset.csv` | `olist_customers` | клієнти (`customer_id` унікальний на замовлення, реальний клієнт ідентифікується через `customer_unique_id`) |
| `olist_orders_dataset.csv` | `olist_orders` | замовлення, статуси, часові мітки |
| `olist_order_items_dataset.csv` | `olist_order_items` | позиції замовлень (`price`, `freight_value`) |
| `olist_products_dataset.csv` | `olist_products` | товари та категорії |
| `olist_sellers_dataset.csv` | `olist_sellers` | продавці |

## Як отримуються файли

Сирі CSV-файли зберігаються в папці `data/`. Вона створюється автоматично під час запуску `hw_5.ipynb`, туди ж потрапляють файли датасету.

csv таблиці завантажуються через комануду kagglehub.dataset_download (див ноутбук).


## Структура проєкту

```
hw5/
├── hw_5.ipynb            # головний notebook: підготовка БД, запуск усіх запитів
├── sql_comnds/           # довгі SQL-команди
│   ├── com1.sql          # DDL: створення 5 таблиць
│   ├── com2.sql          # допоміжні команди підготовки БД
│   ├── cte_chain.sql     # CTE-pipeline (Stages 0-6)
│   ├── cte_in_table.sql  # синтетична таблиця hw5_referrals
│   ├── recursive_cte.sql # recursive CTE: depth, path, захист від циклів
│   ├── mv_pipeline.sql   # Materialized View + UNIQUE INDEX + REFRESH CONCURRENTLY
│   └── explain_cte.sql   # EXPLAIN (ANALYZE, BUFFERS) для pipeline
├── explain_cte.csv       # план: повне переобчислення pipeline
├── explain_mv.csv        # план: top-15 з Materialized View
├── explain_lookup.csv    # план: lookup одного клієнта з Materialized View
├── data/                 # сирі CSV (створюється при запуску)
└── temp/                 # локальна БД PostgreSQL (створюється при запуску)
```

## CTE-pipeline (Stages)

Результат: один рядок на клієнта (`customer_unique_id`) з фічами `recency_days`, `frequency`, `monetary`, `cohort_quarter`, `avg_order_value_30d`, `cancellation_rate`, `preferred_category`.

| Stage | CTE | Що робить |
|---|---|---|
| 0 | `reference_date` | стабільна дата відліку: `MAX(order_purchase_timestamp) + 1 день` (датасет історичний) |
| 1 | `order_base` | один рядок на замовлення: мапінг на `customer_unique_id`, `order_total = price + freight_value`, прапорці `is_canceled` та `is_valid` |
| 2 | `order_rolling` | віконне ковзне середнє `order_total` за 30 календарних днів (`RANGE ... INTERVAL '30 days' PRECEDING`) по клієнту |
| 3 | `customer_rfm` | агрегація до рівня клієнта: RFM, дата першого замовлення, `cancellation_rate`, `avg_order_value_30d` на момент останнього валідного замовлення |
| 4 | `category_revenue` | виручка по парі «клієнт - категорія» (лише валідні замовлення) |
| 5 | `top_category` | `ROW_NUMBER()` по виручці: топ-1 категорія як `preferred_category` (при рівності - за алфавітом) |
| 6 | фінальний `SELECT` | збирає фічі, додає `cohort_quarter = DATE_TRUNC('quarter', first_order_date)::DATE` |

**Припущення:**
- валідне замовлення - будь-який статус, окрім `canceled` та `unavailable`;
- `cancellation_rate` - частка скасованих від усіх замовлень клієнта;
- для клієнтів без валідних замовлень `frequency = 0`, `monetary = 0`, а `recency_days`, `avg_order_value_30d`, `preferred_category` дорівнюють `NULL`;
- товари без категорії потрапляють у `'unknown'`.

## Materialized View

`mv_customer_features` містить той самий повний pipeline (усі stages). Колонка `customer_unique_id` у ній названа `customer_id` (це **не** `olist_customers.customer_id`). На колонці створено `UNIQUE INDEX ux_mv_customer_features_customer_id`, після чого виконується `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

## Recursive CTE

Таблиця `hw5_referrals` - синтетична (Olist не має referral-даних): лінійний ланцюжок із 10 клієнтів. Recursive CTE `referral_depth` має anchor (клієнти без referrer), recursive part, `depth` та `path`. Захист від циклів (наприклад, `A → B → A`) реалізований двома способами:
- масив `path_ids` з умовою `NOT r.referred_customer_id = ANY(rd.path_ids)`;
- depth guard `rd.depth < 50`.

## Запуск

**Вимоги:** Python 3.10+, PostgreSQL 14+ (`RANGE` з `INTERVAL` потребує 11+, `CYCLE`-clause - 14+; у проєкті БД піднімається через `pixeltable-pgserver`, окремо встановлювати PostgreSQL не потрібно).

```bash
pip install pixeltable-pgserver sqlalchemy pandas psycopg2-binary jupyter, kagglehub
jupyter notebook hw_5.ipynb
```

Далі виконайте комірки notebook зверху вниз ("Run All"). Notebook:
1. створює папки `data/` та `temp/`, отримує CSV-файли в `data/`;
2. піднімає локальний PostgreSQL у `temp/` і створює таблиці (`sql_comnds/com1.sql`);
3. завантажує CSV в таблиці;
4. послідовно виконує: CTE-pipeline, `hw5_referrals` + recursive CTE, Materialized View, `EXPLAIN`-запити.

Для повторного чистого запуску видаліть папку `temp/` (локальну БД) і запустіть notebook знову.
