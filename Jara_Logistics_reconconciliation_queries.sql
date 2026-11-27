--Query 1 — Monthly & Fleet Reconciliation (October vs. November):

select
    date_trunc('month', delivery_week)::date as delivery_month,
    fleet_type,
    sum(total_deliveries) as deliveries,
    sum(completed_deliveries) as completed,
    sum(extreme_distance_deliveries) as extreme_100km_plus,
    sum(total_distance_km) as total_km,
    sum(total_delivery_fee) as total_fee_ngn,
    round(sum(total_delivery_fee) / nullif(sum(total_deliveries), 0), 2) as avg_fee_per_delivery
from dbt_ademola.mart_fleet_reconciliation
group by 1, 2
order by 1, 2;

--Query 2 Check distinct fleet values in stg_riders
select fleet, count(*)
from dbt_ademola.stg_riders
group by 1;

-- Check orphan rider_ids in stg_deliveries
select d.rider_id, d.raw_delivery_fleet, count(*) as delivery_count, sum(d.delivery_fee) as total_fee
from dbt_ademola.stg_deliveries d
left join dbt_ademola.stg_riders r on d.rider_id = r.rider_id
where r.rider_id is null
group by 1, 2;

-- test to find details of four orphaned riders 

select d.rider_id, d.raw_delivery_fleet, count(*) as delivery_count, sum(d.delivery_fee) as total_fee
from dbt_ademola.stg_deliveries d
left join dbt_ademola.stg_riders r on d.rider_id = r.rider_id
where r.rider_id is null
group by 1, 2;

-- Query to check if support tickets spiked during those exact November weeks
select
    delivery_week,
    sum(extreme_distance_deliveries) as extreme_trips,
    sum(total_distance_km) as total_km,
    max(weekly_total_tickets) as total_tickets,
    max(weekly_high_priority_tickets) as high_priority_tickets,
    max(weekly_escalated_tickets) as escalated_tickets
from dbt_ademola.mart_fleet_reconciliation
where delivery_week between '2025-10-01' and '2025-12-31'
group by 1
order by 1;

-- Q2: Exact duplicate count and NGN impact (overall & November partner)
select
    count(*) filter (where is_duplicate) as duplicate_rows,
    round(sum(delivery_fee) filter (where is_duplicate), 2) as duplicate_fee_all,
    count(*) filter (where is_duplicate and date_trunc('month', created_at) = '2025-11-01') as nov_duplicate_rows,
    round(sum(delivery_fee) filter (where is_duplicate and date_trunc('month', created_at) = '2025-11-01'), 2) as nov_duplicate_fee
from dbt_ademola.stg_deliveries;

-- Q4: Raw status vs normalized_status breakdown
select
    status as raw_status,
    normalized_status,
    count(*) as row_count,
    round(sum(delivery_fee), 2) as total_fee
from dbt_ademola.stg_deliveries
where not is_duplicate
group by 1, 2
order by 3 desc;

-- Q5 & Q6: Reproduce October bank figure (NGN 773,146) & get exact November payout
select
    date_trunc('month', d.created_at)::date as month,
    coalesce(r.fleet, d.raw_delivery_fleet, 'unknown') as fleet_type,
    count(*) filter (where d.normalized_status = 'delivered') as delivered_trips,
    round(sum(d.delivery_fee) filter (where d.normalized_status = 'delivered'), 2) as delivered_fee_total,
    round(sum(d.distance_km) filter (where d.normalized_status = 'delivered'), 2) as delivered_km_total
from dbt_ademola.stg_deliveries d
left join dbt_ademola.stg_riders r on d.rider_id = r.rider_id
where not d.is_duplicate
  and coalesce(r.fleet, d.raw_delivery_fleet, 'unknown') = 'partner'
group by 1, 2
order by 1;

-- Q7: Reverse-engineer NGN 127,983,042 arithmetic on November partner deliveries( key part of the Capstone)
select
    count(*) as nov_partner_rows,
    count(*) filter (where not is_duplicate) as deduped_rows,
    round(sum(distance_km), 2) as raw_total_km,
    round(sum(distance_km) filter (where not is_duplicate), 2) as deduped_total_km,
    round(sum(delivery_fee), 2) as raw_total_fee,
    round(sum(delivery_fee) filter (where not is_duplicate), 2) as deduped_total_fee,
    round(127983042.0 / nullif(sum(distance_km) filter (where not is_duplicate), 0), 4) as implied_rate_per_km_deduped,
    round(127983042.0 / nullif(sum(distance_km), 0), 4) as implied_rate_per_km_raw
from dbt_ademola.stg_deliveries d
left join dbt_ademola.stg_riders r on d.rider_id = r.rider_id
where date_trunc('month', d.created_at) = '2025-11-01'
  and coalesce(r.fleet, d.raw_delivery_fleet, 'unknown') = 'partner';

-- To do final checks
-- 1. Check exact column names in stg_deliveries
select column_name, data_type
from information_schema.columns
where table_schema = 'dbt_ademola'
  and table_name = 'stg_deliveries'
order by ordinal_position;

-- 2. Breakdown by normalized_status (and check raw.deliveries status values too)
select
    normalized_status,
    count(*) as row_count,
    round(sum(delivery_fee), 2) as total_fee
from dbt_ademola.stg_deliveries
where not is_duplicate
group by 1
order by 2 desc;

select
    status as raw_deliveries_status,
    count(*) as raw_row_count,
    round(sum(delivery_fee), 2) as raw_total_fee
from raw.deliveries
group by 1
order by 2 desc;

-- Check exact October & November partner components (including 'completed' vs 'delivered' and rider rates)
select column_name, data_type
from information_schema.columns
where table_schema = 'raw'
  and table_name in ('riders', 'deliveries')
order by table_name, ordinal_position;

select
    date_trunc('month', d.created_at)::date as month,
    d.status as raw_status,
    count(*) as trips,
    round(sum(d.distance_km), 2) as total_km,
    round(sum(d.delivery_fee), 2) as total_fee
from dbt_ademola.stg_deliveries stg
join raw.deliveries d on stg.delivery_id = d.delivery_id and stg.created_at = d.created_at
left join dbt_ademola.stg_riders r on stg.rider_id = r.rider_id
where not stg.is_duplicate
  and coalesce(r.fleet, stg.raw_delivery_fleet, 'unknown') = 'partner'
  and date_trunc('month', d.created_at) in ('2025-10-01', '2025-11-01')
group by 1, 2
order by 1, 2;

-- Inspect the November partner extreme-distance trips and compute exact normalized November payout
with nov_partner_delivered as (
    select
        d.delivery_id,
        d.rider_id,
        d.pickup_city,
        d.distance_km,
        case
            when d.distance_km >= 100 then d.distance_km / 100.0
            else d.distance_km
        end as corrected_distance_km
    from dbt_ademola.stg_deliveries d
    left join dbt_ademola.stg_riders r on d.rider_id = r.rider_id
    where not d.is_duplicate
      and coalesce(r.fleet, d.raw_delivery_fleet, 'unknown') = 'partner'
      and d.normalized_status = 'delivered'
      and date_trunc('month', d.created_at) = '2025-11-01'
)
select
    count(*) as total_delivered_trips,
    count(*) filter (where distance_km >= 100) as extreme_trips_count,
    round(sum(distance_km), 2) as raw_delivered_km,
    round(sum(corrected_distance_km), 2) as corrected_delivered_km,
    round(sum(corrected_distance_km) * 220, 2) as final_november_payout_ngn
from nov_partner_delivered;

-- Singular test encoding Jara Logistics' ground-truth bank settlements:
-- October 2025 partner delivered payout must equal NGN 773,146
-- December 2025 partner delivered payout must equal NGN 775,852

with monthly_partner_payout as (
    select
        date_trunc('month', d.created_at)::date as delivery_month,
        round(sum(d.distance_km) * 220, 0) as calculated_payout_ngn
    from dbt_ademola.stg_deliveries d
    left join dbt_ademola.stg_riders r
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
  

  -- Singular test encoding Jara Logistics' ground-truth bank settlements:
-- October 2025 partner delivered payout must equal NGN 773,146
-- December 2025 partner delivered payout must equal NGN 775,852
select
    date_trunc('month', d.created_at)::date as delivery_month,
    count(*) as delivered_trips,
    round(sum(d.distance_km), 2) as delivered_km,
    round(sum(d.distance_km) * 220, 0) as calculated_payout_ngn
from dbt_ademola.stg_deliveries d
left join dbt_ademola.stg_riders r
    on d.rider_id = r.rider_id
where not d.is_duplicate
  and d.normalized_status = 'delivered'
  and coalesce(r.fleet, d.raw_delivery_fleet, 'unknown') = 'partner'
  and date_trunc('month', d.created_at)::date in ('2025-10-01', '2025-12-01')
group by 1
order by 1;