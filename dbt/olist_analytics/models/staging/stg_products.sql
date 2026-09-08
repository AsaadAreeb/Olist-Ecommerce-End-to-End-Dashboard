with source as (
    select * from {{ source('olist_raw', 'products') }}
)

select
    cast(product_id as text)                        as product_id,
    lower(trim(product_category_name))              as product_category_name,
    cast(product_name_lenght as integer)            as product_name_length,        -- fixing source typo
    cast(product_description_lenght as integer)    as product_description_length,-- fixing source typo
    cast(product_photos_qty as integer)             as product_photos_qty,
    cast(product_weight_g as integer)              as product_weight_g,
    cast(product_length_cm as numeric(10,2))        as product_length_cm,
    cast(product_height_cm as numeric(10,2))        as product_height_cm,
    cast(product_width_cm as numeric(10,2))         as product_width_cm
from source