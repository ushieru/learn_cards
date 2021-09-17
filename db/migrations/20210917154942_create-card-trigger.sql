-- migrate:up
CREATE FUNCTION learn_private.set_person_id()
    RETURNS TRIGGER
    AS $$
BEGIN
    NEW.person_id := current_setting('jwt.claims.person_id');
    RETURN new;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER card_person_id
    BEFORE INSERT ON learn.card FOR EACH ROW
    EXECUTE PROCEDURE learn_private.set_person_id();

-- migrate:down
DROP TRIGGER card_person_id ON learn.card;
DROP FUNCTION learn_private.set_person_id();
