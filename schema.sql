-- schema.sql
-- Subscription-app analytics project (PostgreSQL)
-- Run this in the Query Tool of a fresh database (e.g. subscription_analytics).
--
-- NOTE: there are no FOREIGN KEY constraints on purpose. The dataset contains
-- deliberately dirty rows (orphan payments, etc.) and foreign keys would reject
-- them at load time. Adding constraints AFTER cleaning is part of Day 2.

DROP TABLE IF EXISTS events, payments, subscriptions, users CASCADE;

-- One row per person who signed up (free tier by default)
CREATE TABLE users (
    user_id              INTEGER PRIMARY KEY,
    name                 VARCHAR(100),
    email                VARCHAR(150),
    signup_date          DATE NOT NULL,
    country              VARCHAR(50),
    acquisition_channel  VARCHAR(30)
);

-- One row per paid subscription (a user can have 0 or 1 in this dataset)
CREATE TABLE subscriptions (
    subscription_id  INTEGER PRIMARY KEY,
    user_id          INTEGER NOT NULL,
    plan             VARCHAR(20) NOT NULL,       -- Basic / Pro / Premium
    monthly_price    NUMERIC(10,2) NOT NULL,     -- INR
    start_date       DATE NOT NULL,
    end_date         DATE,                       -- NULL = still active
    status           VARCHAR(20) NOT NULL        -- active / cancelled
);

-- One row per monthly charge
CREATE TABLE payments (
    payment_id       INTEGER PRIMARY KEY,
    user_id          INTEGER NOT NULL,
    subscription_id  INTEGER,
    amount           NUMERIC(10,2) NOT NULL,
    payment_date     DATE NOT NULL
);

-- One row per product event (signup, login, onboarding_complete, feature_x_used)
CREATE TABLE events (
    event_id    INTEGER PRIMARY KEY,
    user_id     INTEGER NOT NULL,
    event_type  VARCHAR(40) NOT NULL,
    event_time  TIMESTAMP NOT NULL
);
