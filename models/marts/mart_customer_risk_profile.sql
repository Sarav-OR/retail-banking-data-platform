-- mart_customer_risk_profile.sql
-- Business-ready: one row per customer, combining their stated risk_rating
-- (from KYC/onboarding) with their observed AML flag behavior — useful for
-- comparing "declared risk" vs "behavioral risk".

with customers as (
    select * from {{ ref('stg_customers') }}
    where is_current = true
),

flags as (
    select * from {{ ref('int_fraud_flags') }}
),

customer_flag_summary as (
    select
        customer_id,
        count(*) as total_transactions,
        sum(case when aml_flagged then 1 else 0 end) as total_aml_flags,
        sum(case when is_fraud = 1 then 1 else 0 end) as total_labeled_fraud,
        round(avg(aml_flag_count), 2) as avg_flags_per_transaction
    from flags
    group by customer_id
)

select
    c.customer_id,
    c.account_type,
    c.country,
    c.risk_rating as declared_risk_rating,
    c.account_status,
    coalesce(f.total_transactions, 0) as total_transactions,
    coalesce(f.total_aml_flags, 0) as total_aml_flags,
    coalesce(f.total_labeled_fraud, 0) as total_labeled_fraud,
    case
        when coalesce(f.total_aml_flags, 0) = 0 then 'LOW'
        when f.total_aml_flags <= 2 then 'MEDIUM'
        else 'HIGH'
    end as behavioral_risk_rating
from customers c
left join customer_flag_summary f
    on c.customer_id = f.customer_id