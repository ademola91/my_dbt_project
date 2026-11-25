with monthly_partner_payout as (
    select
        date_trunc('month', d.created_at)::date as delivery_month,
        round(sum(d.distance_km) * 220, 0) as calculated_payout_ngn
    from {{ ref('stg_deliveries') }} d
    left join {{ ref('stg_riders') }} r
        on d.rider_id = r.rider_id
    where not d.is_duplicate
      and d.normalized_status = 'delivered'
      and coalesce(r.fleet, d.raw_delivery_fleet, 'unknown') = 'partner'
      and date_trunc('month', d.created_at)::date in ('2025-10-01', '2025-12-01')
    group by 1
)

select
    delivery_month,
    calculated_payout_ngn
from monthly_partner_payout
where (delivery_month = '2025-10-01' and calculated_payout_ngn != 773146)
   or (delivery_month = '2025-12-01' and calculated_payout_ngn != 775852)