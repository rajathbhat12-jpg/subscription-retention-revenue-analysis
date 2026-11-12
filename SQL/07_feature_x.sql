-- 07_feature_x.sql

-- Do paying customers who used feature X cancel less often than those who didn't?
-- "Used feature X" = at least one feature_x_used event in events_clean.
-- Paying customers = subscriptions_clean (2,851). Cancelled = status 'cancelled'.
-- Data is synthetic: the generator built a feature X effect in, so this shows
-- the method, not a real-world discovery.

-- Finding: used feature X: 31.1% churn (321 of 1,032 customers);
--          did not use it: 49.9% churn (907 of 1,819).
--          Gap of 18.8 points; non-users cancel about 1.6x as often.
--          Only about 36% of paying customers used feature X at all.
-- Check: customers add up to 2,851 and cancelled add up to 1,228.
-- Caveats:
--   1. Correlation, not proof of cause. Users who use a feature may be more
--      engaged to begin with and would have stayed anyway.
--   2. Time bias: customers who stay longer have had more time to try the
--      feature, so some of the gap may be tenure and not the feature.
--   3. Feature X use is linked to onboarding in this data, so part of the gap
--      may be the onboarding effect. A real analysis would compare within
--      onboarded users, and within the same tenure.
WITH feature_users AS (
    SELECT DISTINCT user_id
    FROM events_clean
    WHERE event_type = 'feature_x_used'
)
SELECT CASE WHEN f.user_id IS NOT NULL THEN 'used feature X'
            ELSE 'did not use feature X' END AS feature_group,
       COUNT(*) AS customers,
       COUNT(*) FILTER (WHERE s.status = 'cancelled') AS cancelled,
       ROUND(COUNT(*) FILTER (WHERE s.status = 'cancelled') * 100.0 / COUNT(*), 1) AS churn_rate_pct
FROM subscriptions_clean s
LEFT JOIN feature_users f ON s.user_id = f.user_id
GROUP BY feature_group
ORDER BY feature_group;