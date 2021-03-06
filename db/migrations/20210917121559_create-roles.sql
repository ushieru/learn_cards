-- migrate:up
CREATE ROLE learn_postgraphile LOGIN PASSWORD 'secret_password';

CREATE ROLE learn_anonymous;

GRANT learn_anonymous TO learn_postgraphile;

CREATE ROLE learn_person;

GRANT learn_person TO learn_postgraphile;

-- migrate:down
DROP ROLE learn_postgraphile;

DROP ROLE learn_anonymous;

DROP ROLE learn_person;
