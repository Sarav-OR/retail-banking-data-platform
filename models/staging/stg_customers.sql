-- stg_customers.sql
-- Thin pass-through of the SCD2 customer dimension.

with source as (
    select * from {{ source('silver', 'customers_scd2') }}
)

select
    customer_id,
    account_type,
    country,
    risk_rating,
    account_status,
    effective_from,
    effective_to,
    is_current,
    scd_version
from source