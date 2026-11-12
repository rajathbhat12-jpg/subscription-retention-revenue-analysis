-- 03_funnel.sql

-- Funnel: signup -> finished onboarding -> paying customer
-- Uses the clean tables only (users_clean, events_clean, subscriptions_clean).
-- Data is synthetic; the patterns in it were built in by the generator.

-- Guess before running: ~80-90% finish onboarding, ~50-60% of those pay.

-- Stage 1: signups
-- Finding: 15,015 users
SELECT COUNT(*) AS signups
FROM users_clean;

-- Stage 2: finished onboarding (distinct users, not events)
-- Finding: 8,839 users (58.9% of signups). Guess was too high.
SELECT COUNT(DISTINCT user_id) AS onboarded
FROM events_clean
WHERE event_type = 'onboarding_complete';

-- Stage 3: became a paying customer (cancelled subscriptions count too,
-- because the funnel measures conversion, not current status)
-- Finding: 2,851 users (19.0% of signups). No user has more than one
-- subscription, so rows = distinct users.
SELECT COUNT(DISTINCT user_id) AS paying
FROM subscriptions_clean;

-- Overlap: users who finished onboarding AND pay
-- Finding: 2,587 users
SELECT COUNT(DISTINCT s.user_id) AS onboarded_and_paying
FROM events_clean e
INNER JOIN subscriptions_clean s ON e.user_id = s.user_id
WHERE e.event_type = 'onboarding_complete';

-- Comparison (calculated from the counts above):
--   Finished onboarding:      2,587 / 8,839 = 29.3% pay
--   Did not finish onboarding:  264 / 6,176 =  4.3% pay
--   => about 6.8x more likely to pay after finishing onboarding

-- Recommendation: 41% of signups never finish onboarding and almost never pay.
-- Raising completion is the biggest lever in the funnel. Caveat: correlation,
-- not proof of cause; people who finish onboarding may be more motivated anyway.