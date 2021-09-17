-- migrate:up
CREATE TYPE learn.jwt AS (
    role text,
    person_id integer,
    exp bigint
);

-- migrate:down
DROP TYPE learn.jwt;
