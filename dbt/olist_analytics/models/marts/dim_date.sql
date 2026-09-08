with dates as (
    select generate_series(
        '2016-01-01'::date,
        '2018-12-31'::date,
        interval '1 day'
    )::date as date_day
)

select
    date_day,
    extract(year  from date_day)::int                       as year_number,
    extract(quarter from date_day)::int                    as quarter_number,
    'Q' || extract(quarter from date_day)::text             as quarter_label,
    extract(month from date_day)::int                      as month_number,
    trim(to_char(date_day, 'Month'))                        as month_name,
    trim(to_char(date_day, 'YYYY-Mon'))                    as year_month_label,
    date_trunc('month', date_day)::date                    as month_start_date,
    date_trunc('quarter', date_day)::date                  as quarter_start_date,
    extract(week from date_day)::int                       as week_of_year,
    extract(doy from date_day)::int                        as day_of_year,
    extract(day from date_day)::int                        as day_of_month,
    extract(dow from date_day)::int                        as day_of_week_number,  -- 0 = Sunday
    trim(to_char(date_day, 'Day'))                          as day_name,
    (extract(dow from date_day) in (0, 6))                  as is_weekend
from dates