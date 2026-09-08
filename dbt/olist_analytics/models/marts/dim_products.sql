with products as (
    select * from {{ ref('stg_products') }}
),

translation as (
    select * from {{ ref('stg_category_translation') }}
)

select
    p.product_id,
    p.product_category_name,
    coalesce(
        t.product_category_name_english,   -- categories missing from the translation file
        p.product_category_name,           -- fall back to the Portuguese name
        'uncategorized'                     -- products with no category at all (finding #3)
    )                                       as product_category_english,
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    case
        when p.product_length_cm is not null
         and p.product_height_cm is not null
         and p.product_width_cm is not null
        then p.product_length_cm * p.product_height_cm * p.product_width_cm
    end                                     as product_volume_cm3,
    (p.product_weight_g > 0)                as has_weight_data
from products p
left join translation t
       on t.product_category_name = p.product_category_name