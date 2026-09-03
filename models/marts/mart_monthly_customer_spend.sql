-- mart_monthly_customer_spend.sql
-- Business-ready: total and average spend per customer per month.

with enriched as (
    select * from {{ ref('int_transactions_enriched') }}
)

select
    customer_id,
    country,
    risk_rating,
    date_trunc('month', transaction_date) as spend_month,
    count(*) as transaction_count,
    round(sum(transaction_amount), 2) as total_spend,
    round(avg(transaction_amount), 2) as avg_transaction_amount,
    sum(case when is_fraud = 1 then 1 else 0 end) as fraud_transaction_count
from enriched
group by customer_id, country, risk_rating, date_trunc('month', transaction_date)