-- migrate:up
ALTER DEFAULT privileges REVOKE EXECUTE ON functions FROM public;

GRANT usage ON SCHEMA learn TO learn_anonymous, learn_person;

GRANT EXECUTE ON FUNCTION learn.register_person (text, text, text, text) TO learn_anonymous;
GRANT EXECUTE ON FUNCTION learn.authenticate (text, text) TO learn_anonymous, learn_person;
GRANT EXECUTE ON FUNCTION learn.handle_score (integer, integer) TO learn_person;

GRANT ALL privileges ON TABLE learn.person TO learn_person;
GRANT SELECT, DELETE ON TABLE learn.card TO learn_person;
GRANT INSERT, UPDATE (id, question, answer, archived) ON TABLE learn.card TO learn_person;
GRANT usage ON SEQUENCE learn.card_id_seq TO learn_person;
GRANT SELECT ON TABLE learn.response TO  learn_person;
GRANT SELECT ON learn.next_card TO learn_person;

-- migrate:down
ALTER DEFAULT privileges GRANT EXECUTE ON functions FROM public;

REVOKE usage ON SCHEMA learn TO learn_anonymous, learn_person;

REVOKE EXECUTE ON FUNCTION learn.register_person (text, text, text, text) TO learn_anonymous;
REVOKE EXECUTE ON FUNCTION learn.authenticate (text, text) TO learn_anonymous, learn_person;
REVOKE EXECUTE ON FUNCTION learn.handle_score (integer, integer) TO learn_person;

REVOKE ALL privileges ON TABLE learn.person TO learn_person;
REVOKE SELECT, DELETE ON TABLE learn.card TO learn_person;
REVOKE INSERT, UPDATE (id, question, answer, archived) ON TABLE learn.card TO learn_person;
REVOKE usage ON SEQUENCE learn.card_id_seq TO learn_person;
REVOKE SELECT ON TABLE learn.response TO  learn_person;
REVOKE SELECT ON learn.next_card TO learn_person;
