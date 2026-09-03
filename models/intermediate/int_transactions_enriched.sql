-- int_transactions_enriched.sql
--
-- IMPORTANT DESIGN NOTE: the Kaggle fraud dataset is anonymized and has no
-- customer_id or real calendar date (only `transaction_time_seconds`, seconds
-- elapsed since dataset capture start). To join transactions to the synthetic
-- SCD2 customer dimension and to market/economic data, we deterministically
-- assign a synthetic customer_id and transaction_date per transaction, based
-- on a hash of the transaction's surrogate key. This is a stated simplification
-- for demo purposes — a real system would have a true customer_id on each
-- transaction from the source system.

with transactions as (
    select * from {{ ref('stg_transactions') }}
),

customers_current as (
    select * from {{ ref('stg_customers') }}
    where is_current = true
),

market as (
    select * from {{ ref('stg_market_data') }}
),

-- Assign each transaction a synthetic customer (1 of 1000, matching
-- NUM_CUSTOMERS in 06_silver_customers_scd2) via a stable hash
transactions_with_synthetic_keys as (
    select
        *,
        -- Deterministic pseudo-customer assignment: 1..1000
        (abs(hash(transaction_sk)) % 1000) + 1 as synthetic_customer_num,
        -- Deterministic pseudo-date: spread transactions across 2023, based on transaction_time_seconds
        date_add(date('2023-01-01'), cast((transaction_time_seconds / 86400) % 365 as int)) as transaction_date
    from transactions
),

-- Map synthetic_customer_num to real customer_ids by row position
customer_lookup as (
    select
        customer_id,
        row_number() over (order by customer_id) as customer_num
    from customers_current
)

select
    t.transaction_sk,
    t.transaction_amount,
    t.is_fraud,
    t.transaction_date,
    cl.customer_id,
    c.account_type,
    c.country,
    c.risk_rating,
    c.account_status,
    m.eur_usd_close,
    m.fed_funds_rate,
    m.unemployment_rate
from transactions_with_synthetic_keys t
inner join customer_lookup cl
    on t.synthetic_customer_num = cl.customer_num
inner join customers_current c
    on cl.customer_id = c.customer_id
left join market m
    on t.transaction_date = m.date