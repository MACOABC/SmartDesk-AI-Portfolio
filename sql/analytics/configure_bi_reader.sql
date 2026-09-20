\set ON_ERROR_STOP on

-- SMARTDESK_BI_PASSWORD must exist only in the secure execution environment.
-- The real value must never be committed or printed.
\getenv bi_password SMARTDESK_BI_PASSWORD

SELECT format(
    'CREATE ROLE smartdesk_bi_reader LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS PASSWORD %L',
    :'bi_password'
)
WHERE NOT EXISTS (
    SELECT 1 FROM pg_roles WHERE rolname = 'smartdesk_bi_reader'
)
\gexec

SELECT format(
    'ALTER ROLE smartdesk_bi_reader WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS PASSWORD %L',
    :'bi_password'
)
\gexec

ALTER ROLE smartdesk_bi_reader SET default_transaction_read_only = on;
ALTER ROLE smartdesk_bi_reader SET statement_timeout = '5min';

REVOKE ALL PRIVILEGES ON DATABASE smartdesk_db FROM smartdesk_bi_reader;
GRANT CONNECT ON DATABASE smartdesk_db TO smartdesk_bi_reader;

REVOKE ALL PRIVILEGES ON SCHEMA public FROM smartdesk_bi_reader;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM smartdesk_bi_reader;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM smartdesk_bi_reader;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public FROM smartdesk_bi_reader;

REVOKE ALL PRIVILEGES ON SCHEMA analytics FROM smartdesk_bi_reader;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA analytics FROM smartdesk_bi_reader;
GRANT USAGE ON SCHEMA analytics TO smartdesk_bi_reader;
GRANT SELECT ON
    analytics.v_ticket_lifecycle,
    analytics.v_ai_predictions,
    analytics.v_hitl_reviews,
    analytics.v_automation_events
TO smartdesk_bi_reader;
