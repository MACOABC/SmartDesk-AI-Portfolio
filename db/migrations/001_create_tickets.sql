BEGIN;

CREATE TABLE tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_email TEXT NOT NULL,
    requester_area TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'processing',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT tickets_requester_email_length_check
        CHECK (char_length(requester_email) <= 254),
    CONSTRAINT tickets_requester_email_format_check
        CHECK (
            requester_email ~* '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$'
        ),
    CONSTRAINT tickets_requester_area_length_check
        CHECK (
            char_length(requester_area) <= 80
            AND char_length(btrim(requester_area)) >= 2
        ),
    CONSTRAINT tickets_title_length_check
        CHECK (
            char_length(title) <= 150
            AND char_length(btrim(title)) >= 5
        ),
    CONSTRAINT tickets_description_length_check
        CHECK (
            char_length(description) <= 5000
            AND char_length(btrim(description)) >= 10
        ),
    CONSTRAINT tickets_status_check
        CHECK (status IN ('processing', 'open', 'closed'))
);

COMMIT;
