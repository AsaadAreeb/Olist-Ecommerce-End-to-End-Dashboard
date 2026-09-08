with sellers as (
    select * from {{ ref('stg_sellers') }}
)

select
    s.seller_id,
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state,
    g.latitude                     as seller_latitude,
    g.longitude                    as seller_longitude
from sellers s
left join {{ ref('int_geolocation_by_zip') }} g
       on g.zip_code_prefix = s.seller_zip_code_prefix