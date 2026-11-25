with deliveries as (
    select
        date_trunc('week', d.created_at)::date as delivery_week,
        coalesce(r.fleet, d.raw_delivery_fleet, 'unknown') as fleet_type,
        d.pickup_city,
        count(*) as total_deliveries,
        count(*) filter (where d.normalized_status = 'delivered') as completed_deliveries,
        count(*) filter (where d.distance_km >= 100) as extreme_distance_deliveries,
        round(sum(d.distance_km), 2) as total_distance_km,
        round(sum(d.delivery_fee), 2) as total_delivery_fee
    from {{ ref('stg_deliveries') }} d
    left join {{ ref('stg_riders') }} r
        on d.rider_id = r.rider_id
    where not d.is_duplicate
    group by 1, 2, 3
),
tickets as (
    select
        ticket_week,
        sum(ticket_count) as total_tickets,
        sum(high_priority_count) as high_priority_tickets,
        sum(escalated_count) as escalated_tickets
    from {{ ref('stg_support_tickets_weekly') }}
    group by 1
)
select
    d.delivery_week,
    d.fleet_type,
    d.pickup_city,
    d.total_deliveries,
    d.completed_deliveries,
    d.extreme_distance_deliveries,
    d.total_distance_km,
    d.total_delivery_fee,
    coalesce(t.total_tickets, 0) as weekly_total_tickets,
    coalesce(t.high_priority_tickets, 0) as weekly_high_priority_tickets,
    coalesce(t.escalated_tickets, 0) as weekly_escalated_tickets
from deliveries d
left join tickets t
    on d.delivery_week = t.ticket_week
order by d.delivery_week, d.fleet_type, d.pickup_city