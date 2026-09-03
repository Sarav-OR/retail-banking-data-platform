-- stg_market_data.sql
-- Pivots the long-format Silver table (one row per date+metric) into a wide
-- format (one row per date, one column per metric) — much easier to join
-- against transactions in the intermediate layer.

with source as (
    select * from {{ source('silver', 'market_economic_daily') }}
    where dq_passed = true
)

select
    date,
    max(case when metric_name = 'eur_usd_close'      then metric_value end) as eur_usd_close,
    max(case when metric_name = 'jpy_usd_close'       then metric_value end) as jpy_usd_close,
    max(case when metric_name = 'ibm_close'            then metric_value end) as ibm_close,
    max(case when metric_name = 'fed_funds_rate'       then metric_value end) as fed_funds_rate,
    max(case when metric_name = 'cpi_inflation'        then metric_value end) as cpi_inflation,
    max(case when metric_name = 'gdp_growth'           then metric_value end) as gdp_growth,
    max(case when metric_name = 'unemployment_rate'    then metric_value end) as unemployment_rate
from source
group by date