with source as (
    select * from {{ source('olist_raw', 'geolocation') }}
)

-- keep only coordinates inside Brazil's bounding box (assessment 7.4)
select
    cast(geolocation_zip_code_prefix as integer) as zip_code_prefix,
    cast(geolocation_lat as double precision)    as latitude,
    cast(geolocation_lng as double precision)    as longitude,
    trim(geolocation_city)                       as city,
    upper(trim(geolocation_state))               as state
from source
where geolocation_lat between -34 and 6
  and geolocation_lng between -75 and -30