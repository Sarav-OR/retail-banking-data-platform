-- int_fraud_flags.sql
--
-- AML-style fraud flagging logic, built on 3 rule types:
--   1. Velocity     - too many transactions from the same customer in a short window
--   2. Unusual amount - transaction is a statistical outlier vs. that customer's normal spend
--   3. High-risk geography - customer is in a country flagged for enhanced scrutiny
--
-- NOTE: the "high risk country" list below is illustrative for this project
-- (SG, CH flagged as offshore financial centers often subject to enhanced due
-- diligence in real AML programs) — a production system would use a maintained
-- regulatory list (e.g. FATF grey/black list), not a hardcoded array.

with enriched as (
    select * from {{ ref('int_transactions_enriched') }}
),

transactions_raw_time as (
    -- Pull transaction_time_seconds back in for true velocity windowing
    -- (int_transactions_enriched only carries transaction_date, day granularity)
    select
        s.transaction_sk,
        s.transaction_time_seconds
    from {{ ref('stg_transactions') }} s
),

velocity_calc as (
    select
        e.transaction_sk,
        e.customer_id,
        e.transaction_amount,
        e.transaction_date,
        e.is_fraud,
        e.country,
        t.transaction_time_seconds,
        count(*) over (
            partition by e.customer_id
            order by t.transaction_time_seconds
            range between 3600 preceding and current row  -- 1-hour rolling window
        ) as txns_in_last_hour
    from enriched e
    inner join transactions_raw_time t
        on e.transaction_sk = t.transaction_sk
),

customer_stats as (
    select
        customer_id,
        avg(transaction_amount) as avg_amount,
        stddev(transaction_amount) as stddev_amount
    from enriched
    group by customer_id
),

flagged as (
    select
        v.transaction_sk,
        v.customer_id,
        v.transaction_amount,
        v.transaction_date,
        v.is_fraud,
        v.country,
        v.txns_in_last_hour,

        -- Rule 1: Velocity — more than 5 transactions in a rolling 1-hour window
        case when v.txns_in_last_hour > 5 then true else false end as flag_velocity,

        -- Rule 2: Unusual amount — more than 3 standard deviations from customer's average
        case
            when cs.stddev_amount > 0
             and abs(v.transaction_amount - cs.avg_amount) > 3 * cs.stddev_amount
            then true
            else false
        end as flag_unusual_amount,

        -- Rule 3: High-risk geography (illustrative list — see model header note)
        case when v.country in ('SG', 'CH') then true else false end as flag_high_risk_geo

    from velocity_calc v
    inner join customer_stats cs
        on v.customer_id = cs.customer_id
)

select
    *,
    (flag_velocity or flag_unusual_amount or flag_high_risk_geo) as aml_flagged,
    (
        cast(flag_velocity as int)
        + cast(flag_unusual_amount as int)
        + cast(flag_high_risk_geo as int)
    ) as aml_flag_count
from flagged