-- mart_fraud_summary.sql
-- Business-ready: daily fraud and AML flag summary, for dashboarding.

with flags as (
    select * from {{ ref('int_fraud_flags') }}
)

select
    transaction_date,
    country,
    count(*) as total_transactions,
    sum(case when is_fraud = 1 then 1 else 0 end) as labeled_fraud_count,
    sum(case when aml_flagged then 1 else 0 end) as aml_flagged_count,
    sum(case when flag_velocity then 1 else 0 end) as velocity_flag_count,
    sum(case when flag_unusual_amount then 1 else 0 end) as unusual_amount_flag_count,
    sum(case when flag_high_risk_geo then 1 else 0 end) as high_risk_geo_flag_count,
    round(100.0 * sum(case when aml_flagged then 1 else 0 end) / count(*), 2) as aml_flag_rate_pct
from flags
group by transaction_date, country