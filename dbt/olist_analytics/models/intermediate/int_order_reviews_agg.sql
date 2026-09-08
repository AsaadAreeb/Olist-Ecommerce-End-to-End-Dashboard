with reviews as (
    select * from {{ ref('stg_order_reviews') }}
)

select
    order_id,
    round(avg(review_score), 2)                 as review_score,
    count(*)                                    as review_count,
    bool_or(has_comment)                        as has_comment,
    min(review_created_at)                      as first_review_at
from reviews
where order_id is not null
group by order_id