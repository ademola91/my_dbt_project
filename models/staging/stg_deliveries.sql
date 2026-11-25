with source_deliveries as (
    select
        delivery_id,
        customer_id,
        rider_id,
        initcap(trim(pickup_city)) as pickup_city,
        distance_km,
        delivery_fee,
        case
            when lower(trim(status)) in ('delivered', 'completed') then 'delivered'
            else lower(trim(status))
        end as normalized_status,
        lower(trim(fleet)) as raw_delivery_fleet,
        created_at,
        row_number() over (
            partition by delivery_id
            order by created_at asc nulls last, distance_km asc nulls last
        ) as duplicate_rank
    from {{ source('jara_raw', 'deliveries') }}
    where delivery_id is not null
)
select
    delivery_id,
    customer_id,
    rider_id,
    pickup_city,
    distance_km,
    delivery_fee,
    normalized_status,
    raw_delivery_fleet,
    created_at,
    duplicate_rank,
    (duplicate_rank > 1) as is_duplicate
from source_deliveries