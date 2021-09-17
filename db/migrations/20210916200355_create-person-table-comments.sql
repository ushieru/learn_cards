-- migrate:up
COMMENT ON TABLE learn.person IS 'A user of the flashcard app.';
COMMENT ON COLUMN learn.person.id IS 'The primary unique identifier for the person.';
COMMENT ON COLUMN learn.person.first_name IS 'The persons first name.';
COMMENT ON COLUMN learn.person.last_name IS 'The persons last name.';
COMMENT ON COLUMN learn.person.created_at IS 'The time this person was created.';

-- migrate:down

