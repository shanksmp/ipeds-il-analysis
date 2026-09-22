--
-- PostgreSQL database dump
--

\restrict Q0edQvfHnN0M9XavgPvnjyiHBhVQthvpIhJTDlXbwJFpWByxaUYgpXnaZdfkMfb

-- Dumped from database version 17.11 (Homebrew)
-- Dumped by pg_dump version 17.11 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: completions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.completions (
    id integer NOT NULL,
    unitid integer NOT NULL,
    year integer NOT NULL,
    cipcode_6digit integer,
    award_level numeric,
    majornum numeric,
    race integer,
    sex integer,
    awards_6digit numeric
);


--
-- Name: completions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.completions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: completions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.completions_id_seq OWNED BY public.completions.id;


--
-- Name: enrollment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enrollment (
    id integer NOT NULL,
    unitid integer NOT NULL,
    year integer NOT NULL,
    ftpt integer,
    level_of_study integer,
    degree_seeking integer,
    class_level integer,
    sex integer,
    race integer,
    enrollment_fall numeric
);


--
-- Name: enrollment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.enrollment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enrollment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.enrollment_id_seq OWNED BY public.enrollment.id;


--
-- Name: institutions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.institutions (
    unitid integer NOT NULL,
    year integer NOT NULL,
    inst_name text,
    city text,
    state_abbr text,
    zip text,
    county_name text,
    sector integer,
    longitude numeric,
    latitude numeric,
    currently_active_ipeds integer
);


--
-- Name: completions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.completions ALTER COLUMN id SET DEFAULT nextval('public.completions_id_seq'::regclass);


--
-- Name: enrollment id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment ALTER COLUMN id SET DEFAULT nextval('public.enrollment_id_seq'::regclass);


--
-- Name: completions completions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.completions
    ADD CONSTRAINT completions_pkey PRIMARY KEY (id);


--
-- Name: enrollment enrollment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollment
    ADD CONSTRAINT enrollment_pkey PRIMARY KEY (id);


--
-- Name: institutions institutions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institutions
    ADD CONSTRAINT institutions_pkey PRIMARY KEY (unitid, year);


--
-- Name: idx_completions_unitid_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_completions_unitid_year ON public.completions USING btree (unitid, year);


--
-- Name: idx_enrollment_unitid_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enrollment_unitid_year ON public.enrollment USING btree (unitid, year);


--
-- PostgreSQL database dump complete
--

\unrestrict Q0edQvfHnN0M9XavgPvnjyiHBhVQthvpIhJTDlXbwJFpWByxaUYgpXnaZdfkMfb

