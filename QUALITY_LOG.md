# Jara Logistics — Data Quality Log

**Project:** Partner Fleet Cost Reconciliation (Sept – Dec 2025)
**Author:** Ademola
**Stack:** PostgreSQL (Neon), MongoDB, dbt Core

## Data Defects, Detection & Resolutions

| # | Defect | Scope / Evidence | How It Was Found | Impact | Resolution in Pipeline |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Duplicate deliveries | `9` duplicate rows (`2` in Nov) | Window function deduplication (`is_duplicate`) & schema checks | Inflated gross fees by `NGN 20,485.44` (`NGN 4,956.25` in Nov) and double-counted km | Flagged in `stg_deliveries` and excluded via `where not is_duplicate` |
| 2 | Status casing & synonyms | `'delivered'`, `'Delivered'`, `'completed'`, `'Failed'` | Raw status frequency profiling | Filtering only `'delivered'` missed valid delivered trips and underpaid partners | Standardized in `stg_deliveries` (`normalized_status`) |
| 3 | Extreme distance anomaly ($\ge 100\text{ km}$) | `107` partner trips in week of `2025-11-17` (`75` delivered) | Weekly fleet segmentation (`mart_fleet_reconciliation`) | Inflated partner mileage (`581,741.10 km × NGN 220 = NGN 127,983,042`) | Flagged extreme trips in mart; normalized `100x` distance error (`8,706.00 km × NGN 220 = NGN 1,915,320.00` Nov payout) |
| 4 | Orphan / sentinel `rider_id = 9999` | `4` deliveries (`1` own, `3` partner) missing from `raw.riders` | dbt `relationships` test (`WARN 4`) | Strict inner/left join without fallback could drop fleet assignment | Used `coalesce(r.fleet, d.raw_delivery_fleet, 'unknown')` to retain rows |
| 5 | Support ticket surge | `108` tickets (`53` high-priority, `49` escalated) in week of `2025-11-10` | MongoDB weekly aggregation joined by ISO week | Confirmed mid-November operational issue preceding the `2025-11-17` distance spike | Aggregated in MongoDB, loaded to `raw.support_tickets_weekly`, and joined in mart |

## Bank & November Payout Summary (`NGN 220 / km`)
- **October 2025:** `3,514.30 km × 220 = NGN 773,146` (matches bank settlement)
- **November 2025:** `8,706.00 km` (normalized delivered km) `× 220 = NGN 1,915,320`
- **December 2025:** `3,526.60 km × 220 = NGN 775,852` (matches bank settlement)