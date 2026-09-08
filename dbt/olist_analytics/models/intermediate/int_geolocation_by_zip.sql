-- Assessment finding #8: geolocation has ~1M rows for ~19k zips.
-- Collapse to one row per zip: mean coordinates, modal city/state.
with geo as (
    select * from {{ ref('stg_geolocation') }}
)

select
    zip_code_prefix,
    avg(latitude)                                              as latitude,
    avg(longitude)                                             as longitude,
    mode() within group (order by city)                        as city,
    mode() within group (order by state)                       as state,
    count(*)                                                   as source_rows
from geo
group by zip_code_prefix