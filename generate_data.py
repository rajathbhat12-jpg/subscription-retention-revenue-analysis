"""
generate_data.py
Generates a SYNTHETIC, deliberately messy dataset for a subscription app.
Standard library only, so there is nothing to pip install.

Run:      python generate_data.py
Creates:  users.csv, subscriptions.csv, payments.csv, events.csv

IMPORTANT: this data is synthetic. Patterns in it (e.g. onboarding -> higher
conversion, feature X -> lower churn) were built in by the generator's
assumptions. Say so in your README. The project shows your METHOD, not a
real-world discovery.
"""
import csv
import random
from datetime import date, datetime, timedelta

random.seed(42)

N_USERS = 15000
START = date(2025, 1, 1)
END = date(2026, 9, 30)  # data is "as of" this date

PLANS = {"Basic": 199, "Pro": 499, "Premium": 999}  # monthly price, INR
PLAN_WEIGHTS = [0.55, 0.35, 0.10]
CHANNELS = ["organic", "paid_ads", "referral", "social"]
CHANNEL_WEIGHTS = [0.40, 0.25, 0.20, 0.15]
COUNTRIES = ["India", "USA", "UK", "UAE", "Singapore", "Germany"]
COUNTRY_WEIGHTS = [0.70, 0.10, 0.05, 0.05, 0.05, 0.05]

FIRST = ["Asha", "Ravi", "Meera", "Arjun", "Priya", "Karthik", "Ananya", "Rohan",
         "Divya", "Vikram", "Sneha", "Nikhil", "Kavya", "Aditya", "Pooja", "Suresh",
         "Neha", "Manoj", "Lakshmi", "Sanjay"]
LAST = ["Sharma", "Reddy", "Iyer", "Nair", "Gowda", "Patel", "Rao", "Menon",
        "Kumar", "Singh", "Shetty", "Joshi", "Bhat", "Das", "Verma"]


def rand_date(a, b):
    """Random date between a and b inclusive."""
    return a + timedelta(days=random.randint(0, (b - a).days))


def ts(d):
    """Turn a date into a timestamp with a random time of day."""
    return datetime(d.year, d.month, d.day,
                    random.randint(6, 23), random.randint(0, 59), random.randint(0, 59))


users, subs, payments, events = [], [], [], []
sub_id = pay_id = ev_id = 0


def add_event(uid, etype, d):
    global ev_id
    ev_id += 1
    events.append([ev_id, uid, etype, ts(d)])


# ---------------------------------------------------------------- clean data
for uid in range(1, N_USERS + 1):
    first, last = random.choice(FIRST), random.choice(LAST)
    signup = rand_date(START, END)
    users.append([
        uid,
        f"{first} {last}",
        f"{first}.{last}{uid}@example.com".lower(),
        signup,
        random.choices(COUNTRIES, COUNTRY_WEIGHTS)[0],
        random.choices(CHANNELS, CHANNEL_WEIGHTS)[0],
    ])

    # Behaviour assumptions (these create the "findings")
    onboarded = random.random() < 0.60
    used_x = random.random() < (0.40 if onboarded else 0.10)

    add_event(uid, "signup", signup)
    if onboarded:
        delay = random.randint(0, 6) if random.random() < 0.8 else random.randint(7, 14)
        d = signup + timedelta(days=delay)
        if d <= END:
            add_event(uid, "onboarding_complete", d)

    last_active = min(END, signup + timedelta(days=random.randint(10, 90)))
    paid = False

    # Free -> paid conversion
    if random.random() < (0.30 if onboarded else 0.04):
        start = signup + timedelta(days=random.randint(0, 30))
        if start <= END:
            paid = True
            plan = random.choices(list(PLANS), PLAN_WEIGHTS)[0]
            price = PLANS[plan]
            churn_p = 0.04 if used_x else (0.08 if onboarded else 0.14)
            sub_id += 1
            end_date = None
            m = 0
            while True:
                pay_date = start + timedelta(days=30 * m)
                if pay_date > END:
                    break
                pay_id += 1
                payments.append([pay_id, uid, sub_id, price, pay_date])
                if random.random() < churn_p:
                    end_date = pay_date + timedelta(days=30)
                    break
                m += 1
            if end_date is not None and end_date > END:
                end_date = None
            status = "cancelled" if end_date else "active"
            subs.append([sub_id, uid, plan, price, start, end_date, status])
            last_active = end_date if end_date else END

    # Logins and feature usage between signup and last activity
    n_logins = random.randint(5, 25) if (onboarded or paid) else random.randint(0, 6)
    for _ in range(n_logins):
        add_event(uid, "login", rand_date(signup, last_active))
    if used_x:
        for _ in range(random.randint(1, 8)):
            add_event(uid, "feature_x_used", rand_date(signup, last_active))

# ---------------------------------------------------------------- dirty data
# 1. Duplicate users (~2%): same person signed up twice, one day apart
for u in random.sample(users, int(N_USERS * 0.02)):
    users.append([len(users) + 1, u[1], u[2], min(u[3] + timedelta(days=1), END), u[4], u[5]])

# 2. Missing emails (~3%)
for u in random.sample(users, int(len(users) * 0.03)):
    u[2] = None

# 3. Inconsistent country spelling (~8%)
for u in random.sample(users, int(len(users) * 0.08)):
    c = u[4]
    if c == "India" and random.random() < 0.3:
        u[4] = "IN"
    else:
        u[4] = random.choice([c.lower(), c.upper(), " " + c, c + " "])

# 4. Orphan payments: user_id does not exist in users (~1%)
for p in random.sample(payments, int(len(payments) * 0.01)):
    p[1] = random.randint(90000, 99999)

# 5. Duplicate payment rows (~1%): same charge recorded twice
for p in random.sample(payments, int(len(payments) * 0.01)):
    pay_id += 1
    payments.append([pay_id, p[1], p[2], p[3], p[4]])

# 6. Payments missing a subscription_id (~1%)
for p in random.sample(payments, int(len(payments) * 0.01)):
    p[2] = None

# 7. Negative payment amounts (~0.5%)
for p in random.sample(payments, int(len(payments) * 0.005)):
    p[3] = -p[3]

# 8. Events that happen BEFORE the user signed up (~1%)
signup_of = {u[0]: u[3] for u in users}
for e in random.sample(events, int(len(events) * 0.01)):
    e[3] = ts(signup_of[e[1]] - timedelta(days=random.randint(1, 30)))

# 9. Subscriptions that end before they start (~1%)
cancelled = [s for s in subs if s[5] is not None]
for s in random.sample(cancelled, max(1, int(len(subs) * 0.01))):
    s[5] = s[4] - timedelta(days=random.randint(1, 5))


# ---------------------------------------------------------------- write CSVs
def write(filename, header, rows):
    with open(filename, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"{filename}: {len(rows):,} rows")


write("users.csv",
      ["user_id", "name", "email", "signup_date", "country", "acquisition_channel"], users)
write("subscriptions.csv",
      ["subscription_id", "user_id", "plan", "monthly_price", "start_date", "end_date", "status"], subs)
write("payments.csv",
      ["payment_id", "user_id", "subscription_id", "amount", "payment_date"], payments)
write("events.csv",
      ["event_id", "user_id", "event_type", "event_time"], events)
