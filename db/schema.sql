SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: learn; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA learn;


--
-- Name: learn_private; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA learn_private;


--
-- Name: postgraphile_watch; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA postgraphile_watch;


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: jwt; Type: TYPE; Schema: learn; Owner: -
--

CREATE TYPE learn.jwt AS (
	role text,
	person_id integer,
	exp bigint
);


--
-- Name: score_response; Type: TYPE; Schema: learn; Owner: -
--

CREATE TYPE learn.score_response AS (
	ease_factor numeric(7,4),
	spacing integer
);


--
-- Name: authenticate(text, text); Type: FUNCTION; Schema: learn; Owner: -
--

CREATE FUNCTION learn.authenticate(email text, password text) RETURNS learn.jwt
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    AS $$
DECLARE
    account learn_private.person_account;
BEGIN
    SELECT
        * INTO account
    FROM
        learn_private.person_account
    WHERE
        person_account.email = authenticate.email;

    IF account.password_hash = crypt(password, account.password_hash) THEN
        RETURN ('learn_person',
            account.person_id,
            extract(epoch FROM (now() + interval '30 days'))
        )::learn.jwt;
    ELSE
        RETURN NULL;
    END IF;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: card; Type: TABLE; Schema: learn; Owner: -
--

CREATE TABLE learn.card (
    id integer NOT NULL,
    question text NOT NULL,
    answer text NOT NULL,
    review_after timestamp with time zone DEFAULT now() NOT NULL,
    spacing integer DEFAULT 0 NOT NULL,
    ease_factor numeric(7,4) DEFAULT 2.5 NOT NULL,
    seq integer DEFAULT 0 NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    person_id integer,
    create_at timestamp with time zone DEFAULT now(),
    CONSTRAINT card_ease_factor_check CHECK ((ease_factor >= 1.3)),
    CONSTRAINT card_seq_check CHECK ((seq >= 0)),
    CONSTRAINT card_spacing_check CHECK ((spacing >= 0))
);


--
-- Name: TABLE card; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON TABLE learn.card IS 'An individual persons flash card';


--
-- Name: COLUMN card.id; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.card.id IS 'The primary unique identifier for the flash card.';


--
-- Name: COLUMN card.question; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.card.question IS 'The question to prompt the person';


--
-- Name: COLUMN card.answer; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.card.answer IS 'The answer to the question';


--
-- Name: COLUMN card.review_after; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.card.review_after IS '@omit create,update
The next time the card should be reviewed';


--
-- Name: COLUMN card.spacing; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.card.spacing IS '@omit create,update
The current spacing in days between reviews';


--
-- Name: COLUMN card.ease_factor; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.card.ease_factor IS '@omit create,update
The ease at wich the answer was last remembered';


--
-- Name: COLUMN card.seq; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.card.seq IS '@omit create,update
Controls the order in wich to review cards';


--
-- Name: COLUMN card.archived; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.card.archived IS 'Indicater if the card is active or not';


--
-- Name: COLUMN card.person_id; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.card.person_id IS '@omit create,update
The creator/owner of this card';


--
-- Name: COLUMN card.create_at; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.card.create_at IS '@omit create,update
The time this card was created';


--
-- Name: handle_score(integer, integer); Type: FUNCTION; Schema: learn; Owner: -
--

CREATE FUNCTION learn.handle_score(card_id integer, score integer) RETURNS learn.card
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    card learn.card;
    ease_factor numeric(7, 4);
    new_review_after timestamptz;
    response learn.score_response;
BEGIN
    SELECT
        *   INTO card
    FROM
        learn.card
    WHERE
        id = card_id;
    response = learn.score_response(score, card.spacing, card.ease_factor);
    new_review_after = card.review_after + interval '1 day' * response.spacing;
    UPDATE
        learn.card
    SET
        spacing = response.spacing,
        ease_factor = response.ease_factor,
        review_after = new_review_after,
        seq = CASE WHEN response.spacing = 0 THEN
        (
            SELECT
                coalesce(max(seq), 0) + 1
            FROM
                learn.card
            WHERE
                review_after < now()
                AND archived = FALSE
        )
        ELSE
            0
        END
    WHERE
        id = card_id
    RETURNING
        * INTO card;
    INSERT INTO learn.response (score, review_after, spacing, ease_factor, card_id, person_id)
        VALUES (score, new_review_after, response.spacing, response.ease_factor, card_id, card.person_id);
    RETURN card;
END;
$$;


--
-- Name: person; Type: TABLE; Schema: learn; Owner: -
--

CREATE TABLE learn.person (
    id integer NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: TABLE person; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON TABLE learn.person IS 'A user of the flashcard app.';


--
-- Name: COLUMN person.id; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.person.id IS 'The primary unique identifier for the person.';


--
-- Name: COLUMN person.first_name; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.person.first_name IS 'The persons first name.';


--
-- Name: COLUMN person.last_name; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.person.last_name IS 'The persons last name.';


--
-- Name: COLUMN person.created_at; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.person.created_at IS 'The time this person was created.';


--
-- Name: register_person(text, text, text, text); Type: FUNCTION; Schema: learn; Owner: -
--

CREATE FUNCTION learn.register_person(first_name text, last_name text, email text, password text) RETURNS learn.person
    LANGUAGE plpgsql STRICT SECURITY DEFINER
    AS $$
DECLARE
    person learn.person;
BEGIN
    INSERT INTO learn.person (first_name, last_name)
        VALUES (first_name, last_name)
    RETURNING * INTO person;
    INSERT INTO learn_private.person_account(person_id, email, password_hash)
        VALUES (person.id, email, crypt(password, gen_salt('bf')));
    RETURN person;
END;
$$;


--
-- Name: score_response(integer, integer, numeric); Type: FUNCTION; Schema: learn; Owner: -
--

CREATE FUNCTION learn.score_response(score integer, spacing integer, ease_factor numeric) RETURNS learn.score_response
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    AS $$
DECLARE
    new_ease_factor numeric (7, 4);
    new_days integer;
BEGIN
    IF score IS NOT NULL OR score < 0 OR score > 3 THEN
        score = 0;
    END IF;
    IF score = 0 THEN
        new_ease_factor = ease_factor;
        new_days = 0;
    ELSE
        IF spacing = 0 THEN
            new_days = 1;
            new_ease_factor = 2.5;
        ELSIF spacing = 1 THEN
            new_days = 3;
            new_ease_factor = ease_factor;
        ELSE
            new_ease_factor = ease_factor + (0.1 - (4 - score) * (0.08 + (4 - score) * 0.0200));
            IF new_ease_factor < 1.3 THEN
                new_ease_factor = 1.3;
            END IF;
            new_days = spacing * new_ease_factor;
        END IF;
    END IF;
    RETURN (new_ease_factor,
        new_days)::learn.score_response;
END;
$$;


--
-- Name: set_person_id(); Type: FUNCTION; Schema: learn_private; Owner: -
--

CREATE FUNCTION learn_private.set_person_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.person_id := current_setting('jwt.claims.person_id');
    RETURN new;
END
$$;


--
-- Name: notify_watchers_ddl(); Type: FUNCTION; Schema: postgraphile_watch; Owner: -
--

CREATE FUNCTION postgraphile_watch.notify_watchers_ddl() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
begin
  perform pg_notify(
    'postgraphile_watch',
    json_build_object(
      'type',
      'ddl',
      'payload',
      (select json_agg(json_build_object('schema', schema_name, 'command', command_tag)) from pg_event_trigger_ddl_commands() as x)
    )::text
  );
end;
$$;


--
-- Name: notify_watchers_drop(); Type: FUNCTION; Schema: postgraphile_watch; Owner: -
--

CREATE FUNCTION postgraphile_watch.notify_watchers_drop() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
begin
  perform pg_notify(
    'postgraphile_watch',
    json_build_object(
      'type',
      'drop',
      'payload',
      (select json_agg(distinct x.schema_name) from pg_event_trigger_dropped_objects() as x)
    )::text
  );
end;
$$;


--
-- Name: card_id_seq; Type: SEQUENCE; Schema: learn; Owner: -
--

CREATE SEQUENCE learn.card_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: card_id_seq; Type: SEQUENCE OWNED BY; Schema: learn; Owner: -
--

ALTER SEQUENCE learn.card_id_seq OWNED BY learn.card.id;


--
-- Name: next_card; Type: VIEW; Schema: learn; Owner: -
--

CREATE VIEW learn.next_card AS
 SELECT card.id,
    card.question,
    card.answer,
    card.review_after,
    card.spacing,
    card.ease_factor,
    card.seq,
    card.archived,
    card.person_id,
    card.create_at
   FROM learn.card
  WHERE (card.review_after <= now())
  ORDER BY card.seq, card.review_after, card.id;


--
-- Name: person_id_seq; Type: SEQUENCE; Schema: learn; Owner: -
--

CREATE SEQUENCE learn.person_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: person_id_seq; Type: SEQUENCE OWNED BY; Schema: learn; Owner: -
--

ALTER SEQUENCE learn.person_id_seq OWNED BY learn.person.id;


--
-- Name: response; Type: TABLE; Schema: learn; Owner: -
--

CREATE TABLE learn.response (
    id integer NOT NULL,
    score integer NOT NULL,
    review_after timestamp with time zone NOT NULL,
    spacing integer NOT NULL,
    ease_factor numeric(7,4) NOT NULL,
    card_id integer NOT NULL,
    person_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT response_ease_factor_check CHECK ((ease_factor >= 1.3)),
    CONSTRAINT response_score_check CHECK (((score >= 0) AND (score <= 3))),
    CONSTRAINT response_spacing_check CHECK ((spacing >= 0))
);


--
-- Name: TABLE response; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON TABLE learn.response IS '@omit create,update,delete
An individual graded response to a flash card';


--
-- Name: COLUMN response.id; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.response.id IS 'The primary unique identifier for the flash card response';


--
-- Name: COLUMN response.score; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.response.score IS 'An value indicating how wll the answer was remembered.';


--
-- Name: COLUMN response.review_after; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.response.review_after IS 'The calculated next review time';


--
-- Name: COLUMN response.spacing; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.response.spacing IS 'The number of days until next review';


--
-- Name: COLUMN response.ease_factor; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.response.ease_factor IS 'A factor indicating how easy/hard the card is';


--
-- Name: COLUMN response.card_id; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.response.card_id IS 'The card that this response is for';


--
-- Name: COLUMN response.person_id; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.response.person_id IS 'The user who made the response';


--
-- Name: COLUMN response.created_at; Type: COMMENT; Schema: learn; Owner: -
--

COMMENT ON COLUMN learn.response.created_at IS 'Thi time this response was created';


--
-- Name: response_id_seq; Type: SEQUENCE; Schema: learn; Owner: -
--

CREATE SEQUENCE learn.response_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: response_id_seq; Type: SEQUENCE OWNED BY; Schema: learn; Owner: -
--

ALTER SEQUENCE learn.response_id_seq OWNED BY learn.response.id;


--
-- Name: person_account; Type: TABLE; Schema: learn_private; Owner: -
--

CREATE TABLE learn_private.person_account (
    person_id integer NOT NULL,
    email text NOT NULL,
    password_hash text NOT NULL,
    CONSTRAINT person_account_email_check CHECK ((email ~* '^.+@.+\..+$'::text))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: card id; Type: DEFAULT; Schema: learn; Owner: -
--

ALTER TABLE ONLY learn.card ALTER COLUMN id SET DEFAULT nextval('learn.card_id_seq'::regclass);


--
-- Name: person id; Type: DEFAULT; Schema: learn; Owner: -
--

ALTER TABLE ONLY learn.person ALTER COLUMN id SET DEFAULT nextval('learn.person_id_seq'::regclass);


--
-- Name: response id; Type: DEFAULT; Schema: learn; Owner: -
--

ALTER TABLE ONLY learn.response ALTER COLUMN id SET DEFAULT nextval('learn.response_id_seq'::regclass);


--
-- Name: card card_pkey; Type: CONSTRAINT; Schema: learn; Owner: -
--

ALTER TABLE ONLY learn.card
    ADD CONSTRAINT card_pkey PRIMARY KEY (id);


--
-- Name: person person_pkey; Type: CONSTRAINT; Schema: learn; Owner: -
--

ALTER TABLE ONLY learn.person
    ADD CONSTRAINT person_pkey PRIMARY KEY (id);


--
-- Name: response response_pkey; Type: CONSTRAINT; Schema: learn; Owner: -
--

ALTER TABLE ONLY learn.response
    ADD CONSTRAINT response_pkey PRIMARY KEY (id);


--
-- Name: person_account person_account_email_key; Type: CONSTRAINT; Schema: learn_private; Owner: -
--

ALTER TABLE ONLY learn_private.person_account
    ADD CONSTRAINT person_account_email_key UNIQUE (email);


--
-- Name: person_account person_account_pkey; Type: CONSTRAINT; Schema: learn_private; Owner: -
--

ALTER TABLE ONLY learn_private.person_account
    ADD CONSTRAINT person_account_pkey PRIMARY KEY (person_id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: card_archived_idx; Type: INDEX; Schema: learn; Owner: -
--

CREATE INDEX card_archived_idx ON learn.card USING btree (archived);


--
-- Name: card_person_id_idx; Type: INDEX; Schema: learn; Owner: -
--

CREATE INDEX card_person_id_idx ON learn.card USING btree (person_id);


--
-- Name: card_review_after_idx; Type: INDEX; Schema: learn; Owner: -
--

CREATE INDEX card_review_after_idx ON learn.card USING btree (review_after);


--
-- Name: response_card_id_idx; Type: INDEX; Schema: learn; Owner: -
--

CREATE INDEX response_card_id_idx ON learn.response USING btree (card_id);


--
-- Name: response_person_id_idx; Type: INDEX; Schema: learn; Owner: -
--

CREATE INDEX response_person_id_idx ON learn.response USING btree (person_id);


--
-- Name: person_account_email_idx; Type: INDEX; Schema: learn_private; Owner: -
--

CREATE INDEX person_account_email_idx ON learn_private.person_account USING btree (email);


--
-- Name: card card_person_id; Type: TRIGGER; Schema: learn; Owner: -
--

CREATE TRIGGER card_person_id BEFORE INSERT ON learn.card FOR EACH ROW EXECUTE FUNCTION learn_private.set_person_id();


--
-- Name: card card_person_id_fkey; Type: FK CONSTRAINT; Schema: learn; Owner: -
--

ALTER TABLE ONLY learn.card
    ADD CONSTRAINT card_person_id_fkey FOREIGN KEY (person_id) REFERENCES learn.person(id);


--
-- Name: response response_card_id_fkey; Type: FK CONSTRAINT; Schema: learn; Owner: -
--

ALTER TABLE ONLY learn.response
    ADD CONSTRAINT response_card_id_fkey FOREIGN KEY (card_id) REFERENCES learn.card(id);


--
-- Name: response response_person_id_fkey; Type: FK CONSTRAINT; Schema: learn; Owner: -
--

ALTER TABLE ONLY learn.response
    ADD CONSTRAINT response_person_id_fkey FOREIGN KEY (person_id) REFERENCES learn.person(id);


--
-- Name: person_account person_account_person_id_fkey; Type: FK CONSTRAINT; Schema: learn_private; Owner: -
--

ALTER TABLE ONLY learn_private.person_account
    ADD CONSTRAINT person_account_person_id_fkey FOREIGN KEY (person_id) REFERENCES learn.person(id) ON DELETE CASCADE;


--
-- Name: card; Type: ROW SECURITY; Schema: learn; Owner: -
--

ALTER TABLE learn.card ENABLE ROW LEVEL SECURITY;

--
-- Name: card delete_card; Type: POLICY; Schema: learn; Owner: -
--

CREATE POLICY delete_card ON learn.card FOR DELETE TO learn_person USING ((person_id = (NULLIF(current_setting('jwt.claims.person_id'::text, true), ''::text))::integer));


--
-- Name: card insert_card; Type: POLICY; Schema: learn; Owner: -
--

CREATE POLICY insert_card ON learn.card FOR INSERT TO learn_person WITH CHECK ((person_id = (NULLIF(current_setting('jwt.claims.person_id'::text, true), ''::text))::integer));


--
-- Name: card select_card; Type: POLICY; Schema: learn; Owner: -
--

CREATE POLICY select_card ON learn.card FOR SELECT TO learn_person USING ((person_id = (NULLIF(current_setting('jwt.claims.person_id'::text, true), ''::text))::integer));


--
-- Name: card update_card; Type: POLICY; Schema: learn; Owner: -
--

CREATE POLICY update_card ON learn.card FOR UPDATE TO learn_person USING ((person_id = (NULLIF(current_setting('jwt.claims.person_id'::text, true), ''::text))::integer));


--
-- Name: postgraphile_watch_ddl; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER postgraphile_watch_ddl ON ddl_command_end
         WHEN TAG IN ('ALTER AGGREGATE', 'ALTER DOMAIN', 'ALTER EXTENSION', 'ALTER FOREIGN TABLE', 'ALTER FUNCTION', 'ALTER POLICY', 'ALTER SCHEMA', 'ALTER TABLE', 'ALTER TYPE', 'ALTER VIEW', 'COMMENT', 'CREATE AGGREGATE', 'CREATE DOMAIN', 'CREATE EXTENSION', 'CREATE FOREIGN TABLE', 'CREATE FUNCTION', 'CREATE INDEX', 'CREATE POLICY', 'CREATE RULE', 'CREATE SCHEMA', 'CREATE TABLE', 'CREATE TABLE AS', 'CREATE VIEW', 'DROP AGGREGATE', 'DROP DOMAIN', 'DROP EXTENSION', 'DROP FOREIGN TABLE', 'DROP FUNCTION', 'DROP INDEX', 'DROP OWNED', 'DROP POLICY', 'DROP RULE', 'DROP SCHEMA', 'DROP TABLE', 'DROP TYPE', 'DROP VIEW', 'GRANT', 'REVOKE', 'SELECT INTO')
   EXECUTE FUNCTION postgraphile_watch.notify_watchers_ddl();


--
-- Name: postgraphile_watch_drop; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER postgraphile_watch_drop ON sql_drop
   EXECUTE FUNCTION postgraphile_watch.notify_watchers_drop();


--
-- PostgreSQL database dump complete
--


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20210916185045'),
    ('20210916192550'),
    ('20210916200355'),
    ('20210916201547'),
    ('20210916204618'),
    ('20210916205730'),
    ('20210916212551'),
    ('20210916222129'),
    ('20210916222939'),
    ('20210916223639'),
    ('20210916224940'),
    ('20210916225101'),
    ('20210917121559'),
    ('20210917123258'),
    ('20210917123620'),
    ('20210917124314'),
    ('20210917130922'),
    ('20210917154942');
