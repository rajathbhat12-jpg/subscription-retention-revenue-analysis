# User Retention & Revenue Analysis | PostgreSQL

An end-to-end SQL analysis of a subscription app: auditing messy data, cleaning it,
and answering the questions a product team would ask about conversion, churn,
retention and revenue.

> **Note: the dataset is synthetic.** I generated it with a Python script
> (`generate_data.py`), and the patterns in it (for example the effect of onboarding
> and of feature X) were built in by the generator. The project demonstrates my
> method, not a real-world discovery.

## The business question
Where does the app lose people between signup and paying, how long do paying
customers stay, and what should the team do about it?

## Headline findings
- **Onboarding is the gate to paying.** Only 58.9% of 15,015 signups finish onboarding.
  Those who do pay at 29.3%; those who don't pay at 4.3% (about 6.8x less often).
- **Churn is steady.** Monthly churn of paying customers has been about 6.6% since
  mid-2025, an average lifetime of roughly 15 months.
- **Free users fade fast.** In the January 2025 cohort, activity falls from 76% in
  month 1 to 23% in month 3, then settles at about 6-9%.
- **Feature X is linked to lower churn.** Customers who used it cancelled at 31.1%
  against 49.9% for those who didn't, but only 36% of paying customers used it.
- **Revenue grew from about 27,500 to 619,000 a month** (Jan 2025 to Sep 2026), +85%
  year over year in Sep 2026, with month-to-month growth slowing to 1-7%.
- **Basic is the biggest plan by payments (56%) but only 29% of revenue;** Pro brings in 43%.

## Recommendations

Recommendation 1: Get more new users through onboarding.

Finding: Only 58.9% of signups finish onboarding (8,839 of 15,015). Those who do pay at 29.3%. Those who don’t pay at 4.3%, about 6.8 times less often.
So what: Onboarding is where the funnel leaks most. 41% of users drop out before they’ve used the product, and they almost never convert.
Action: Shorten the onboarding flow. Send a reminder to anyone who hasn’t finished within 3 days of signup. Track the completion rate as the main success measure.
Caveat: People who finish onboarding may simply be more motivated, so the 6.8x gap overstates what onboarding alone would achieve. Test the change with a controlled experiment first.

Recommendation 2: Get paying customers to try feature X early.

Finding: Paying customers who used feature X cancelled at 31.1% (321 of 1,032). Those who didn’t cancelled at 49.9% (907 of 1,819). Only about 36% of paying customers used it.
So what: The feature is linked to much lower cancellation, but most customers never discover it.
Action: Introduce feature X right after onboarding, for example with a short guided prompt. Track the share of new customers who use it in their first week. As an idea to test later, offer a limited-time free taste of the feature.
Caveat: Engaged customers may use more features anyway, and customers who stay longer have had more time to try it. An experiment would show whether showing the feature early really reduces cancellation.

Recommendation 3: Understand and reduce paying-customer churn.

Finding: Monthly churn has been flat at about 6.6% since mid-2025, so the average customer stays about 15 months.
So what: Churn caps the value of every customer you acquire. Cutting it by one point, to 5.6%, lengthens the average stay to about 18 months, roughly 18% more revenue per customer.
Action: Add an exit survey to the cancellation flow. Analyse churn by months since subscription to find where customers leave. Use that to design one targeted retention step, aiming for 5.6% monthly churn within two quarters.
Caveat: The 6.6% is an average and may hide a spike at a particular point in the subscription. The data is synthetic, and the feature X link to lower churn may partly be an engagement effect.

Recommendation 4: Move engaged Basic customers up to Pro.

Finding: In September 2026, Basic made up 893 of 1,600 payments (56%) but only 28.7% of revenue. Pro brought in 42.7%. Churn is similar across plans.
So what: Each Basic-to-Pro upgrade adds ₹300 a month. If 10% of Basic customers upgraded, monthly revenue would rise by roughly 4%, with no new customers needed.
Action: Test an upgrade prompt aimed at engaged Basic customers, such as feature X users, as an A/B test. Track upgrade rate, revenue per customer and churn after the upgrade.
Caveat: The data doesn’t say why customers chose Basic or whether they’d pay more. Price-sensitive customers may leave instead of upgrading. The dataset is synthetic.

## Data
Four tables (schema diagram: ![Schema diagram](images/schema.PNG)):
- `users`: one row per signup (date, country, acquisition channel)
- `subscriptions`: one row per paid subscription (plan, price, dates, status)
- `payments`: one row per monthly charge
- `events`: product events (signup, login, onboarding_complete, feature_x_used)

## Data quality audit
Nine problems were found with SQL before any analysis (`sql/01_data_quality_audit.sql`):

| Problem | Rows affected |
|---|---|
| Missing email | 459 users |
| Inconsistent country spelling | 28 spellings for 6 countries |
| Duplicate users | 285 |
| Orphan payments (no matching user) | 211 |
| Negative payment amounts | 105 (100 behaved like sign errors) |
| Payments with no subscription ID | 211 |
| Events dated before signup | 1,979 |
| Subscriptions ending before they start | 28 |
| Duplicate payments | 200 groups |

## Cleaning approach
Raw tables are never modified. Cleaned copies (`users_clean`, `subscriptions_clean`,
`payments_clean`, `events_clean`) are built by `sql/02_cleaning.sql`, which can be
re-run from scratch. Removed payments go to a quarantine table instead of being
deleted, and row counts are reconciled at each step.

## How to run
1. Create a PostgreSQL database and run `schema.sql`.
2. Run `python generate_data.py` to create four CSV files.
3. Import the CSVs into the matching tables.
4. Run the files in `sql/` in order, 01 to 07.

## Repository contents
- `schema.sql`, `generate_data.py`
- `sql/01_data_quality_audit.sql` ... `sql/07_feature_x.sql`

## Skills demonstrated
Joins (including self-joins), CTEs, window functions (ROW_NUMBER, LAG), cohort
analysis, date handling, data cleaning and reconciliation, and metric definition.

## Limitations
The data is synthetic. Findings are correlations, not proof of cause. Plan-level
churn differences are small and probably noise.