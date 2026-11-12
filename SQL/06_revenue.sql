-- 06_revenue.sql
-- Revenue from payments_clean (amounts are positive after cleaning). Synthetic data.

-- Step 1: monthly total revenue
-- Finding: grew from ~27,500 (Jan 2025) to ~619,000 (Sep 2026), but growth is slowing (about +1.4% from Aug to Sep 2026).

SELECT DATE_TRUNC('month', payment_date)::date AS payment_month,
       SUM(amount) AS total_revenue
FROM payments_clean
GROUP BY DATE_TRUNC('month', payment_date)::date
ORDER BY payment_month;

-- Step 2: monthly revenue by plan
-- Finding: in Sep 2026 Basic has the most payments (893) but only ~29% of
--          revenue; Pro brings in ~43%; Premium has 177 payments (~11%) but ~29%
--          of revenue.
SELECT DATE_TRUNC('month',p.payment_date)::date AS payment_month , p.amount ,s.plan,SUM(p.amount) AS total_revenue
FROM payments_clean p
LEFT JOIN subscriptions_clean s ON p.subscription_id = s.subscription_id
GROUP BY payment_month , p.amount, s.plan 
ORDER BY payment_month ASC;

-- Step 3: month-over-month revenue growth (LAG)
-- Finding: growth slows as the base grows (167% in Feb 2025 to about 1-7% in
--          2026). Month-to-month growth is lumpy because charges are 30 days
--          apart: 28-day February shows a dip (-4.7%, 1,154 payments vs 1,215
--          in January) and 31-day months show jumps. Year over year is cleaner:
--          Sep 2026 vs Sep 2025 is +85%.

WITH per_month AS (
  SELECT DATE_TRUNC('month', payment_date)::date AS payment_month,
       SUM(amount) AS total_revenue
  FROM payments_clean
  GROUP BY DATE_TRUNC('month', payment_date)::date
),
 with_revenue AS (
       SELECT total_revenue, payment_month ,
       LAG(total_revenue) OVER(ORDER BY payment_month) AS previous_revenue
       FROM per_month
)
       SELECT 
        payment_month, total_revenue , previous_revenue , 
		ROUND((total_revenue - previous_revenue) * 100.0 / previous_revenue , 1) AS growth_pct
		FROM with_revenue
		ORDER BY payment_month;
		
		



