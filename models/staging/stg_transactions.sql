-- stg_transactions.sql
-- Thin pass-through: rename/select only, no business logic here.
-- Business logic (enrichment, fraud rules) lives in intermediate models.

with source as (
    select * from {{ source('silver', 'transactions_cleaned') }}
)

select
    transaction_sk,
    transaction_time_seconds,
    transaction_amount,
    is_fraud,
    silver_ingestion_date,
    dq_passed
from source
where dq_passed = true  -- only pass DQ-clean rows downstream