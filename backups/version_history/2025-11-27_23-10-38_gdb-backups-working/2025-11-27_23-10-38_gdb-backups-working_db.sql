--
-- PostgreSQL database dump
--

\restrict o499dbc7G4lAtughocdxFqRlLBXQZ7kpofAWOnmyf9CkHf1SqL6dFnWHICeWG5s

-- Dumped from database version 15.14 (Debian 15.14-1.pgdg13+1)
-- Dumped by pg_dump version 15.14 (Debian 15.14-0+deb12u1)

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
-- Name: countries_iso2_guard(); Type: FUNCTION; Schema: public; Owner: app
--

CREATE FUNCTION public.countries_iso2_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
BEGIN
  IF NEW.iso2 IS NULL OR length(NEW.iso2) <> 2 OR NEW.iso2 !~ '^[A-Za-z]{2}$' THEN
    NEW.iso2 := 'ZZ';
  END IF;
  NEW.iso2 := upper(NEW.iso2);
  RETURN NEW;
END;
$_$;


ALTER FUNCTION public.countries_iso2_guard() OWNER TO app;

--
-- Name: countries_view_del(); Type: FUNCTION; Schema: public; Owner: app
--

CREATE FUNCTION public.countries_view_del() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      DELETE FROM countries_base WHERE id = OLD.id;
      RETURN OLD;
    END;
    $$;


ALTER FUNCTION public.countries_view_del() OWNER TO app;

--
-- Name: countries_view_ins(); Type: FUNCTION; Schema: public; Owner: app
--

CREATE FUNCTION public.countries_view_ins() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE r countries_base%ROWTYPE;
    BEGIN
      INSERT INTO countries_base(name, iso2, created_at, updated_at)
      VALUES (COALESCE(NEW.name,'International'), NEW.iso2,
              COALESCE(NEW.created_at, now()), COALESCE(NEW.updated_at, now()))
      ON CONFLICT (iso2) DO UPDATE
        SET name = CASE WHEN countries_base.iso2='ZZ'
                        THEN countries_base.name
                        ELSE EXCLUDED.name END,
            updated_at = now()
      RETURNING * INTO r;
      RETURN r;
    END;
    $$;


ALTER FUNCTION public.countries_view_ins() OWNER TO app;

--
-- Name: countries_view_upd(); Type: FUNCTION; Schema: public; Owner: app
--

CREATE FUNCTION public.countries_view_upd() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE r countries_base%ROWTYPE;
    BEGIN
      UPDATE countries_base
         SET name = NEW.name,
             iso2 = NEW.iso2,
             updated_at = now()
       WHERE id = OLD.id
      RETURNING * INTO r;
      RETURN r;
    END;
    $$;


ALTER FUNCTION public.countries_view_upd() OWNER TO app;

--
-- Name: countries_view_upsert_ins(); Type: FUNCTION; Schema: public; Owner: app
--

CREATE FUNCTION public.countries_view_upsert_ins() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE r countries_base%ROWTYPE;
BEGIN
  INSERT INTO countries_base(name, iso2, created_at, updated_at)
  VALUES (
    COALESCE(NEW.name,'International'),
    NEW.iso2,
    COALESCE(NEW.created_at, now()),
    COALESCE(NEW.updated_at, now())
  )
  ON CONFLICT (iso2) DO UPDATE
    SET name = EXCLUDED.name,
        updated_at = now()
  RETURNING * INTO r;

  NEW.id := r.id; NEW.name := r.name; NEW.iso2 := r.iso2;
  NEW.created_at := r.created_at; NEW.updated_at := r.updated_at;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.countries_view_upsert_ins() OWNER TO app;

--
-- Name: countries_view_upsert_upd(); Type: FUNCTION; Schema: public; Owner: app
--

CREATE FUNCTION public.countries_view_upsert_upd() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE r countries_base%ROWTYPE;
BEGIN
  INSERT INTO countries_base(name, iso2, created_at, updated_at)
  VALUES (
    COALESCE(NEW.name,'International'),
    NEW.iso2,
    COALESCE(OLD.created_at, now()),
    now()
  )
  ON CONFLICT (iso2) DO UPDATE
    SET name = EXCLUDED.name,
        updated_at = now()
  RETURNING * INTO r;

  NEW.id := r.id; NEW.name := r.name; NEW.iso2 := r.iso2;
  NEW.created_at := r.created_at; NEW.updated_at := r.updated_at;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.countries_view_upsert_upd() OWNER TO app;

--
-- Name: networks_name_normalize(); Type: FUNCTION; Schema: public; Owner: app
--

CREATE FUNCTION public.networks_name_normalize() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.name IS NULL THEN NEW.name := ''; END IF;
  NEW.name := upper(regexp_replace(btrim(NEW.name), '\s+', ' ', 'g'));
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.networks_name_normalize() OWNER TO app;

--
-- Name: networks_name_normalize_base(); Type: FUNCTION; Schema: public; Owner: app
--

CREATE FUNCTION public.networks_name_normalize_base() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.name IS NULL THEN NEW.name := ''; END IF;
  NEW.name := regexp_replace(btrim(NEW.name), '\s+', ' ', 'g');
  NEW.lower_name := lower(NEW.name);
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.networks_name_normalize_base() OWNER TO app;

--
-- Name: networks_view_upsert_ins(); Type: FUNCTION; Schema: public; Owner: app
--

CREATE FUNCTION public.networks_view_upsert_ins() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE r networks_base%ROWTYPE;
BEGIN
  -- Normalize here as well (view-side) so ON CONFLICT hits correct key;
  -- base trigger also runs, so we're consistent.
  NEW.name := regexp_replace(btrim(COALESCE(NEW.name,'')), '\s+', ' ', 'g');
  NEW.lower_name := lower(NEW.name);

  INSERT INTO networks_base(country_id, name, lower_name, created_at, updated_at)
  VALUES (NEW.country_id, NEW.name, NEW.lower_name, COALESCE(NEW.created_at, now()), COALESCE(NEW.updated_at, now()))
  ON CONFLICT ON CONSTRAINT networks_country_lowername_unique DO UPDATE
    SET name = EXCLUDED.name,
        updated_at = now()
  RETURNING * INTO r;

  NEW.id := r.id; NEW.created_at := r.created_at; NEW.updated_at := r.updated_at;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.networks_view_upsert_ins() OWNER TO app;

--
-- Name: networks_view_upsert_upd(); Type: FUNCTION; Schema: public; Owner: app
--

CREATE FUNCTION public.networks_view_upsert_upd() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE r networks_base%ROWTYPE;
BEGIN
  NEW.name := regexp_replace(btrim(COALESCE(NEW.name,'')), '\s+', ' ', 'g');
  NEW.lower_name := lower(NEW.name);

  INSERT INTO networks_base(country_id, name, lower_name, created_at, updated_at)
  VALUES (NEW.country_id, NEW.name, NEW.lower_name, COALESCE(OLD.created_at, now()), now())
  ON CONFLICT ON CONSTRAINT networks_country_lowername_unique DO UPDATE
    SET name = EXCLUDED.name,
        updated_at = now()
  RETURNING * INTO r;

  NEW.id := r.id; NEW.created_at := r.created_at; NEW.updated_at := r.updated_at;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.networks_view_upsert_upd() OWNER TO app;

--
-- Name: normalize_network_mncs(); Type: FUNCTION; Schema: public; Owner: app
--

CREATE FUNCTION public.normalize_network_mncs() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_mcc   text;
    v_mnc   text;
    v_raw   text;
    v_norm  text;
    v_len   int;
BEGIN
    IF NEW.mcc IS NULL OR NEW.mnc IS NULL THEN
        RETURN NEW;
    END IF;

    -- Strip to digits
    v_mcc := regexp_replace(COALESCE(NEW.mcc::text, ''), '\D', '', 'g');
    v_mnc := regexp_replace(COALESCE(NEW.mnc::text, ''), '\D', '', 'g');

    IF v_mcc = '' OR v_mnc = '' THEN
        RETURN NEW;
    END IF;

    -- Build raw MCCMNC as 6 digits: MCC(3) + MNC(3)
    v_raw := lpad(v_mcc, 3, '0') || lpad(v_mnc, 3, '0');

    -- Keep only digits, max 6 chars
    v_norm := regexp_replace(v_raw, '\D', '', 'g');
    v_len  := length(v_norm);

    IF v_len > 6 THEN
        v_norm := substring(v_norm from 1 for 6);
        v_len  := 6;
    END IF;

    -- If 6 digits and 4th digit is '0', drop that '0' => 5-digit composite
    IF v_len = 6 AND substring(v_norm from 4 for 1) = '0' THEN
        v_norm := substring(v_norm from 1 for 3) || substring(v_norm from 5);
        v_len  := 5;
    END IF;

    -- If we ended up with fewer than 5 digits, just store what we have in mcc_mnc
    IF v_len < 5 THEN
        NEW.mcc_mnc := v_norm;
        RETURN NEW;
    END IF;

    -- MCC is always first 3
    NEW.mcc := substring(v_norm from 1 for 3)::integer;

    -- For 5-digit: MCC(3) + MNC(2)
    -- For 6-digit: MCC(3) + MNC(3)
    IF v_len = 5 THEN
        NEW.mnc := substring(v_norm from 4 for 2)::integer;
    ELSE
        NEW.mnc := substring(v_norm from 4)::integer;
    END IF;

    NEW.mcc_mnc := v_norm;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.normalize_network_mncs() OWNER TO app;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: auth_logs; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.auth_logs (
    id bigint NOT NULL,
    user_id bigint,
    event character varying(20) NOT NULL,
    ip character varying(64),
    user_agent text,
    created_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.auth_logs OWNER TO app;

--
-- Name: auth_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.auth_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_logs_id_seq OWNER TO app;

--
-- Name: auth_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.auth_logs_id_seq OWNED BY public.auth_logs.id;


--
-- Name: cache; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.cache (
    key character varying(255) NOT NULL,
    value text NOT NULL,
    expiration integer NOT NULL
);


ALTER TABLE public.cache OWNER TO app;

--
-- Name: cache_locks; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.cache_locks (
    key character varying(255) NOT NULL,
    owner character varying(255) NOT NULL,
    expiration integer NOT NULL
);


ALTER TABLE public.cache_locks OWNER TO app;

--
-- Name: charge_models; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.charge_models (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.charge_models OWNER TO app;

--
-- Name: charge_models_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.charge_models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.charge_models_id_seq OWNER TO app;

--
-- Name: charge_models_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.charge_models_id_seq OWNED BY public.charge_models.id;


--
-- Name: countries_base; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.countries_base (
    id bigint NOT NULL,
    name character varying(120) NOT NULL,
    iso2 character varying(3),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    CONSTRAINT countries_iso2_check CHECK (((iso2)::text ~ '^[A-Z]{2}$'::text))
);


ALTER TABLE public.countries_base OWNER TO app;

--
-- Name: countries; Type: VIEW; Schema: public; Owner: app
--

CREATE VIEW public.countries AS
 SELECT countries_base.id,
    countries_base.name,
    countries_base.iso2,
    countries_base.created_at,
    countries_base.updated_at
   FROM public.countries_base;


ALTER TABLE public.countries OWNER TO app;

--
-- Name: countries_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.countries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.countries_id_seq OWNER TO app;

--
-- Name: countries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.countries_id_seq OWNED BY public.countries_base.id;


--
-- Name: country_mccs; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.country_mccs (
    id bigint NOT NULL,
    country_id bigint NOT NULL,
    mcc character varying(3) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    marked_for_deletion boolean DEFAULT false NOT NULL,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    created_by_source character varying(64),
    updated_by_source character varying(64)
);


ALTER TABLE public.country_mccs OWNER TO app;

--
-- Name: country_mccs_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.country_mccs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.country_mccs_id_seq OWNER TO app;

--
-- Name: country_mccs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.country_mccs_id_seq OWNED BY public.country_mccs.id;


--
-- Name: country_meta; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.country_meta (
    id bigint NOT NULL,
    country_id bigint NOT NULL,
    notes text,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.country_meta OWNER TO app;

--
-- Name: country_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.country_meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.country_meta_id_seq OWNER TO app;

--
-- Name: country_meta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.country_meta_id_seq OWNED BY public.country_meta.id;


--
-- Name: dropdown_items; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.dropdown_items (
    id bigint NOT NULL,
    dropdown_menu_id bigint NOT NULL,
    label character varying(255) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    "position" integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.dropdown_items OWNER TO app;

--
-- Name: dropdown_items_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.dropdown_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dropdown_items_id_seq OWNER TO app;

--
-- Name: dropdown_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.dropdown_items_id_seq OWNED BY public.dropdown_items.id;


--
-- Name: dropdown_menus; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.dropdown_menus (
    id bigint NOT NULL,
    title character varying(120) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.dropdown_menus OWNER TO app;

--
-- Name: dropdown_menus_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.dropdown_menus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dropdown_menus_id_seq OWNER TO app;

--
-- Name: dropdown_menus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.dropdown_menus_id_seq OWNED BY public.dropdown_menus.id;


--
-- Name: failed_jobs; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.failed_jobs (
    id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    connection text NOT NULL,
    queue text NOT NULL,
    payload text NOT NULL,
    exception text NOT NULL,
    failed_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.failed_jobs OWNER TO app;

--
-- Name: failed_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.failed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.failed_jobs_id_seq OWNER TO app;

--
-- Name: failed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.failed_jobs_id_seq OWNED BY public.failed_jobs.id;


--
-- Name: imap_settings; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.imap_settings (
    id bigint NOT NULL,
    host character varying(255),
    port integer,
    encryption character varying(255) DEFAULT 'ssl'::character varying NOT NULL,
    username character varying(255),
    password character varying(255),
    enabled boolean DEFAULT false NOT NULL,
    poll_minutes integer DEFAULT 5 NOT NULL,
    selected_folders json,
    last_folders_cache json,
    last_test_log text,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    last_run_at timestamp(0) without time zone,
    CONSTRAINT imap_settings_encryption_check CHECK (((encryption)::text = ANY ((ARRAY['none'::character varying, 'ssl'::character varying, 'tls'::character varying])::text[])))
);


ALTER TABLE public.imap_settings OWNER TO app;

--
-- Name: imap_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.imap_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.imap_settings_id_seq OWNER TO app;

--
-- Name: imap_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.imap_settings_id_seq OWNED BY public.imap_settings.id;


--
-- Name: job_batches; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.job_batches (
    id character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    total_jobs integer NOT NULL,
    pending_jobs integer NOT NULL,
    failed_jobs integer NOT NULL,
    failed_job_ids text NOT NULL,
    options text,
    cancelled_at integer,
    created_at integer NOT NULL,
    finished_at integer
);


ALTER TABLE public.job_batches OWNER TO app;

--
-- Name: jobs; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.jobs (
    id bigint NOT NULL,
    queue character varying(255) NOT NULL,
    payload text NOT NULL,
    attempts smallint NOT NULL,
    reserved_at integer,
    available_at integer NOT NULL,
    created_at integer NOT NULL
);


ALTER TABLE public.jobs OWNER TO app;

--
-- Name: jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.jobs_id_seq OWNER TO app;

--
-- Name: jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.jobs_id_seq OWNED BY public.jobs.id;


--
-- Name: known_hops; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.known_hops (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.known_hops OWNER TO app;

--
-- Name: known_hops_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.known_hops_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.known_hops_id_seq OWNER TO app;

--
-- Name: known_hops_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.known_hops_id_seq OWNED BY public.known_hops.id;


--
-- Name: migrations; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    migration character varying(255) NOT NULL,
    batch integer NOT NULL
);


ALTER TABLE public.migrations OWNER TO app;

--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.migrations_id_seq OWNER TO app;

--
-- Name: migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.migrations_id_seq OWNED BY public.migrations.id;


--
-- Name: network_meta; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.network_meta (
    id bigint NOT NULL,
    network_id bigint NOT NULL,
    non_operational boolean DEFAULT false NOT NULL,
    notes text,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.network_meta OWNER TO app;

--
-- Name: network_meta_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.network_meta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.network_meta_id_seq OWNER TO app;

--
-- Name: network_meta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.network_meta_id_seq OWNED BY public.network_meta.id;


--
-- Name: network_mncs; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.network_mncs (
    id bigint NOT NULL,
    network_id bigint NOT NULL,
    mcc character varying(6) NOT NULL,
    mnc character varying(6) NOT NULL,
    mcc_mnc character varying(12) NOT NULL,
    marked_for_deletion boolean DEFAULT false NOT NULL,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    created_by_source character varying(255),
    updated_by_source character varying(255),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    created_by_user character varying(100),
    updated_by_user character varying(100)
);


ALTER TABLE public.network_mncs OWNER TO app;

--
-- Name: network_mncs_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.network_mncs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.network_mncs_id_seq OWNER TO app;

--
-- Name: network_mncs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.network_mncs_id_seq OWNED BY public.network_mncs.id;


--
-- Name: networks_base; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.networks_base (
    id bigint NOT NULL,
    name character varying(160) NOT NULL,
    mcc character varying(3),
    mnc character varying(3),
    mcc_mnc character varying(6),
    country_id bigint,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    created_by_user_id bigint,
    updated_by_user_id bigint,
    created_by_source character varying(255),
    updated_by_source character varying(255),
    marked_for_deletion boolean DEFAULT false NOT NULL,
    lower_name character varying(255)
);


ALTER TABLE public.networks_base OWNER TO app;

--
-- Name: networks; Type: VIEW; Schema: public; Owner: app
--

CREATE VIEW public.networks AS
 SELECT networks_base.id,
    networks_base.country_id,
    networks_base.name,
    networks_base.lower_name,
    networks_base.created_at,
    networks_base.updated_at
   FROM public.networks_base;


ALTER TABLE public.networks OWNER TO app;

--
-- Name: networks_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.networks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.networks_id_seq OWNER TO app;

--
-- Name: networks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.networks_id_seq OWNED BY public.networks_base.id;


--
-- Name: password_reset_tokens; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.password_reset_tokens (
    email character varying(255) NOT NULL,
    token character varying(255) NOT NULL,
    created_at timestamp(0) without time zone
);


ALTER TABLE public.password_reset_tokens OWNER TO app;

--
-- Name: route_types; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.route_types (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.route_types OWNER TO app;

--
-- Name: route_types_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.route_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.route_types_id_seq OWNER TO app;

--
-- Name: route_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.route_types_id_seq OWNED BY public.route_types.id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.sessions (
    id character varying(255) NOT NULL,
    user_id bigint,
    ip_address character varying(45),
    user_agent text,
    payload text NOT NULL,
    last_activity integer NOT NULL
);


ALTER TABLE public.sessions OWNER TO app;

--
-- Name: supplier_connections; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.supplier_connections (
    id bigint NOT NULL,
    supplier_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    username character varying(255),
    charge_type character varying(32) NOT NULL,
    notes text,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    product_type character varying(255),
    connection_dead boolean DEFAULT false NOT NULL
);


ALTER TABLE public.supplier_connections OWNER TO app;

--
-- Name: supplier_connections_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.supplier_connections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.supplier_connections_id_seq OWNER TO app;

--
-- Name: supplier_connections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.supplier_connections_id_seq OWNED BY public.supplier_connections.id;


--
-- Name: supplier_offer_histories; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.supplier_offer_histories (
    id bigint NOT NULL,
    supplier_offer_id bigint NOT NULL,
    supplier_id bigint,
    supplier_connection_id bigint,
    country_id bigint,
    network_id bigint,
    network_mnc_id bigint,
    price numeric(15,6),
    mcc character varying(8),
    mnc character varying(8),
    mcc_mnc character varying(16),
    product_type character varying(100),
    known_hops character varying(255),
    sender_id_supported character varying(255),
    charge_type character varying(100),
    is_exclusive boolean DEFAULT false NOT NULL,
    route_type character varying(100),
    effective_date date,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.supplier_offer_histories OWNER TO app;

--
-- Name: supplier_offer_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.supplier_offer_histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.supplier_offer_histories_id_seq OWNER TO app;

--
-- Name: supplier_offer_histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.supplier_offer_histories_id_seq OWNED BY public.supplier_offer_histories.id;


--
-- Name: supplier_offer_history; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.supplier_offer_history (
    id bigint NOT NULL,
    supplier_offer_id bigint,
    country_id bigint,
    network_id bigint,
    network_mnc_id bigint,
    supplier_id bigint,
    supplier_connection_id bigint,
    price numeric(12,6) NOT NULL,
    mcc character varying(3),
    mnc character varying(3),
    mcc_mnc character varying(6),
    product_type_id bigint,
    known_hops_dropdown_item_id bigint,
    sender_id_supported_dropdown_item_id bigint,
    route_type_id bigint,
    charge_model_id bigint,
    charge_type character varying(32),
    is_exclusive boolean DEFAULT false NOT NULL,
    effective_date date,
    recorded_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    product_type character varying(64)
);


ALTER TABLE public.supplier_offer_history OWNER TO app;

--
-- Name: supplier_offer_history_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.supplier_offer_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.supplier_offer_history_id_seq OWNER TO app;

--
-- Name: supplier_offer_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.supplier_offer_history_id_seq OWNED BY public.supplier_offer_history.id;


--
-- Name: supplier_offers; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.supplier_offers (
    id bigint NOT NULL,
    country_id bigint,
    network_id bigint,
    network_mnc_id bigint,
    supplier_id bigint,
    supplier_connection_id bigint,
    price numeric(12,6) NOT NULL,
    mcc character varying(3),
    mnc character varying(3),
    mcc_mnc character varying(6),
    product_type_id bigint,
    known_hops_dropdown_item_id bigint,
    sender_id_supported_dropdown_item_id bigint,
    route_type_id bigint,
    charge_model_id bigint,
    charge_type character varying(32),
    is_exclusive boolean DEFAULT false NOT NULL,
    effective_date date,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    product_type character varying(64),
    known_hops character varying(255),
    sender_id_supported character varying(255),
    updated_by bigint
);


ALTER TABLE public.supplier_offers OWNER TO app;

--
-- Name: supplier_offers_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.supplier_offers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.supplier_offers_id_seq OWNER TO app;

--
-- Name: supplier_offers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.supplier_offers_id_seq OWNED BY public.supplier_offers.id;


--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.suppliers (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255),
    notes text,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.suppliers OWNER TO app;

--
-- Name: suppliers_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.suppliers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.suppliers_id_seq OWNER TO app;

--
-- Name: suppliers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.suppliers_id_seq OWNED BY public.suppliers.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: app
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    email_verified_at timestamp(0) without time zone,
    password character varying(255) NOT NULL,
    remember_token character varying(100),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    is_admin boolean DEFAULT false NOT NULL,
    role character varying(255) DEFAULT 'standard'::character varying NOT NULL
);


ALTER TABLE public.users OWNER TO app;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: app
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO app;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: app
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: auth_logs id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.auth_logs ALTER COLUMN id SET DEFAULT nextval('public.auth_logs_id_seq'::regclass);


--
-- Name: charge_models id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.charge_models ALTER COLUMN id SET DEFAULT nextval('public.charge_models_id_seq'::regclass);


--
-- Name: countries_base id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.countries_base ALTER COLUMN id SET DEFAULT nextval('public.countries_id_seq'::regclass);


--
-- Name: country_mccs id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.country_mccs ALTER COLUMN id SET DEFAULT nextval('public.country_mccs_id_seq'::regclass);


--
-- Name: country_meta id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.country_meta ALTER COLUMN id SET DEFAULT nextval('public.country_meta_id_seq'::regclass);


--
-- Name: dropdown_items id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.dropdown_items ALTER COLUMN id SET DEFAULT nextval('public.dropdown_items_id_seq'::regclass);


--
-- Name: dropdown_menus id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.dropdown_menus ALTER COLUMN id SET DEFAULT nextval('public.dropdown_menus_id_seq'::regclass);


--
-- Name: failed_jobs id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.failed_jobs ALTER COLUMN id SET DEFAULT nextval('public.failed_jobs_id_seq'::regclass);


--
-- Name: imap_settings id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.imap_settings ALTER COLUMN id SET DEFAULT nextval('public.imap_settings_id_seq'::regclass);


--
-- Name: jobs id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.jobs ALTER COLUMN id SET DEFAULT nextval('public.jobs_id_seq'::regclass);


--
-- Name: known_hops id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.known_hops ALTER COLUMN id SET DEFAULT nextval('public.known_hops_id_seq'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Name: network_meta id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.network_meta ALTER COLUMN id SET DEFAULT nextval('public.network_meta_id_seq'::regclass);


--
-- Name: network_mncs id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.network_mncs ALTER COLUMN id SET DEFAULT nextval('public.network_mncs_id_seq'::regclass);


--
-- Name: networks_base id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.networks_base ALTER COLUMN id SET DEFAULT nextval('public.networks_id_seq'::regclass);


--
-- Name: route_types id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.route_types ALTER COLUMN id SET DEFAULT nextval('public.route_types_id_seq'::regclass);


--
-- Name: supplier_connections id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.supplier_connections ALTER COLUMN id SET DEFAULT nextval('public.supplier_connections_id_seq'::regclass);


--
-- Name: supplier_offer_histories id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.supplier_offer_histories ALTER COLUMN id SET DEFAULT nextval('public.supplier_offer_histories_id_seq'::regclass);


--
-- Name: supplier_offer_history id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.supplier_offer_history ALTER COLUMN id SET DEFAULT nextval('public.supplier_offer_history_id_seq'::regclass);


--
-- Name: supplier_offers id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.supplier_offers ALTER COLUMN id SET DEFAULT nextval('public.supplier_offers_id_seq'::regclass);


--
-- Name: suppliers id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.suppliers ALTER COLUMN id SET DEFAULT nextval('public.suppliers_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: auth_logs; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.auth_logs (id, user_id, event, ip, user_agent, created_at, updated_at) FROM stdin;
1	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-18 15:38:09	2025-11-18 15:38:09
2	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-18 15:38:50	2025-11-18 15:38:50
3	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-18 19:08:50	2025-11-18 19:08:50
4	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-19 07:48:58	2025-11-19 07:48:58
5	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-20 09:10:50	2025-11-20 09:10:50
6	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-20 15:32:51	2025-11-20 15:32:51
7	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-20 22:13:28	2025-11-20 22:13:28
8	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 09:29:54	2025-11-21 09:29:54
9	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 15:27:44	2025-11-21 15:27:44
10	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 20:29:13	2025-11-21 20:29:13
11	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 20:29:19	2025-11-21 20:29:19
12	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:04:13	2025-11-21 21:04:13
13	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:04:18	2025-11-21 21:04:18
14	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:09:55	2025-11-21 21:09:55
15	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:10:06	2025-11-21 21:10:06
16	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:15:16	2025-11-21 21:15:16
17	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:15:25	2025-11-21 21:15:25
18	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:21:39	2025-11-21 21:21:39
19	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:21:43	2025-11-21 21:21:43
20	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:28:08	2025-11-21 21:28:08
21	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:28:13	2025-11-21 21:28:13
22	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:32:48	2025-11-21 21:32:48
23	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:32:52	2025-11-21 21:32:52
24	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:34:14	2025-11-21 21:34:14
25	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:34:18	2025-11-21 21:34:18
26	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:50:13	2025-11-21 21:50:13
27	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 21:50:18	2025-11-21 21:50:18
28	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 22:04:53	2025-11-21 22:04:53
29	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 22:04:57	2025-11-21 22:04:57
30	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 22:16:55	2025-11-21 22:16:55
31	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 22:16:59	2025-11-21 22:16:59
32	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 22:40:51	2025-11-21 22:40:51
33	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 22:40:55	2025-11-21 22:40:55
34	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 22:44:01	2025-11-21 22:44:01
35	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 22:44:05	2025-11-21 22:44:05
36	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 22:57:36	2025-11-21 22:57:36
37	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-21 22:57:41	2025-11-21 22:57:41
38	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-22 09:41:32	2025-11-22 09:41:32
39	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-22 13:07:06	2025-11-22 13:07:06
40	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-22 20:31:02	2025-11-22 20:31:02
41	1	logout	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-22 20:34:52	2025-11-22 20:34:52
42	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-22 20:34:59	2025-11-22 20:34:59
43	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-23 20:17:50	2025-11-23 20:17:50
44	1	login	192.168.50.10	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-24 11:31:26	2025-11-24 11:31:26
45	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-24 20:56:01	2025-11-24 20:56:01
46	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-25 07:54:12	2025-11-25 07:54:12
47	1	login	109.178.39.135	Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-25 18:01:08	2025-11-25 18:01:08
48	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-26 07:47:32	2025-11-26 07:47:32
49	1	login	109.178.114.107	Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-26 11:23:47	2025-11-26 11:23:47
50	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-27 11:46:37	2025-11-27 11:46:37
51	1	login	192.168.50.109	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36	2025-11-27 20:31:45	2025-11-27 20:31:45
\.


--
-- Data for Name: cache; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.cache (key, value, expiration) FROM stdin;
\.


--
-- Data for Name: cache_locks; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.cache_locks (key, owner, expiration) FROM stdin;
\.


--
-- Data for Name: charge_models; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.charge_models (id, name, slug, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: countries_base; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.countries_base (id, name, iso2, created_at, updated_at) FROM stdin;
215	Benin	BJ	2025-11-18 22:02:29	2025-11-18 22:02:29
216	Bermuda	BM	2025-11-18 22:02:29	2025-11-18 22:02:29
217	Bhutan	BT	2025-11-18 22:02:29	2025-11-18 22:02:29
218	Bolivia	BO	2025-11-18 22:02:29	2025-11-18 22:02:29
219	Bonaire, Sint Eustatius and Saba	BQ	2025-11-18 22:02:29	2025-11-18 22:02:29
220	Bosnia and Herzegovina	BA	2025-11-18 22:02:29	2025-11-18 22:02:29
221	Botswana	BW	2025-11-18 22:02:29	2025-11-18 22:02:29
222	Brazil	BR	2025-11-18 22:02:29	2025-11-18 22:02:29
223	British Virgin Islands	VG	2025-11-18 22:02:29	2025-11-18 22:02:29
224	Brunei	BN	2025-11-18 22:02:29	2025-11-18 22:02:29
225	Bulgaria	BG	2025-11-18 22:02:29	2025-11-18 22:02:29
226	Burkina Faso	BF	2025-11-18 22:02:29	2025-11-18 22:02:29
227	Burundi	BI	2025-11-18 22:02:29	2025-11-18 22:02:29
228	Cambodia	KH	2025-11-18 22:02:29	2025-11-18 22:02:29
229	Cameroon	CM	2025-11-18 22:02:29	2025-11-18 22:02:29
230	Canada	CA	2025-11-18 22:02:29	2025-11-18 22:02:29
231	Cape Verde	CV	2025-11-18 22:02:29	2025-11-18 22:02:29
232	Cayman Islands	KY	2025-11-18 22:02:29	2025-11-18 22:02:29
233	Central African Republic	CF	2025-11-18 22:02:29	2025-11-18 22:02:29
234	Chad	TD	2025-11-18 22:02:29	2025-11-18 22:02:29
235	Chile	CL	2025-11-18 22:02:29	2025-11-18 22:02:29
236	China	CN	2025-11-18 22:02:30	2025-11-18 22:02:30
237	Colombia	CO	2025-11-18 22:02:30	2025-11-18 22:02:30
238	Comoros	KM	2025-11-18 22:02:30	2025-11-18 22:02:30
239	Congo	CG	2025-11-18 22:02:30	2025-11-18 22:02:30
240	Cook Islands	CK	2025-11-18 22:02:30	2025-11-18 22:02:30
241	Costa Rica	CR	2025-11-18 22:02:30	2025-11-18 22:02:30
242	Croatia	HR	2025-11-18 22:02:30	2025-11-18 22:02:30
243	Cuba	CU	2025-11-18 22:02:30	2025-11-18 22:02:30
244	Curacao	CW	2025-11-18 22:02:30	2025-11-18 22:02:30
245	Cyprus	CY	2025-11-18 22:02:30	2025-11-18 22:02:30
246	Czech Republic	CZ	2025-11-18 22:02:30	2025-11-18 22:02:30
247	Democratic Republic of Congo	CD	2025-11-18 22:02:30	2025-11-18 22:02:30
248	Denmark	DK	2025-11-18 22:02:30	2025-11-18 22:02:30
249	Djibouti	DJ	2025-11-18 22:02:30	2025-11-18 22:02:30
250	Dominica	DM	2025-11-18 22:02:30	2025-11-18 22:02:30
251	Dominican Republic	DO	2025-11-18 22:02:30	2025-11-18 22:02:30
252	East Timor	TL	2025-11-18 22:02:30	2025-11-18 22:02:30
253	Ecuador	EC	2025-11-18 22:02:30	2025-11-18 22:02:30
254	Egypt	EG	2025-11-18 22:02:30	2025-11-18 22:02:30
255	El Salvador	SV	2025-11-18 22:02:30	2025-11-18 22:02:30
256	Equatorial Guinea	GQ	2025-11-18 22:02:30	2025-11-18 22:02:30
257	Eritrea	ER	2025-11-18 22:02:30	2025-11-18 22:02:30
258	Estonia	EE	2025-11-18 22:02:30	2025-11-18 22:02:30
259	Ethiopia	ET	2025-11-18 22:02:30	2025-11-18 22:02:30
260	Falkland Islands	FK	2025-11-18 22:02:30	2025-11-18 22:02:30
261	Faroe Islands	FO	2025-11-18 22:02:30	2025-11-18 22:02:30
262	Fiji	FJ	2025-11-18 22:02:30	2025-11-18 22:02:30
263	Finland	FI	2025-11-18 22:02:30	2025-11-18 22:02:30
264	France	FR	2025-11-18 22:02:30	2025-11-18 22:02:30
265	French Guiana	GF	2025-11-18 22:02:31	2025-11-18 22:02:31
266	French Polynesia	PF	2025-11-18 22:02:31	2025-11-18 22:02:31
267	Gabon	GA	2025-11-18 22:02:31	2025-11-18 22:02:31
268	Gambia	GM	2025-11-18 22:02:31	2025-11-18 22:02:31
269	Germany	DE	2025-11-18 22:02:31	2025-11-18 22:02:31
270	Ghana	GH	2025-11-18 22:02:31	2025-11-18 22:02:31
271	Gibraltar	GI	2025-11-18 22:02:31	2025-11-18 22:02:31
272	Greenland	GL	2025-11-18 22:02:31	2025-11-18 22:02:31
273	Grenada	GD	2025-11-18 22:02:31	2025-11-18 22:02:31
274	Guadeloupe	GP	2025-11-18 22:02:31	2025-11-18 22:02:31
275	Guam	GU	2025-11-18 22:02:31	2025-11-18 22:02:31
276	Guatemala	GT	2025-11-18 22:02:31	2025-11-18 22:02:31
277	Guinea	GN	2025-11-18 22:02:31	2025-11-18 22:02:31
278	Guinea-Bissau	GW	2025-11-18 22:02:31	2025-11-18 22:02:31
279	Guyana	GY	2025-11-18 22:02:31	2025-11-18 22:02:31
280	Haiti	HT	2025-11-18 22:02:31	2025-11-18 22:02:31
281	Honduras	HN	2025-11-18 22:02:31	2025-11-18 22:02:31
282	Hongkong	HK	2025-11-18 22:02:31	2025-11-18 22:02:31
283	Hungary	HU	2025-11-18 22:02:31	2025-11-18 22:02:31
284	Iceland	IS	2025-11-18 22:02:31	2025-11-18 22:02:31
285	India	IN	2025-11-18 22:02:31	2025-11-18 22:02:31
286	Indonesia	ID	2025-11-18 22:02:32	2025-11-18 22:02:32
288	Iran	IR	2025-11-18 22:02:32	2025-11-18 22:02:32
289	Iraq	IQ	2025-11-18 22:02:32	2025-11-18 22:02:32
290	Ireland	IE	2025-11-18 22:02:32	2025-11-18 22:02:32
291	Israel	IL	2025-11-18 22:02:32	2025-11-18 22:02:32
292	Italy	IT	2025-11-18 22:02:32	2025-11-18 22:02:32
293	Ivory Coast	CI	2025-11-18 22:02:32	2025-11-18 22:02:32
294	Jamaica	JM	2025-11-18 22:02:32	2025-11-18 22:02:32
295	Japan	JP	2025-11-18 22:02:32	2025-11-18 22:02:32
296	Jordan	JO	2025-11-18 22:02:33	2025-11-18 22:02:33
297	Kazakhstan	KZ	2025-11-18 22:02:33	2025-11-18 22:02:33
298	Kenya	KE	2025-11-18 22:02:33	2025-11-18 22:02:33
299	Kiribati	KI	2025-11-18 22:02:33	2025-11-18 22:02:33
300	Kosovo	XK	2025-11-18 22:02:33	2025-11-18 22:02:33
301	Kuwait	KW	2025-11-18 22:02:33	2025-11-18 22:02:33
302	Kyrgyzstan	KG	2025-11-18 22:02:33	2025-11-18 22:02:33
303	Laos	LA	2025-11-18 22:02:33	2025-11-18 22:02:33
304	Latvia	LV	2025-11-18 22:02:33	2025-11-18 22:02:33
305	Lebanon	LB	2025-11-18 22:02:33	2025-11-18 22:02:33
306	Lesotho	LS	2025-11-18 22:02:33	2025-11-18 22:02:33
307	Liberia	LR	2025-11-18 22:02:33	2025-11-18 22:02:33
308	Libya	LY	2025-11-18 22:02:33	2025-11-18 22:02:33
309	Liechtenstein	LI	2025-11-18 22:02:33	2025-11-18 22:02:33
310	Lithuania	LT	2025-11-18 22:02:33	2025-11-18 22:02:33
311	Luxembourg	LU	2025-11-18 22:02:33	2025-11-18 22:02:33
312	Macao	MO	2025-11-18 22:02:33	2025-11-18 22:02:33
313	Madagascar	MG	2025-11-18 22:02:33	2025-11-18 22:02:33
191	Greece	GR	2025-11-18 20:53:34	2025-11-18 20:53:34
192	Netherlands	NL	2025-11-18 20:53:34	2025-11-18 20:53:34
193	Abkhazia	GE	2025-11-18 22:02:28	2025-11-18 22:02:28
194	Afghanistan	AF	2025-11-18 22:02:28	2025-11-18 22:02:28
195	Albania	AL	2025-11-18 22:02:28	2025-11-18 22:02:28
325	Micronesia	FM	2025-11-18 22:02:34	2025-11-18 22:02:34
326	Moldova	MD	2025-11-18 22:02:34	2025-11-18 22:02:34
327	Monaco	MC	2025-11-18 22:02:34	2025-11-18 22:02:34
328	Mongolia	MN	2025-11-18 22:02:34	2025-11-18 22:02:34
329	Montenegro	ME	2025-11-18 22:02:34	2025-11-18 22:02:34
330	Montserrat	MS	2025-11-18 22:02:34	2025-11-18 22:02:34
331	Morocco	MA	2025-11-18 22:02:34	2025-11-18 22:02:34
332	Mozambique	MZ	2025-11-18 22:02:34	2025-11-18 22:02:34
333	Myanmar	MM	2025-11-18 22:02:34	2025-11-18 22:02:34
334	Namibia	NA	2025-11-18 22:02:34	2025-11-18 22:02:34
317	Mali	ML	2025-11-18 22:02:33	2025-11-18 22:02:33
196	Algeria	DZ	2025-11-18 22:02:28	2025-11-18 22:02:28
197	American Samoa	AS	2025-11-18 22:02:28	2025-11-18 22:02:28
198	Andorra	AD	2025-11-18 22:02:28	2025-11-18 22:02:28
199	Angola	AO	2025-11-18 22:02:28	2025-11-18 22:02:28
210	Bangladesh	BD	2025-11-18 22:02:29	2025-11-18 22:02:29
211	Barbados	BB	2025-11-18 22:02:29	2025-11-18 22:02:29
212	Belarus	BY	2025-11-18 22:02:29	2025-11-18 22:02:29
213	Belgium	BE	2025-11-18 22:02:29	2025-11-18 22:02:29
214	Belize	BZ	2025-11-18 22:02:29	2025-11-18 22:02:29
354	Philippines	PH	2025-11-18 22:02:35	2025-11-18 22:02:35
355	Poland	PL	2025-11-18 22:02:35	2025-11-18 22:02:35
356	Portugal	PT	2025-11-18 22:02:35	2025-11-18 22:02:35
357	Puerto Rico	PR	2025-11-18 22:02:35	2025-11-18 22:02:35
358	Qatar	QA	2025-11-18 22:02:35	2025-11-18 22:02:35
359	Reunion	RE	2025-11-18 22:02:35	2025-11-18 22:02:35
360	Romania	RO	2025-11-18 22:02:35	2025-11-18 22:02:35
361	Russia	RU	2025-11-18 22:02:35	2025-11-18 22:02:35
362	Rwanda	RW	2025-11-18 22:02:35	2025-11-18 22:02:35
363	Saint Helena and Ascension and Tristan da Cunha	SH	2025-11-18 22:02:35	2025-11-18 22:02:35
364	Saint Kitts and Nevis	KN	2025-11-18 22:02:35	2025-11-18 22:02:35
365	Saint Lucia	LC	2025-11-18 22:02:35	2025-11-18 22:02:35
366	Saint Pierre and Miquelon	PM	2025-11-18 22:02:35	2025-11-18 22:02:35
367	Saint Vincent and the Grenadines	VC	2025-11-18 22:02:35	2025-11-18 22:02:35
368	Samoa	WS	2025-11-18 22:02:35	2025-11-18 22:02:35
369	San Marino	SM	2025-11-18 22:02:35	2025-11-18 22:02:35
370	Sao Tome and Principe	ST	2025-11-18 22:02:35	2025-11-18 22:02:35
371	Saudi Arabia	SA	2025-11-18 22:02:35	2025-11-18 22:02:35
372	Senegal	SN	2025-11-18 22:02:36	2025-11-18 22:02:36
373	Serbia	RS	2025-11-18 22:02:36	2025-11-18 22:02:36
374	Seychelles	SC	2025-11-18 22:02:36	2025-11-18 22:02:36
375	Sierra Leone	SL	2025-11-18 22:02:36	2025-11-18 22:02:36
376	Singapore	SG	2025-11-18 22:02:36	2025-11-18 22:02:36
377	Slovakia	SK	2025-11-18 22:02:36	2025-11-18 22:02:36
378	Slovenia	SI	2025-11-18 22:02:36	2025-11-18 22:02:36
379	Solomon Islands	SB	2025-11-18 22:02:36	2025-11-18 22:02:36
380	Somalia	SO	2025-11-18 22:02:36	2025-11-18 22:02:36
381	South Africa	ZA	2025-11-18 22:02:36	2025-11-18 22:02:36
382	South Korea	KR	2025-11-18 22:02:36	2025-11-18 22:02:36
383	South Sudan	SS	2025-11-18 22:02:36	2025-11-18 22:02:36
384	Spain	ES	2025-11-18 22:02:36	2025-11-18 22:02:36
385	Sri Lanka	LK	2025-11-18 22:02:36	2025-11-18 22:02:36
386	Sudan	SD	2025-11-18 22:02:36	2025-11-18 22:02:36
387	Suriname	SR	2025-11-18 22:02:36	2025-11-18 22:02:36
388	Swaziland	SZ	2025-11-18 22:02:36	2025-11-18 22:02:36
389	Sweden	SE	2025-11-18 22:02:36	2025-11-18 22:02:36
390	Switzerland	CH	2025-11-18 22:02:37	2025-11-18 22:02:37
391	Syria	SY	2025-11-18 22:02:37	2025-11-18 22:02:37
392	Taiwan	TW	2025-11-18 22:02:37	2025-11-18 22:02:37
393	Tajikistan	TJ	2025-11-18 22:02:37	2025-11-18 22:02:37
394	Tanzania	TZ	2025-11-18 22:02:37	2025-11-18 22:02:37
395	Thailand	TH	2025-11-18 22:02:37	2025-11-18 22:02:37
396	Togo	TG	2025-11-18 22:02:37	2025-11-18 22:02:37
397	Tonga	TO	2025-11-18 22:02:37	2025-11-18 22:02:37
398	Trinidad and Tobago	TT	2025-11-18 22:02:37	2025-11-18 22:02:37
399	Tunisia	TN	2025-11-18 22:02:37	2025-11-18 22:02:37
400	Turkiye	TR	2025-11-18 22:02:37	2025-11-18 22:02:37
401	Turkmenistan	TM	2025-11-18 22:02:37	2025-11-18 22:02:37
402	Turks and Caicos Islands	TC	2025-11-18 22:02:37	2025-11-18 22:02:37
403	Tuvalu	TV	2025-11-18 22:02:37	2025-11-18 22:02:37
404	Uganda	UG	2025-11-18 22:02:37	2025-11-18 22:02:37
405	Ukraine	UA	2025-11-18 22:02:37	2025-11-18 22:02:37
406	United Arab Emirates	AE	2025-11-18 22:02:37	2025-11-18 22:02:37
407	United Kingdom	GB	2025-11-18 22:02:37	2025-11-18 22:02:37
408	United States of America	US	2025-11-18 22:02:38	2025-11-18 22:02:38
409	Uruguay	UY	2025-11-18 22:02:38	2025-11-18 22:02:38
410	Uzbekistan	UZ	2025-11-18 22:02:38	2025-11-18 22:02:38
411	Vanuatu	VU	2025-11-18 22:02:38	2025-11-18 22:02:38
412	Vatican	VA	2025-11-18 22:02:38	2025-11-18 22:02:38
413	Venezuela	VE	2025-11-18 22:02:39	2025-11-18 22:02:39
414	Vietnam	VN	2025-11-18 22:02:39	2025-11-18 22:02:39
415	Virgin Islands	VI	2025-11-18 22:02:39	2025-11-18 22:02:39
416	Wallis and Futuna	WF	2025-11-18 22:02:39	2025-11-18 22:02:39
417	Yemen	YE	2025-11-18 22:02:39	2025-11-18 22:02:39
418	Zambia	ZM	2025-11-18 22:02:39	2025-11-18 22:02:39
419	Zimbabwe	ZW	2025-11-18 22:02:39	2025-11-18 22:02:39
314	Malawi	MW	2025-11-18 22:02:33	2025-11-18 22:02:33
315	Malaysia	MY	2025-11-18 22:02:33	2025-11-18 22:02:33
316	Maldives	MV	2025-11-18 22:02:33	2025-11-18 22:02:33
318	Malta	MT	2025-11-18 22:02:33	2025-11-18 22:02:33
319	Marshall Islands	MH	2025-11-18 22:02:33	2025-11-18 22:02:33
320	Martinique	MQ	2025-11-18 22:02:33	2025-11-18 22:02:33
321	Mauritania	MR	2025-11-18 22:02:33	2025-11-18 22:02:33
322	Mauritius	MU	2025-11-18 22:02:34	2025-11-18 22:02:34
323	Mayotte	YT	2025-11-18 22:02:34	2025-11-18 22:02:34
324	Mexico	MX	2025-11-18 22:02:34	2025-11-18 22:02:34
335	Nepal	NP	2025-11-18 22:02:34	2025-11-18 22:02:34
336	Netherlands Antilles	AN	2025-11-18 22:02:34	2025-11-18 22:02:34
337	New Caledonia	NC	2025-11-18 22:02:34	2025-11-18 22:02:34
338	New Zealand	NZ	2025-11-18 22:02:34	2025-11-18 22:02:34
340	Niger	NE	2025-11-18 22:02:34	2025-11-18 22:02:34
341	Nigeria	NG	2025-11-18 22:02:34	2025-11-18 22:02:34
342	Niue	NU	2025-11-18 22:02:34	2025-11-18 22:02:34
343	North Korea	KP	2025-11-18 22:02:34	2025-11-18 22:02:34
344	North Macedonia	MK	2025-11-18 22:02:34	2025-11-18 22:02:34
345	Norway	NO	2025-11-18 22:02:34	2025-11-18 22:02:34
346	Oman	OM	2025-11-18 22:02:34	2025-11-18 22:02:34
347	Pakistan	PK	2025-11-18 22:02:34	2025-11-18 22:02:34
348	Palau	PW	2025-11-18 22:02:34	2025-11-18 22:02:34
349	Palestinian Territory	PS	2025-11-18 22:02:34	2025-11-18 22:02:34
350	Panama	PA	2025-11-18 22:02:34	2025-11-18 22:02:34
351	Papua New Guinea	PG	2025-11-18 22:02:35	2025-11-18 22:02:35
352	Paraguay	PY	2025-11-18 22:02:35	2025-11-18 22:02:35
353	Peru	PE	2025-11-18 22:02:35	2025-11-18 22:02:35
287	Satellite Networks	ZZ	2025-11-18 22:02:32	2025-11-21 18:54:55
448	Nicaragua	NI	2025-11-26 15:11:40	2025-11-27 13:41:24
200	Anguilla	AI	2025-11-18 22:02:28	2025-11-18 22:02:28
201	Antigua and Barbuda	AG	2025-11-18 22:02:28	2025-11-18 22:02:28
202	Argentina	AR	2025-11-18 22:02:28	2025-11-18 22:02:28
203	Armenia	AM	2025-11-18 22:02:28	2025-11-18 22:02:28
204	Aruba	AW	2025-11-18 22:02:28	2025-11-18 22:02:28
205	Australia	AU	2025-11-18 22:02:28	2025-11-18 22:02:28
206	Austria	AT	2025-11-18 22:02:29	2025-11-18 22:02:29
207	Azerbaijan	AZ	2025-11-18 22:02:29	2025-11-18 22:02:29
208	Bahamas	BS	2025-11-18 22:02:29	2025-11-18 22:02:29
209	Bahrain	BH	2025-11-18 22:02:29	2025-11-18 22:02:29
\.


--
-- Data for Name: country_mccs; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.country_mccs (id, country_id, mcc, created_at, updated_at, marked_for_deletion, created_by_user_id, updated_by_user_id, created_by_source, updated_by_source) FROM stdin;
1	193	289	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
232	448	710	2025-11-27 13:41:19	2025-11-27 13:41:19	f	\N	\N	\N	\N
2	194	412	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
3	195	276	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
4	196	603	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
5	197	544	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
6	198	213	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
7	199	631	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
8	200	365	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
9	201	344	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
10	202	722	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
11	203	283	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
12	204	363	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
13	205	505	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
14	206	232	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
15	207	400	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
16	208	364	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
17	209	426	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
18	210	470	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
19	211	342	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
20	212	257	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
21	213	206	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
22	214	702	2025-11-21 18:54:55	2025-11-21 18:54:55	f	\N	\N	import:itu	import:itu
23	215	616	2025-11-21 18:54:55	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
24	216	350	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
25	217	402	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
26	218	736	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
28	220	218	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
29	221	652	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
30	222	724	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
31	223	348	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
32	224	528	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
33	225	284	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
34	226	613	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
35	227	642	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
36	228	456	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
37	229	624	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
38	230	302	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
39	231	625	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
40	232	346	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
41	233	623	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
42	234	622	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
43	235	730	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
44	236	460	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
45	237	732	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
46	238	654	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
47	239	629	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
48	240	548	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
49	241	712	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
50	242	219	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
51	243	368	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
52	245	280	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
53	246	230	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
54	247	630	2025-11-21 18:54:56	2025-11-21 18:54:56	f	\N	\N	import:itu	import:itu
55	248	238	2025-11-21 18:54:56	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
56	249	638	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
57	250	366	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
58	251	370	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
59	252	514	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
60	253	740	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
61	254	602	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
62	255	706	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
63	256	627	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
64	257	657	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
65	258	248	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
66	259	636	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
67	260	750	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
68	261	288	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
69	262	542	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
70	263	244	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
71	264	208	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
73	266	547	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
74	267	628	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
75	268	607	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
76	193	282	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
77	269	262	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
78	270	620	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
79	271	266	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
80	191	202	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
81	272	290	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
82	273	352	2025-11-21 18:54:57	2025-11-21 18:54:57	f	\N	\N	import:itu	import:itu
85	276	704	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
86	277	611	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
87	278	632	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
88	279	738	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
89	280	372	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
90	281	708	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
91	282	454	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
92	283	216	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
93	284	274	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
95	285	405	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
94	285	404	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
96	286	510	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
98	288	432	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
99	289	418	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
100	290	272	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
102	292	222	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
103	293	612	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
104	294	338	2025-11-21 18:54:58	2025-11-21 18:54:58	f	\N	\N	import:itu	import:itu
106	295	441	2025-11-21 18:54:58	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
105	295	440	2025-11-21 18:54:58	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
107	296	416	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
108	297	401	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
109	298	639	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
110	299	545	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
111	300	221	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
112	301	419	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
113	302	437	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
114	303	457	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
115	304	247	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
116	305	415	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
117	306	651	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
118	307	618	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
119	308	606	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
120	309	295	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
121	310	246	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
122	311	270	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
123	312	455	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
124	313	646	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
125	314	650	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
126	315	502	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
127	316	472	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
128	317	610	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
129	318	278	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
130	319	551	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
72	320	340	2025-11-21 18:54:57	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
131	321	609	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
132	322	617	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
134	324	334	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
135	325	550	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
136	326	259	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
137	327	212	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
138	328	428	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
139	329	297	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
140	330	354	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
141	331	604	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
142	332	643	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
143	333	414	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
144	334	649	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
145	335	429	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
146	192	204	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
27	336	362	2025-11-21 18:54:56	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
147	337	546	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
148	338	530	2025-11-21 18:54:59	2025-11-21 18:54:59	f	\N	\N	import:itu	import:itu
150	340	614	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
151	341	621	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
152	342	555	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
153	343	467	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
154	344	294	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
155	345	242	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
156	346	422	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
157	347	410	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
158	348	552	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
101	349	425	2025-11-21 18:54:58	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
159	350	714	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
160	351	537	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
161	352	744	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
162	353	716	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
163	354	515	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
164	355	260	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
165	356	268	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
166	357	330	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
167	358	427	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
133	359	647	2025-11-21 18:54:59	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
168	360	226	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
169	361	250	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
170	362	635	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
171	363	658	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
172	364	356	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
173	365	358	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
174	366	308	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
175	367	360	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
176	368	549	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
177	369	292	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
178	370	626	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
97	287	901	2025-11-21 18:54:58	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
179	371	420	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
180	372	608	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
181	373	220	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
182	374	633	2025-11-21 18:55:00	2025-11-21 18:55:00	f	\N	\N	import:itu	import:itu
183	375	619	2025-11-21 18:55:00	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
184	376	525	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
185	377	231	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
186	378	293	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
187	379	540	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
188	380	637	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
189	381	655	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
190	382	450	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
191	383	659	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
192	384	214	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
193	385	413	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
194	386	634	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
195	387	746	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
196	388	653	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
197	389	240	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
198	390	228	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
199	391	417	2025-11-21 18:55:01	2025-11-21 18:55:01	f	\N	\N	import:itu	import:itu
200	392	466	2025-11-21 18:55:01	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
201	393	436	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
202	394	640	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
203	395	520	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
204	396	615	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
205	397	539	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
206	398	374	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
207	399	605	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
208	400	286	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
209	401	438	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
211	403	553	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
212	404	641	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
213	405	255	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
214	406	424	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
215	406	431	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
216	406	430	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
218	407	235	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
217	407	234	2025-11-21 18:55:02	2025-11-21 18:55:02	f	\N	\N	import:itu	import:itu
220	408	316	2025-11-21 18:55:03	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
219	408	312	2025-11-21 18:55:02	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
84	408	311	2025-11-21 18:54:58	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
83	408	310	2025-11-21 18:54:57	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
221	409	748	2025-11-21 18:55:03	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
222	410	434	2025-11-21 18:55:03	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
223	411	541	2025-11-21 18:55:03	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
224	412	225	2025-11-21 18:55:03	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
225	413	734	2025-11-21 18:55:03	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
226	414	452	2025-11-21 18:55:03	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
210	415	376	2025-11-21 18:55:02	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
227	416	543	2025-11-21 18:55:03	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
228	417	421	2025-11-21 18:55:03	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
229	418	645	2025-11-21 18:55:03	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
230	419	648	2025-11-21 18:55:03	2025-11-21 18:55:03	f	\N	\N	import:itu	import:itu
\.


--
-- Data for Name: country_meta; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.country_meta (id, country_id, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: dropdown_items; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.dropdown_items (id, dropdown_menu_id, label, created_at, updated_at, "position") FROM stdin;
1	1	Direct	2025-11-22 21:21:59	2025-11-22 21:21:59	0
2	1	HQ	2025-11-22 21:22:02	2025-11-22 21:22:02	0
3	1	SIM	2025-11-22 21:22:05	2025-11-22 21:22:05	0
4	1	SS7	2025-11-22 21:22:08	2025-11-22 21:22:08	0
5	1	Local Bypass	2025-11-22 21:22:12	2025-11-22 21:22:12	0
6	2	0-Hop	2025-11-22 22:07:31	2025-11-22 22:07:31	0
7	2	1-Hop	2025-11-22 22:07:38	2025-11-22 22:07:38	0
8	2	2-Hops	2025-11-22 22:07:42	2025-11-22 22:07:42	0
9	2	N-Hops	2025-11-22 22:07:46	2025-11-22 22:07:46	0
10	3	Dynamic Alphanumeric	2025-11-22 22:14:09	2025-11-22 22:14:14	0
11	3	Dynamic Numeric	2025-11-22 22:14:21	2025-11-22 22:14:21	0
12	3	Shared Shortcode	2025-11-22 22:14:30	2025-11-22 22:14:30	0
13	3	Dedicated Shortcode	2025-11-22 22:14:38	2025-11-22 22:14:38	0
14	3	Regsid - No Generic	2025-11-22 22:15:37	2025-11-22 22:15:37	0
15	3	Regsid - With Generic	2025-11-22 22:15:47	2025-11-22 22:15:47	0
16	3	Random Numeric	2025-11-25 15:43:33	2025-11-25 15:43:33	0
\.


--
-- Data for Name: dropdown_menus; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.dropdown_menus (id, title, created_at, updated_at) FROM stdin;
1	Product Type	2025-11-22 21:21:44	2025-11-22 21:21:44
2	Known Hops	2025-11-22 22:07:26	2025-11-22 22:07:26
3	Sender Id Supported	2025-11-22 22:13:53	2025-11-22 22:13:53
\.


--
-- Data for Name: failed_jobs; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.failed_jobs (id, uuid, connection, queue, payload, exception, failed_at) FROM stdin;
\.


--
-- Data for Name: imap_settings; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.imap_settings (id, host, port, encryption, username, password, enabled, poll_minutes, selected_folders, last_folders_cache, last_test_log, created_at, updated_at, last_run_at) FROM stdin;
1	mail.m-stat.gr	993	ssl	n.pardas@m-stat.gr	Rene!!@@1122	f	5	[]	[{"value":"INBOX.2025","label":"2025"},{"value":"INBOX.Archive","label":"Archive"},{"value":"INBOX.Archive.2024","label":"Archive \\u2192 2024"},{"value":"INBOX.Archive.2025","label":"Archive \\u2192 2025"},{"value":"INBOX.Balance","label":"Balance"},{"value":"INBOX.Balance.Customers","label":"Balance \\u2192 Customers"},{"value":"INBOX.Balance.Suppliers","label":"Balance \\u2192 Suppliers"},{"value":"INBOX.Drafts","label":"Drafts"},{"value":"INBOX","label":"INBOX"},{"value":"INBOX.Junk","label":"Junk"},{"value":"INBOX.Rates","label":"Rates"},{"value":"INBOX.Rates.Customers","label":"Rates \\u2192 Customers"},{"value":"INBOX.Rates.Suppliers","label":"Rates \\u2192 Suppliers"},{"value":"INBOX.Reports","label":"Reports"},{"value":"INBOX.Reports.CRM","label":"Reports \\u2192 CRM"},{"value":"INBOX.Reports.Customers","label":"Reports \\u2192 Customers"},{"value":"INBOX.Reports.Routing","label":"Reports \\u2192 Routing"},{"value":"INBOX.Reports.Suppliers","label":"Reports \\u2192 Suppliers"},{"value":"INBOX.Sent","label":"Sent"},{"value":"INBOX.spam","label":"spam"},{"value":"INBOX.Tickets","label":"Tickets"},{"value":"INBOX.Trash","label":"Trash"}]	Connected OK to mail.m-stat.gr:993 (ssl)\n	2025-11-18 15:20:37	2025-11-27 13:59:04	\N
\.


--
-- Data for Name: job_batches; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.job_batches (id, name, total_jobs, pending_jobs, failed_jobs, failed_job_ids, options, cancelled_at, created_at, finished_at) FROM stdin;
\.


--
-- Data for Name: jobs; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.jobs (id, queue, payload, attempts, reserved_at, available_at, created_at) FROM stdin;
\.


--
-- Data for Name: known_hops; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.known_hops (id, name, slug, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.migrations (id, migration, batch) FROM stdin;
1	0001_01_01_000000_create_users_table	1
2	0001_01_01_000001_create_cache_table	1
3	0001_01_01_000002_create_jobs_table	1
4	2025_11_10_151408_add_is_admin_to_users_table	1
5	2025_11_10_151408_create_route_types_table	1
6	2025_11_10_151409_create_charge_models_table	1
7	2025_11_10_151409_create_known_hops_table	1
8	2025_11_10_231903_create_auth_logs_table	1
9	2025_11_11_002716_add_timestamps_to_auth_logs	1
10	2025_11_12_153130_add_role_to_users_table	1
11	2025_11_12_225654_create_dropdown_menus_table	1
12	2025_11_12_225656_create_dropdown_items_table	1
13	2025_11_12_230233_add_position_to_dropdown_items	1
14	2025_11_12_232723_create_imap_settings_table	1
15	2025_11_13_002840_add_last_run_at_to_imap_settings	1
16	2025_11_13_011420_create_countries_and_networks	1
17	2025_11_13_012301_create_countries_and_networks	1
18	2025_11_13_103815_add_network_mncs_and_audit	1
19	2025_11_13_105616_add_unique_networks_country_lowername	1
20	2025_11_13_122038_add_marked_flag_to_networks	1
21	2025_11_13_132900_add_audit_cols_to_network_mncs	1
22	2025_11_13_234532_relax_legacy_not_null_on_networks_mcc_mnc	1
23	2025_11_13_235202_relax_networks_mcc_notnull	1
24	2025_11_14_000001_unique_indexes_on_mcc_tables	1
25	2025_11_14_000210_add_lower_name_to_networks	1
26	2025_11_14_000900_add_is_admin_to_users	1
27	2025_11_14_225238_add_audit_cols_to_country_mccs	1
28	2025_11_19_100443_install_countries_iso2_guard	2
29	2025_11_21_000101_create_network_meta_table	3
30	2025_11_21_000102_create_country_meta_table	3
31	2025_11_21_200937_add_network_mncs_normalizer_trigger	4
32	2025_11_22_150000_create_suppliers_table	5
33	2025_11_22_160000_create_supplier_connections_table	6
34	2025_11_22_170500_create_supplier_connections_table_fix	6
35	2025_11_22_233844_add_product_type_to_supplier_connections_table	7
36	2025_11_23_000514_add_connection_dead_to_supplier_connections_table	8
37	2025_11_23_012523_000000_create_supplier_offers_table	9
38	2025_11_23_012523_000001_create_supplier_offer_history_table	9
39	2025_11_24_010546_add_product_type_to_supplier_offers_tables	10
40	2025_11_23_230500_drop_route_type_from_supplier_offers_table	11
41	2025_11_24_150000_create_supplier_offer_histories_table	11
42	2025_11_24_200000_add_known_hops_and_sender_to_supplier_offers	11
43	2025_11_24_210000_add_known_hops_sender_id_supported_to_supplier_offers_table	11
44	2025_11_24_230000_offers_meta_string_fields	11
45	2025_11_25_174153_add_updated_by_to_supplier_offers_table	11
\.


--
-- Data for Name: network_meta; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.network_meta (id, network_id, non_operational, notes, created_at, updated_at) FROM stdin;
1	1404	f	\N	2025-11-21 16:23:49	2025-11-21 16:23:49
2	1405	f	\N	2025-11-21 18:00:56	2025-11-21 18:00:56
3	1945	f	\N	2025-11-21 18:10:59	2025-11-21 18:10:59
4	2436	f	\N	2025-11-26 15:12:01	2025-11-26 15:12:01
5	2435	f	\N	2025-11-26 15:12:59	2025-11-26 15:12:59
7	2433	f	\N	2025-11-27 12:07:55	2025-11-27 12:07:55
8	2434	f	\N	2025-11-27 12:08:07	2025-11-27 12:08:07
9	3324	f	\N	2025-11-27 13:43:34	2025-11-27 13:43:34
10	3316	f	\N	2025-11-27 13:44:14	2025-11-27 13:44:14
11	3313	f	\N	2025-11-27 13:44:46	2025-11-27 13:44:46
\.


--
-- Data for Name: network_mncs; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.network_mncs (id, network_id, mcc, mnc, mcc_mnc, marked_for_deletion, created_by_user_id, updated_by_user_id, created_by_source, updated_by_source, created_at, updated_at, created_by_user, updated_by_user) FROM stdin;
3	1405	289	67	28967	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
4	1406	412	1	41201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
5	1407	412	50	41250	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
6	1407	412	30	41230	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
7	1408	412	80	41280	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
8	1408	412	88	41288	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
9	1409	412	40	41240	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
10	1410	412	20	41220	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
11	1411	412	3	41203	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
12	1412	276	3	27603	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
13	1413	276	1	27601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
14	1414	276	4	27604	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
15	1415	276	2	27602	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
16	1416	603	2	60302	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
17	1417	603	1	60301	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
18	1418	603	3	60303	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
19	1419	544	780	544780	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
20	1420	544	11	54411	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
21	1421	213	3	21303	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
22	1422	631	4	63104	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
23	1423	631	2	63102	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
24	1424	365	850	365850	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
25	1425	365	840	365840	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
26	1426	344	93	34493	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
27	1426	344	930	344930	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
28	1427	344	92	34492	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
29	1427	344	920	344920	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
30	1428	344	3	34403	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
31	1428	344	30	34430	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
32	1429	722	310	722310	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
33	1429	722	330	722330	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
34	1429	722	31	72231	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
35	1429	722	320	722320	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
36	1430	722	299	722299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
37	1431	722	999	722999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
38	1435	722	10	72210	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
39	1435	722	7	72207	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
40	1435	722	70	72270	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
41	1437	722	20	72220	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
42	1439	722	34	72234	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
43	1439	722	341	722341	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
44	1439	722	340	722340	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
45	1441	283	1	28301	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
46	1442	283	4	28304	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
47	1443	283	10	28310	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
48	1444	283	5	28305	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
49	1445	363	2	36302	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
50	1445	363	20	36320	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
51	1446	363	299	363299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
52	1447	363	1	36301	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
53	1448	505	14	50514	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
54	1449	505	299	505299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
55	1450	505	24	50524	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
56	1451	505	9	50509	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
57	1452	505	30	50530	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
58	1453	505	4	50504	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
59	1454	505	999	505999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
60	1456	505	12	50512	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
61	1456	505	6	50506	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
62	1457	505	88	50588	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
63	1458	505	19	50519	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
64	1459	505	35	50535	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
65	1460	505	10	50510	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
66	1461	505	8	50508	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
67	1461	505	99	50599	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
68	1462	505	90	50590	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
69	1463	505	50	50550	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
70	1464	505	13	50513	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
71	1465	505	26	50526	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
72	1462	505	2	50502	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
73	1467	505	11	50511	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
74	1467	505	72	50572	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
75	1467	505	1	50501	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
1	1404	289	88	28988	f	\N	1	import:itu	networks.edit	2025-11-21 18:54:55	2025-11-22 13:08:29	\N	\N
76	1467	505	39	50539	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
77	1467	505	71	50571	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
78	1468	505	5	50505	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
79	1469	505	16	50516	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
80	1470	505	3	50503	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
81	1470	505	7	50507	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
82	1471	232	11	23211	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
83	1471	232	1	23201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
84	1471	232	9	23209	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
85	1471	232	12	23212	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
86	1471	232	2	23202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
87	1472	232	299	232299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
88	1473	232	15	23215	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
89	1478	232	999	232999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
90	1479	232	25	23225	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
91	1480	232	19	23219	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
92	1480	232	14	23214	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
93	1480	232	16	23216	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
94	1480	232	10	23210	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
95	1480	232	5	23205	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
96	1485	232	26	23226	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
97	1486	232	17	23217	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
98	1487	232	20	23220	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
99	1488	232	91	23291	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
100	1489	232	6	23206	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
101	1490	232	22	23222	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
102	1493	232	24	23224	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
103	1494	232	18	23218	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
104	1473	232	7	23207	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
105	1473	232	4	23204	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
106	1473	232	3	23203	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
107	1473	232	13	23213	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
108	1473	232	23	23223	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
109	1471	232	8	23208	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
110	1496	232	27	23227	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
111	1498	400	1	40001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
112	1499	400	2	40002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
113	1500	400	3	40003	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
114	1501	400	4	40004	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
115	1502	400	6	40006	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
116	1503	364	490	364490	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
117	1504	364	390	364390	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
118	1504	364	30	36430	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
119	1504	364	39	36439	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
120	1505	364	3	36403	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
121	1506	426	1	42601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
122	1507	426	299	426299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
123	1508	426	999	426999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
124	1509	426	5	42605	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
125	1510	426	4	42604	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
126	1511	426	2	42602	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
127	1512	470	7	47007	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
128	1512	470	2	47002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
129	1513	470	3	47003	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
130	1514	470	6	47006	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
131	1514	470	5	47005	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
132	1515	470	1	47001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
133	1516	470	4	47004	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
134	1518	342	810	342810	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
135	1519	342	750	342750	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
136	1519	342	50	34250	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
137	1520	342	299	342299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
138	1521	342	600	342600	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
139	1523	342	820	342820	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
140	1524	257	3	25703	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
141	1525	257	4	25704	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
142	1526	257	1	25701	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
143	1527	257	2	25702	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
144	1529	206	20	20620	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
145	1529	206	5	20605	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
146	1530	206	28	20628	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
147	1531	206	25	20625	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
148	1532	206	23	20623	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
149	1533	206	33	20633	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
150	1534	206	299	206299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
151	1535	206	999	206999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
152	1537	206	2	20602	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
153	1540	206	99	20699	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
154	1542	206	6	20606	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
155	1543	206	30	20630	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
156	1544	206	10	20610	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
157	1546	206	34	20634	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
158	1548	206	1	20601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
159	1548	206	4	20604	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
160	1548	206	0	20600	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
161	1550	206	7	20607	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
162	1551	206	8	20608	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
163	1553	702	67	70267	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
164	1554	702	299	702299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
165	1555	702	68	70268	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
166	1556	702	99	70299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
167	1556	702	69	70269	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
168	1557	616	4	61604	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:55	2025-11-21 18:54:55	\N	\N
169	1558	616	5	61605	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
170	1559	616	1	61601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
171	1560	616	2	61602	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
172	1561	616	3	61603	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
173	1562	350	0	35000	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
174	1563	350	99	35099	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
175	1564	350	1	35001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
176	1565	350	299	350299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
177	1566	350	2	35002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
178	1569	402	11	40211	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
179	1570	402	17	40217	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
180	1571	402	77	40277	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
181	1572	736	2	73602	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
182	1573	736	1	73601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
183	1574	736	3	73603	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
184	1575	362	999	362999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
185	1576	218	90	21890	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
186	1577	218	3	21803	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
187	1578	218	5	21805	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
188	1579	652	4	65204	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
189	1580	652	1	65201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
190	1581	652	2	65202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
191	1582	724	26	72426	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
192	1583	724	12	72412	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
193	1583	724	38	72438	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
194	1583	724	5	72405	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
195	1584	724	1	72401	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
196	1585	724	34	72434	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
197	1585	724	33	72433	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
198	1585	724	32	72432	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
199	1586	724	8	72408	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
200	1587	724	39	72439	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
201	1587	724	0	72400	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
202	1588	724	16	72416	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
203	1589	724	24	72424	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
204	1590	724	30	72430	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
205	1590	724	31	72431	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
206	1591	724	54	72454	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
207	1592	724	15	72415	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
208	1593	724	7	72407	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
209	1584	724	19	72419	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
210	1586	724	3	72403	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
211	1586	724	2	72402	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
212	1586	724	4	72404	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
213	1594	724	37	72437	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
214	1584	724	10	72410	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
215	1584	724	6	72406	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
216	1584	724	23	72423	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
217	1584	724	11	72411	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
218	1595	348	570	348570	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
219	1596	348	770	348770	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
220	1597	348	170	348170	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
221	1598	528	2	52802	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
222	1599	528	11	52811	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
223	1600	528	1	52801	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
224	1601	284	1	28401	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
225	1602	284	6	28406	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
226	1602	284	3	28403	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
227	1603	284	11	28411	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
228	1604	284	13	28413	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
229	1605	284	5	28405	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
230	1606	613	2	61302	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
231	1607	613	3	61303	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
232	1608	613	1	61301	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
233	1609	642	2	64202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
234	1610	642	999	642999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
235	1611	642	82	64282	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
236	1611	642	1	64201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
237	1612	642	8	64208	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
238	1613	642	3	64203	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
239	1614	642	7	64207	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
240	1615	456	4	45604	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
241	1616	456	1	45601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
242	1617	456	299	456299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
243	1618	456	8	45608	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
244	1616	456	18	45618	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
245	1620	456	3	45603	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
246	1621	456	11	45611	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
247	1622	456	6	45606	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
248	1622	456	5	45605	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
249	1622	456	2	45602	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
250	1623	456	9	45609	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
251	1624	624	1	62401	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
252	1625	624	4	62404	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
253	1626	624	2	62402	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
254	1627	302	652	302652	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
255	1628	302	630	302630	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
256	1629	302	610	302610	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
257	1629	302	651	302651	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
258	1630	302	670	302670	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
259	1631	302	361	302361	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
260	1631	302	360	302360	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
261	1632	302	380	302380	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
262	1633	302	710	302710	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
263	1634	302	640	302640	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
264	1635	302	370	302370	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
265	1636	302	320	302320	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
266	1637	302	702	302702	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
267	1638	302	660	302660	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
268	1638	302	655	302655	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
269	1639	302	701	302701	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
270	1640	302	703	302703	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
271	1641	302	760	302760	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
272	1642	302	657	302657	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
273	1643	302	720	302720	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
274	1644	302	680	302680	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
275	1644	302	780	302780	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
276	1644	302	654	302654	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
277	1645	302	656	302656	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
278	1646	302	653	302653	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
279	1646	302	220	302220	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
280	1647	302	500	302500	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
281	1648	302	490	302490	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
282	1649	625	1	62501	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
283	1650	625	2	62502	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
284	1651	346	50	34650	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
285	1652	346	6	34606	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
286	1653	346	140	346140	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
287	1654	346	1	34601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
288	1655	623	4	62304	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
289	1656	623	299	623299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
290	1657	623	1	62301	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
291	1658	623	3	62303	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
292	1660	623	2	62302	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
293	1661	622	1	62201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
294	1662	622	3	62203	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
295	1663	622	4	62204	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
296	1664	622	2	62202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
297	1665	730	6	73006	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
298	1666	730	11	73011	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
299	1667	730	15	73015	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
300	1668	730	3	73003	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
301	1669	730	10	73010	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
302	1670	730	1	73001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
303	1671	730	14	73014	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
304	1672	730	9	73009	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
305	1672	730	5	73005	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
306	1672	730	4	73004	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
307	1673	730	19	73019	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
308	1674	730	7	73007	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
309	1674	730	2	73002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
310	1675	730	12	73012	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
311	1676	730	0	73000	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
312	1677	730	13	73013	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
313	1678	730	8	73008	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
314	1679	460	7	46007	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
315	1679	460	0	46000	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
316	1679	460	2	46002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
317	1680	460	4	46004	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
318	1681	460	3	46003	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
319	1681	460	5	46005	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
320	1682	460	6	46006	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
321	1682	460	1	46001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
322	1683	460	999	460999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
323	1684	732	299	732299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
324	1685	732	130	732130	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
325	1686	732	102	732102	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
326	1687	732	666	732666	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
327	1687	732	101	732101	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
328	1688	732	2	73202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
329	1689	732	187	732187	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
330	1691	732	999	732999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
331	1692	732	240	732240	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
332	1694	732	220	732220	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
333	1686	732	123	732123	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
334	1686	732	1	73201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
335	1697	732	230	732230	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
336	1698	732	199	732199	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
337	1699	732	165	732165	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
338	1699	732	103	732103	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
339	1699	732	111	732111	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
340	1701	732	142	732142	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
341	1701	732	20	73220	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
342	1703	732	154	732154	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
343	1704	732	360	732360	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
344	1705	654	299	654299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
345	1706	654	1	65401	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
346	1707	654	2	65402	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
347	1708	629	1	62901	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
348	1709	629	2	62902	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
349	1710	629	10	62910	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
350	1711	629	7	62907	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
351	1712	548	1	54801	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
352	1713	712	3	71203	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
353	1714	712	999	712999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
354	1715	712	2	71202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
355	1715	712	1	71201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
356	1716	712	4	71204	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
357	1717	712	20	71220	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
358	1718	219	10	21910	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
359	1719	219	999	219999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
360	1720	219	1	21901	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
361	1721	219	12	21912	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
362	1722	219	2	21902	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
363	1723	368	1	36801	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
364	1724	368	999	368999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
365	1725	362	95	36295	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
366	1727	362	69	36269	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
367	1728	280	22	28022	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
368	1729	280	2	28002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
369	1729	280	1	28001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
370	1730	280	10	28010	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
371	1731	280	999	280999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
372	1732	280	20	28020	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
373	1733	230	299	230299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
374	1736	230	8	23008	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
375	1740	230	999	230999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
376	1748	230	4	23004	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
377	1749	230	2	23002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
378	1751	230	5	23005	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
379	1753	230	98	23098	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
380	1754	230	7	23007	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
381	1754	230	1	23001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
382	1758	230	9	23009	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
383	1759	230	3	23003	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
384	1759	230	99	23099	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
385	1760	630	90	63090	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
386	1761	630	2	63002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
387	1762	630	299	630299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
388	1763	630	86	63086	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
389	1764	630	5	63005	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
390	1766	630	89	63089	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
391	1767	630	1	63001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
392	1768	630	88	63088	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
393	1769	238	23	23823	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
394	1770	238	15	23815	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
395	1771	238	88	23888	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
396	1772	238	13	23813	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
397	1773	238	999	238999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
398	1774	238	17	23817	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
399	1775	238	42	23842	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
400	1776	238	6	23806	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
401	1777	238	28	23828	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
402	1778	238	12	23812	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
403	1779	238	14	23814	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
404	1780	238	7	23807	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
405	1781	238	4	23804	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
406	1782	238	73	23873	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
407	1783	238	30	23830	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
408	1784	238	3	23803	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
409	1785	238	10	23810	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
410	1785	238	1	23801	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
411	1786	238	77	23877	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
412	1786	238	2	23802	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:56	2025-11-21 18:54:56	\N	\N
413	1787	238	96	23896	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
414	1787	238	20	23820	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
415	1788	238	16	23816	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
416	1789	238	25	23825	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
417	1790	238	8	23808	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
418	1791	638	1	63801	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
419	1792	366	110	366110	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
420	1793	366	20	36620	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
421	1794	366	50	36650	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
422	1795	370	2	37002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
423	1796	370	1	37001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
424	1797	370	3	37003	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
425	1798	370	4	37004	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
426	1799	514	299	514299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
427	1800	514	999	514999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
428	1801	514	3	51403	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
429	1802	514	1	51401	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
430	1803	514	2	51402	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
431	1804	740	1	74001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
432	1805	740	2	74002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
433	1806	740	0	74000	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
434	1808	740	3	74003	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
435	1809	602	3	60203	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
436	1810	602	299	602299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
437	1811	602	1	60201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
438	1812	602	2	60202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
439	1813	602	4	60204	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
440	1814	706	1	70601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
441	1815	706	2	70602	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
442	1816	706	5	70605	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
443	1817	706	4	70604	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
444	1818	706	3	70603	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
445	1819	627	299	627299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
446	1820	627	3	62703	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
447	1821	627	1	62701	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
448	1822	657	1	65701	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
449	1823	248	2	24802	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
450	1824	248	3	24803	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
451	1825	248	13	24813	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
452	1825	248	1	24801	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
453	1826	248	4	24804	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
454	1827	636	1	63601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
455	1828	750	1	75001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
456	1829	288	1	28801	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
457	1830	288	2	28802	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
458	1831	288	3	28803	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
459	1832	542	2	54202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
460	1833	542	1	54201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
461	1834	244	14	24414	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
462	1835	244	299	244299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
463	1836	244	26	24426	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
464	1838	244	3	24403	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
465	1838	244	12	24412	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
466	1838	244	13	24413	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
467	1838	244	4	24404	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
468	1839	244	21	24421	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
469	1839	244	6	24406	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
470	1839	244	5	24405	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
471	1840	244	82	24482	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
472	1845	244	11	24411	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
473	1846	244	24	24424	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
474	1847	244	41	24441	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
475	1847	244	9	24409	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
476	1847	244	8	24408	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
477	1847	244	38	24438	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
478	1847	244	39	24439	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
479	1847	244	40	24440	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
480	1847	244	7	24407	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
481	1849	244	10	24410	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
482	1850	244	43	24443	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
483	1851	244	36	24436	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
484	1851	244	91	24491	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
485	1852	244	15	24415	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
486	1853	244	37	24437	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
487	1856	244	35	24435	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
488	1845	244	42	24442	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
489	1857	244	47	24447	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
490	1857	244	46	24446	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
491	1857	244	45	24445	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
492	1857	244	33	24433	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
493	1858	244	32	24432	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
494	1859	208	299	208299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
495	1861	208	28	20828	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
496	1864	208	92	20892	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
497	1870	208	88	20888	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
498	1870	208	21	20821	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
499	1870	208	20	20820	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
500	1874	208	34	20834	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
501	1877	208	27	20827	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
502	1884	208	999	208999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
503	1886	208	36	20836	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
504	1886	208	15	20815	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
505	1886	208	14	20814	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
506	1886	208	35	20835	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
507	1886	208	16	20816	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
508	1887	208	7	20807	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
509	1887	208	6	20806	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
510	1887	208	5	20805	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
511	1888	208	94	20894	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
512	1891	208	89	20889	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
513	1893	208	29	20829	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
514	1864	208	37	20837	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
515	1901	208	38	20838	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
516	1902	208	17	20817	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
517	1905	208	25	20825	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
518	1906	208	24	20824	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
519	1906	208	3	20803	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
520	1908	208	39	20839	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
521	1910	208	26	20826	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
522	1891	208	23	20823	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
523	1893	208	1	20801	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
524	1893	208	32	20832	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
525	1893	208	91	20891	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
526	1893	208	2	20802	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
527	1915	208	10	20810	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
528	1915	208	11	20811	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
529	1915	208	13	20813	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
530	1915	208	9	20809	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
531	1915	208	8	20808	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
532	1867	208	4	20804	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
533	1919	208	30	20830	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
534	1921	208	0	20800	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
535	1923	208	22	20822	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
536	1925	208	12	20812	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
537	1928	208	31	20831	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
538	1930	340	20	34020	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
539	1931	340	1	34001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
540	1932	340	2	34002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
541	1933	340	11	34011	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
542	1933	340	3	34003	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
543	1934	547	15	54715	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
544	1935	547	20	54720	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
545	1936	628	3	62803	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
546	1937	628	4	62804	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
547	1938	628	299	628299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
548	1939	628	1	62801	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
549	1940	628	2	62802	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
550	1941	607	2	60702	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
551	1942	607	3	60703	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
552	1943	607	1	60701	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
553	1944	607	4	60704	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
554	1945	282	4	28204	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
555	1946	282	1	28201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
556	1947	282	7	28207	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
557	1948	282	3	28203	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
558	1949	282	2	28202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
559	1950	282	11	28211	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
560	1951	282	22	28222	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
561	1952	282	10	28210	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
562	1953	282	5	28205	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
563	1953	282	8	28208	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
564	1954	282	12	28212	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
565	1955	262	23	26223	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
566	1955	262	299	262299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
567	1957	262	13	26213	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
568	1958	262	10	26210	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
569	1959	262	77	26277	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
570	1959	262	20	26220	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
571	1960	262	999	262999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
572	1961	262	14	26214	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
573	1962	262	43	26243	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
574	1963	262	21	26221	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
575	1964	262	22	26222	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
576	1964	262	33	26233	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
577	1965	262	24	26224	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
578	1959	262	5	26205	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
579	1959	262	17	26217	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
580	1959	262	12	26212	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
581	1959	262	3	26203	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
582	1966	262	11	26211	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
583	1966	262	8	26208	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
584	1966	262	16	26216	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
585	1966	262	7	26207	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
586	1967	262	78	26278	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
587	1967	262	6	26206	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
588	1967	262	1	26201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
589	1970	262	9	26209	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
590	1970	262	4	26204	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
591	1970	262	2	26202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
592	1970	262	42	26242	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
593	1971	620	6	62006	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
594	1971	620	3	62003	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
595	1972	620	299	620299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
596	1973	620	4	62004	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
597	1974	620	7	62007	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
598	1975	620	1	62001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
599	1976	620	5	62005	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
600	1977	620	8	62008	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
601	1978	620	2	62002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
602	1979	266	6	26606	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
603	1980	266	9	26609	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
604	1981	266	999	266999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
605	1982	266	299	266299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
606	1983	266	1	26601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
607	1984	202	299	202299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
608	1984	202	7	20207	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
609	1986	202	15	20215	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
610	1399	202	2	20202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
611	1399	202	1	20201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
612	1987	202	14	20214	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
613	1988	202	999	202999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
614	1989	202	16	20216	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
615	1992	202	4	20204	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
616	1993	202	3	20203	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
617	1996	202	10	20210	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
618	1400	202	5	20205	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
619	1996	202	9	20209	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
620	1997	202	12	20212	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
621	1998	290	1	29001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
622	1999	352	110	352110	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
623	2000	352	30	35230	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
624	2000	352	50	35250	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
625	2001	340	8	34008	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
626	2002	310	370	310370	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
627	2002	310	470	310470	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
628	2003	310	140	310140	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
629	2004	310	33	31033	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
630	2005	310	32	31032	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:57	2025-11-21 18:54:57	\N	\N
631	2006	311	250	311250	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
632	2007	704	1	70401	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
633	2008	704	3	70403	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
634	2009	704	2	70402	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
635	2010	611	5	61105	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
636	2011	611	3	61103	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
637	2012	611	4	61104	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
638	2013	611	1	61101	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
639	2014	611	2	61102	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
640	2015	632	999	632999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
641	2016	632	1	63201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
642	2017	632	2	63202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
643	2018	632	3	63203	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
644	2019	738	2	73802	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
645	2020	738	1	73801	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
646	2021	372	1	37201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
647	2022	372	2	37202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
648	2023	372	3	37203	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
649	2024	708	40	70840	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
650	2025	708	30	70830	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
651	2026	708	1	70801	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
652	2027	708	2	70802	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
653	2028	454	12	45412	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
654	2028	454	28	45428	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
655	2028	454	13	45413	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
656	2029	454	9	45409	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
657	2030	454	7	45407	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
658	2031	454	11	45411	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
659	2032	454	1	45401	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
660	2033	454	2	45402	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
661	2033	454	0	45400	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
662	2033	454	18	45418	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
663	2034	454	10	45410	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
664	2035	454	31	45431	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
665	2036	454	14	45414	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
666	2036	454	5	45405	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
667	2036	454	4	45404	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
668	2036	454	3	45403	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
669	2037	454	20	45420	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
670	2037	454	19	45419	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
671	2037	454	29	45429	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
672	2037	454	16	45416	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
673	2038	454	47	45447	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
674	2039	454	24	45424	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
675	2038	454	40	45440	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
676	2040	454	8	45408	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
677	2041	454	17	45417	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
678	2041	454	15	45415	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
679	2041	454	6	45406	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
680	2042	216	299	216299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
681	2043	216	3	21603	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
682	2044	216	999	216999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
683	2047	216	2	21602	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
684	2050	216	30	21630	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
685	2051	216	1	21601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
686	2052	216	71	21671	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
687	2054	216	70	21670	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
688	2055	274	9	27409	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
689	2056	274	7	27407	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
690	2057	274	11	27411	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
691	2058	274	31	27431	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
692	2058	274	8	27408	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
693	2058	274	1	27401	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
694	2059	274	16	27416	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
695	2060	274	4	27404	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
696	2061	274	12	27412	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
697	2061	274	2	27402	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
698	2061	274	3	27403	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
699	2061	274	5	27405	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
700	2062	404	17	40417	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
701	2062	404	42	40442	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
702	2062	404	33	40433	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
703	2062	404	29	40429	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
704	2062	404	28	40428	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
705	2062	404	25	40425	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
706	2063	404	1	40401	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
707	2063	404	15	40415	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
708	2063	404	60	40460	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
709	2064	405	53	40553	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
710	2065	404	86	40486	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
711	2065	404	13	40413	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
712	2066	404	58	40458	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
713	2066	404	81	40481	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
714	2066	404	74	40474	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
715	2066	404	38	40438	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
716	2066	404	57	40457	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
717	2066	404	80	40480	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
718	2066	404	73	40473	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
719	2066	404	34	40434	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
720	2066	404	66	40466	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
721	2066	404	55	40455	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
722	2066	404	72	40472	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
723	2066	404	77	40477	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
724	2066	404	64	40464	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
725	2066	404	54	40454	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
726	2066	404	71	40471	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
727	2066	404	76	40476	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
728	2066	404	62	40462	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
729	2066	404	53	40453	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
730	2066	404	59	40459	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
731	2066	404	75	40475	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
732	2066	404	51	40451	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
733	2067	404	10	40410	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
734	2068	404	45	40445	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
735	2069	404	79	40479	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
736	2070	404	87	40487	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
737	2070	404	82	40482	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
738	2070	404	89	40489	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
739	2070	404	88	40488	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
740	2071	404	12	40412	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
741	2071	404	19	40419	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
742	2071	404	56	40456	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
743	2072	405	5	40505	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
744	2073	404	5	40405	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
745	2074	404	998	404998	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
746	2075	404	70	40470	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
747	2076	404	16	40416	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
748	2077	404	78	40478	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
749	2077	404	7	40407	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
750	2077	404	4	40404	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
751	2077	404	24	40424	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
752	2077	404	22	40422	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
753	2078	404	69	40469	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
754	2078	404	68	40468	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
755	2079	404	83	40483	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
756	2080	404	50	40450	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
757	2080	404	67	40467	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
758	2080	404	18	40418	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
759	2080	404	85	40485	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
760	2080	404	9	40409	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
761	2080	405	87	40587	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
762	2080	404	36	40436	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
763	2080	404	52	40452	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
764	2081	404	41	40441	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
765	2082	404	14	40414	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
766	2082	404	44	40444	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
767	2083	404	11	40411	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
768	2084	405	34	40534	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
769	2085	404	30	40430	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
770	2086	404	999	404999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
771	2087	404	27	40427	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
772	2088	404	43	40443	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
773	2087	404	20	40420	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
774	2089	510	8	51008	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
775	2090	510	99	51099	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
776	2091	510	999	510999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
777	2092	510	7	51007	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
778	2093	510	89	51089	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
779	2094	510	21	51021	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
780	2094	510	1	51001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
781	2095	510	0	51000	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
782	2096	510	27	51027	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
783	2097	510	28	51028	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
784	2097	510	9	51009	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
785	2098	510	11	51011	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
786	2099	510	10	51010	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
787	2100	901	13	90113	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
788	2101	432	999	432999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
789	2102	432	19	43219	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
790	2103	432	70	43270	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
791	2104	432	35	43235	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
792	2105	432	20	43220	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
793	2106	432	32	43232	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
794	2107	432	11	43211	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
795	2108	432	14	43214	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
796	2109	418	5	41805	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
797	2110	418	66	41866	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
798	2111	418	92	41892	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
799	2112	418	82	41882	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
800	2112	418	40	41840	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
801	2113	418	45	41845	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
802	2114	418	30	41830	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
803	2115	418	8	41808	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
804	2116	418	20	41820	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
805	2117	272	4	27204	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
806	2118	272	3	27203	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
807	2118	272	7	27207	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
808	2118	272	8	27208	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
809	2119	272	13	27213	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
810	2120	272	11	27211	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
811	2121	272	17	27217	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
812	2121	272	2	27202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
813	2121	272	5	27205	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
814	2122	272	15	27215	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
815	2123	272	1	27201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
816	2124	425	19	42519	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
817	2125	425	299	425299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
818	2126	425	23	42523	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
819	2129	425	2	42502	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
820	2131	425	8	42508	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
821	2132	425	15	42515	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
822	2133	425	77	42577	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
823	2133	425	7	42507	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
824	2134	425	13	42513	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
825	2135	425	22	42522	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
826	2136	425	1	42501	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
827	2137	425	3	42503	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
828	2137	425	12	42512	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
829	2138	425	16	42516	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
830	2141	425	17	42517	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
831	2142	425	9	42509	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
832	2143	425	14	42514	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
833	2144	222	299	222299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
834	2145	222	40	22240	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
835	2146	222	34	22234	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
836	2149	222	53	22253	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
837	2150	222	36	22236	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
838	2152	222	2	22202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
839	2153	222	42	22242	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
840	2154	222	8	22208	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
841	2155	222	999	222999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
842	2156	222	99	22299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
843	2157	222	50	22250	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
844	2158	222	77	22277	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
845	2160	222	39	22239	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
846	2161	222	35	22235	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
847	2162	222	7	22207	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
848	2163	222	54	22254	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
849	2164	222	33	22233	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
850	2165	222	0	22200	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
851	2166	222	58	22258	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
852	2167	222	30	22230	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
853	2168	222	56	22256	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
854	2169	222	43	22243	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
855	2170	222	1	22201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
856	2169	222	48	22248	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
857	2172	222	44	22244	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
858	2173	222	51	22251	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
859	2174	222	49	22249	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
860	2175	222	10	22210	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
861	2175	222	6	22206	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
862	2179	222	88	22288	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
863	2156	222	37	22237	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
864	2180	612	7	61207	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
865	2181	612	4	61204	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
866	2182	612	1	61201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
867	2183	612	2	61202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
868	2184	612	5	61205	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
869	2185	612	3	61203	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
870	2186	612	6	61206	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
871	2187	338	20	33820	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
872	2187	338	110	338110	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
873	2187	338	180	338180	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
874	2188	338	50	33850	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
875	2189	440	0	44000	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
876	2190	440	89	44089	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
877	2190	440	51	44051	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
878	2190	440	75	44075	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
879	2190	440	70	44070	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
880	2190	440	56	44056	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
881	2190	441	70	44170	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
882	2190	440	52	44052	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
883	2190	440	76	44076	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
884	2190	440	71	44071	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
885	2190	440	53	44053	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
886	2190	440	77	44077	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
887	2190	440	8	44008	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
888	2190	440	72	44072	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
889	2190	440	54	44054	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
890	2190	440	79	44079	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
891	2190	440	7	44007	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
892	2190	440	73	44073	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
893	2190	440	55	44055	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
894	2190	440	88	44088	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
895	2190	440	50	44050	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
896	2190	440	74	44074	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
897	2191	440	2	44002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
898	2191	440	22	44022	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
899	2191	441	43	44143	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
900	2191	440	27	44027	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
901	2191	440	87	44087	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
902	2191	440	17	44017	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
903	2191	440	31	44031	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
904	2191	440	65	44065	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
905	2191	440	36	44036	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
906	2191	441	92	44192	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
907	2191	440	3	44003	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
908	2191	440	12	44012	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
909	2191	440	58	44058	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
910	2191	440	28	44028	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
911	2191	440	61	44061	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
912	2191	440	18	44018	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
913	2191	441	91	44191	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
914	2191	440	32	44032	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
915	2191	440	66	44066	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
916	2191	440	35	44035	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
917	2191	441	93	44193	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
918	2191	441	40	44140	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
919	2191	440	9	44009	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
920	2191	440	49	44049	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
921	2191	440	29	44029	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
922	2191	440	60	44060	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
923	2191	440	19	44019	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
924	2191	441	90	44190	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
925	2191	440	33	44033	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
926	2191	440	67	44067	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
927	2191	440	14	44014	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
928	2191	441	94	44194	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
929	2191	441	41	44141	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
930	2191	440	10	44010	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
931	2191	440	62	44062	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
932	2191	440	39	44039	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
933	2191	440	30	44030	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
934	2191	441	45	44145	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
935	2191	440	1	44001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
936	2191	440	24	44024	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
937	2191	440	68	44068	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
938	2191	440	15	44015	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
939	2191	441	98	44198	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
940	2191	441	42	44142	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
941	2191	440	11	44011	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
942	2191	440	63	44063	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
943	2191	440	38	44038	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
944	2191	440	26	44026	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
945	2191	440	23	44023	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:58	2025-11-21 18:54:58	\N	\N
946	2191	440	21	44021	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
947	2191	441	44	44144	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
948	2191	440	13	44013	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
949	2191	440	69	44069	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
950	2191	440	16	44016	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
951	2191	441	99	44199	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
952	2191	440	34	44034	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
953	2191	440	64	44064	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
954	2191	440	37	44037	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
955	2191	440	25	44025	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
956	2191	440	99	44099	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
957	2192	440	78	44078	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
958	2194	440	20	44020	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
959	2194	440	5	44005	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
960	2194	440	94	44094	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
961	2194	440	46	44046	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
962	2194	440	97	44097	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
963	2194	440	42	44042	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
964	2194	441	65	44165	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
965	2194	440	90	44090	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
966	2194	440	96	44096	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
967	2194	440	92	44092	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
968	2194	440	98	44098	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
969	2194	440	43	44043	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
970	2194	440	48	44048	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
971	2194	440	6	44006	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
972	2194	441	61	44161	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
973	2194	440	44	44044	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
974	2194	440	4	44004	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
975	2194	441	62	44162	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
976	2194	440	45	44045	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
977	2194	440	40	44040	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
978	2194	441	63	44163	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
979	2194	440	93	44093	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
980	2194	440	47	44047	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
981	2194	440	95	44095	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
982	2194	440	41	44041	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
983	2194	441	64	44164	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
984	2190	440	85	44085	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
985	2190	440	83	44083	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
986	2190	440	80	44080	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
987	2190	440	86	44086	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
988	2190	440	81	44081	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
989	2190	440	84	44084	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
990	2190	440	82	44082	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
991	2195	416	999	416999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
992	2196	416	77	41677	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
993	2197	416	3	41603	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
994	2198	416	2	41602	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
995	2199	416	1	41601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
996	2200	401	1	40101	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
997	2201	401	7	40107	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
998	2202	401	2	40102	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
999	2203	401	77	40177	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1000	2204	639	3	63903	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1001	2204	639	5	63905	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1002	2205	639	299	639299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1003	2206	639	6	63906	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1004	2207	639	9	63909	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1005	2208	639	12	63912	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1006	2209	639	11	63911	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1007	2210	639	10	63910	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1008	2211	639	4	63904	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1009	2212	639	1	63901	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1010	2212	639	2	63902	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1011	2213	639	7	63907	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1012	2214	545	9	54509	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1013	2215	221	7	22107	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1014	2216	221	6	22106	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1015	2217	221	2	22102	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1016	2218	221	299	221299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1017	2218	221	3	22103	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1018	2219	221	1	22101	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1019	2220	419	999	419999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1020	2221	419	2	41902	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1021	2222	419	4	41904	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1022	2223	419	3	41903	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1023	2224	437	1	43701	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1024	2225	437	299	437299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1025	2226	437	2	43702	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1026	2227	437	5	43705	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1027	2228	437	9	43709	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1028	2229	437	10	43710	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1029	2230	437	3	43703	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1030	2231	457	2	45702	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1031	2232	457	1	45701	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1032	2233	457	8	45708	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1033	2234	457	3	45703	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1034	2235	247	5	24705	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1035	2236	247	10	24710	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1036	2236	247	1	24701	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1037	2237	247	299	247299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1038	2238	247	7	24707	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1039	2239	247	6	24706	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1040	2240	247	2	24702	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1041	2241	247	4	24704	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1042	2242	247	3	24703	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1043	2243	247	8	24708	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1044	2244	247	9	24709	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1045	2245	415	35	41535	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1046	2245	415	33	41533	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1047	2245	415	32	41532	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1048	2246	415	34	41534	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1049	2247	415	39	41539	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1050	2247	415	38	41538	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1051	2247	415	37	41537	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1052	2248	415	1	41501	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1053	2247	415	3	41503	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1054	2247	415	36	41536	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1055	2249	651	2	65102	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1056	2250	651	1	65101	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1057	2251	618	2	61802	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1058	2252	618	20	61820	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1059	2253	618	1	61801	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1060	2254	618	4	61804	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1061	2255	618	7	61807	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1062	2256	606	2	60602	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1063	2256	606	1	60601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1064	2257	606	6	60606	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1065	2258	606	0	60600	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1066	2259	606	3	60603	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1067	2260	295	2	29502	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1068	2261	295	6	29506	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1069	2262	295	299	295299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1070	2264	295	9	29509	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1071	2265	295	7	29507	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1072	2266	295	1	29501	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1073	2267	295	5	29505	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1074	2269	295	77	29577	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1075	2271	246	2	24602	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1076	2272	246	5	24605	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1077	2273	246	6	24606	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1078	2274	246	299	246299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1079	2275	246	3	24603	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1080	2277	246	1	24601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1081	2278	270	10	27010	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1082	2279	270	299	270299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1083	2280	270	81	27081	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1084	2282	270	999	270999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1085	2283	270	5	27005	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1086	2285	270	99	27099	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1087	2286	270	1	27001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1088	2287	270	77	27077	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1089	2288	455	1	45501	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1090	2288	455	4	45504	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1091	2289	455	2	45502	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1092	2290	455	5	45505	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1093	2290	455	3	45503	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1094	2291	455	6	45506	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1095	2291	455	0	45500	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1096	2292	646	1	64601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1097	2293	646	299	646299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1098	2294	646	2	64602	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1099	2295	646	3	64603	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1100	2296	646	4	64604	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1101	2297	650	10	65010	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1102	2298	650	1	65001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1103	2299	502	156	502156	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1104	2300	502	1	50201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1105	2301	502	14	50214	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1106	2301	502	11	50211	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1107	2302	502	151	502151	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1108	2303	502	19	50219	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1109	2303	502	13	50213	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1110	2303	502	198	502198	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1111	2304	502	10	50210	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1112	2304	502	16	50216	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1113	2305	502	20	50220	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1114	2306	502	999	502999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1115	2307	502	299	502299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1116	2308	502	17	50217	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1117	2308	502	12	50212	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1118	2313	502	155	502155	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1119	2314	502	154	502154	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1120	2315	502	150	502150	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1121	2316	502	18	50218	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1122	2317	502	153	502153	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1123	2318	502	195	502195	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1124	2320	502	152	502152	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1125	2321	472	1	47201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1126	2322	472	2	47202	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1127	2323	610	1	61001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1128	2324	610	2	61002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1129	2325	610	3	61003	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1130	2326	278	1	27801	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1131	2327	278	999	278999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1132	2328	278	21	27821	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1133	2328	278	30	27830	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1134	2329	278	77	27877	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1135	2330	551	299	551299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1136	2332	340	12	34012	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1137	2333	609	2	60902	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1138	2334	609	1	60901	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1139	2335	609	10	60910	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1140	2336	617	3	61703	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1141	2336	617	2	61702	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1142	2337	617	10	61710	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1143	2338	617	1	61701	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1144	2339	647	1	64701	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1145	2340	647	10	64710	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1146	2341	334	50	33450	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1147	2341	334	40	33440	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1148	2341	334	5	33405	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1149	2341	334	4	33404	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1150	2342	334	3	33403	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1151	2342	334	30	33430	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1152	2343	334	90	33490	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1153	2343	334	10	33410	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1154	2343	334	1	33401	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1155	2343	334	9	33409	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1156	2344	334	70	33470	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1157	2344	334	80	33480	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1158	2345	334	60	33460	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1159	2346	334	20	33420	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1160	2346	334	2	33402	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1161	2347	550	1	55001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1162	2348	259	4	25904	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1163	2349	259	3	25903	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1164	2350	259	2	25902	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1165	2351	259	1	25901	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1166	2349	259	99	25999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1167	2349	259	5	25905	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1168	2352	212	10	21210	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1169	2352	212	1	21201	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1170	2353	428	98	42898	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1171	2354	428	99	42899	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1172	2355	428	91	42891	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1173	2355	428	0	42800	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1174	2356	428	88	42888	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1175	2357	297	3	29703	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1176	2358	297	2	29702	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1177	2359	297	1	29701	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1178	2360	354	860	354860	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1179	2361	604	4	60404	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1180	2361	604	99	60499	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1181	2362	604	1	60401	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1182	2362	604	6	60406	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1183	2363	604	2	60402	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1184	2363	604	5	60405	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1185	2364	604	0	60400	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1186	2365	643	3	64303	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1187	2366	643	1	64301	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1188	2367	643	4	64304	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1189	2368	414	999	414999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1190	2369	414	1	41401	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1191	2370	414	9	41409	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1192	2371	414	5	41405	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1193	2372	414	6	41406	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1194	2373	649	299	649299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1195	2374	649	1	64901	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1196	2375	649	2	64902	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1197	2376	649	3	64903	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1198	2377	429	999	429999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1199	2378	429	2	42902	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1200	2379	429	1	42901	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1201	2380	429	4	42904	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1202	2381	204	14	20414	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1203	2382	204	299	204299	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1204	2384	204	30	20430	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1205	2390	204	5	20405	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1206	2392	204	999	204999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1207	2394	204	17	20417	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1208	2395	204	0	20400	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1209	2397	204	23	20423	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1210	1403	204	8	20408	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1211	1403	204	10	20410	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1212	1403	204	69	20469	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1213	1403	204	12	20412	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1214	2399	204	27	20427	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1215	2400	204	28	20428	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1216	2400	204	98	20498	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1217	2401	204	9	20409	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1218	2402	204	63	20463	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1219	2405	204	7	20407	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1220	2406	204	6	20406	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1221	2409	204	24	20424	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1222	2410	204	21	20421	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1223	2412	204	26	20426	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1224	2413	204	2	20402	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1225	2413	204	20	20420	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1226	2413	204	16	20416	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1227	2416	204	29	20429	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1228	2417	204	33	20433	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1229	2418	204	68	20468	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1230	1402	204	4	20404	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1231	2419	204	3	20403	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1232	2420	204	15	20415	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1233	2421	204	18	20418	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1234	2422	362	630	362630	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1235	2423	362	51	36251	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1236	2424	362	91	36291	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1237	2425	362	951	362951	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1238	2426	546	1	54601	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1239	2427	530	28	53028	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1240	2428	530	999	530999	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1241	2429	530	5	53005	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1242	2429	530	2	53002	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1243	2430	530	4	53004	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1244	2427	530	24	53024	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1245	2431	530	1	53001	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1246	2432	530	3	53003	f	\N	\N	import:itu	import:itu	2025-11-21 18:54:59	2025-11-21 18:54:59	\N	\N
1251	2437	614	2	61402	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1252	2438	614	3	61403	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1253	2439	614	1	61401	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1254	2440	614	4	61404	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1255	2441	621	60	62160	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1256	2442	621	20	62120	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1257	2443	621	299	621299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1258	2444	621	50	62150	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1259	2445	621	30	62130	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1260	2446	621	40	62140	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1261	2447	621	27	62127	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1262	2448	621	99	62199	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1263	2449	621	1	62101	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1264	2449	621	25	62125	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1265	2451	555	1	55501	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1266	2452	467	299	467299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1267	2454	467	192	467192	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1268	2455	467	193	467193	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1269	2456	294	2	29402	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1270	2456	294	3	29403	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1271	2456	294	75	29475	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1272	2457	294	299	294299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1273	2459	294	4	29404	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1274	2460	294	11	29411	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1275	2462	294	1	29401	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1276	2464	242	22	24222	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1277	2465	242	21	24221	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1278	2465	242	20	24220	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1279	2466	242	299	242299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1280	2468	242	9	24209	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1281	2469	242	15	24215	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1282	2470	242	999	242999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1283	2473	242	14	24214	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1284	2475	242	16	24216	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1285	2477	242	23	24223	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1286	2478	242	5	24205	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1287	2480	242	10	24210	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1288	2473	242	6	24206	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1289	2485	242	8	24208	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1290	2487	242	4	24204	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1291	2488	242	12	24212	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1292	2488	242	1	24201	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1293	2489	242	3	24203	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1294	2490	242	2	24202	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1295	2492	242	17	24217	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1296	2492	242	7	24207	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1297	2493	422	3	42203	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1298	2494	422	2	42202	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1299	2495	410	299	410299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1300	2496	410	8	41008	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1301	2497	410	1	41001	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1302	2497	410	7	41007	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1303	2498	410	5	41005	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1304	2499	410	6	41006	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1305	2500	410	3	41003	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1306	2502	410	4	41004	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1307	2503	552	80	55280	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1308	2504	552	1	55201	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1309	2505	552	2	55202	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1310	2506	425	5	42505	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1311	2507	425	6	42506	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1312	2508	714	1	71401	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1313	2509	714	3	71403	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1314	2510	714	4	71404	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1315	2511	714	999	714999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1316	2512	714	20	71420	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1317	2512	714	2	71402	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1318	2513	537	3	53703	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1319	2514	537	999	537999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1320	2515	537	2	53702	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1321	2516	537	1	53701	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1322	2517	744	2	74402	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1323	2518	744	3	74403	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1324	2519	744	1	74401	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1325	2520	744	5	74405	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1326	2521	744	4	74404	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1327	2522	716	20	71620	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1328	2522	716	10	71610	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1329	2523	716	2	71602	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1330	2523	716	1	71601	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1331	2524	716	6	71606	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1332	2525	716	7	71607	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1333	2525	716	17	71617	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1334	2526	716	15	71615	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1335	2527	515	999	515999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1336	2528	515	2	51502	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1337	2528	515	1	51501	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1338	2529	515	88	51588	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1339	2530	515	18	51518	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1340	2531	515	3	51503	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1341	2532	515	5	51505	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1342	2533	260	299	260299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1343	2534	260	4	26004	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1344	2534	260	16	26016	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1345	2534	260	15	26015	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1346	2534	260	17	26017	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1347	2536	260	48	26048	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1348	2537	260	18	26018	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1349	2540	260	38	26038	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1350	2543	260	32	26032	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1351	2544	260	12	26012	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1352	2545	260	8	26008	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1353	2546	260	41	26041	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1354	2547	260	999	260999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1355	2555	260	9	26009	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1356	2556	260	49	26049	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1357	2560	260	42	26042	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1358	2563	260	13	26013	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1359	2565	260	36	26036	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1360	2569	260	19	26019	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1361	2570	260	7	26007	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1362	2573	260	11	26011	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1363	2574	260	27	26027	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1364	2575	260	3	26003	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1365	2575	260	5	26005	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1366	2576	260	35	26035	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1367	2577	260	98	26098	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1368	2577	260	6	26006	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1369	2578	260	1	26001	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1370	2579	260	97	26097	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1371	2580	260	90	26090	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1372	2563	260	14	26014	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1373	2586	260	47	26047	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1374	2588	260	34	26034	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1375	2588	260	2	26002	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1376	2588	260	10	26010	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1377	2594	260	20	26020	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1378	2596	260	22	26022	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1379	2599	260	45	26045	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1380	2601	260	39	26039	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1381	2602	268	999	268999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1382	2603	268	4	26804	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1383	2604	268	80	26880	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1384	2604	268	8	26808	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1385	2604	268	6	26806	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1386	2605	268	3	26803	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1387	2605	268	93	26893	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1388	2606	268	299	268299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1389	2605	268	7	26807	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1390	2608	268	91	26891	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1391	2608	268	1	26801	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1392	2609	330	11	33011	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1393	2609	330	110	330110	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1394	2610	427	1	42701	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1395	2611	427	2	42702	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1396	2612	647	3	64703	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1397	2612	647	2	64702	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1398	2613	647	0	64700	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1399	2615	647	4	64704	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1400	2616	226	5	22605	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1401	2617	226	11	22611	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1402	2618	226	299	226299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1403	2619	226	16	22616	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1404	2620	226	10	22610	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1405	2621	226	2	22602	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1406	2622	226	3	22603	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1407	2623	226	6	22606	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1408	2624	226	1	22601	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1409	2623	226	4	22604	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1410	2625	250	299	250299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1411	2632	250	99	25099	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1412	2633	250	28	25028	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1413	2639	250	10	25010	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1414	2644	250	999	250999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1415	2646	250	48	25048	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1416	2647	250	55	25055	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1417	2652	250	34	25034	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1418	2653	250	13	25013	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1419	2656	250	54	25054	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1420	2658	250	57	25057	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1421	2660	250	2	25002	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1422	2665	250	35	25035	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1423	2667	250	1	25001	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1424	2668	250	42	25042	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1425	2669	250	3	25003	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1426	2673	250	16	25016	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1427	2675	250	19	25019	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1428	2679	250	92	25092	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1429	2684	250	33	25033	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1430	2685	250	4	25004	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1431	2689	250	9	25009	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1432	2694	250	44	25044	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1433	2699	250	20	25020	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1434	2699	250	12	25012	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1435	2701	250	93	25093	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1436	2712	250	39	25039	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1437	2712	250	17	25017	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1438	2647	250	77	25077	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1439	2717	250	60	25060	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1440	2719	250	32	25032	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1441	2700	250	5	25005	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1442	2720	250	11	25011	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1443	2721	250	15	25015	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1444	2721	250	7	25007	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1445	2722	635	13	63513	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1446	2722	635	14	63514	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1447	2723	635	10	63510	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1448	2724	658	299	658299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1449	2725	356	110	356110	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1450	2726	356	50	35650	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1451	2727	356	70	35670	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1452	2728	358	110	358110	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1453	2729	358	30	35830	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1454	2730	358	50	35850	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1455	2731	308	1	30801	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1456	2732	360	110	360110	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1457	2733	360	10	36010	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1458	2733	360	100	360100	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1459	2734	360	50	36050	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1460	2734	360	70	36070	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1461	2735	549	999	549999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1462	2736	549	27	54927	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1463	2737	549	1	54901	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1464	2738	292	1	29201	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1465	2739	292	299	292299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1466	2740	626	1	62601	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1467	2741	626	2	62602	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1468	2742	901	14	90114	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1469	2743	901	11	90111	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1470	2744	901	12	90112	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1471	2745	901	5	90105	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1472	2746	420	7	42007	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1473	2747	420	3	42003	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1474	2748	420	6	42006	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1475	2749	420	1	42001	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1476	2750	420	5	42005	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1477	2746	420	4	42004	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1478	2751	608	299	608299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1479	2752	608	3	60803	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1480	2753	608	2	60802	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1481	2754	608	4	60804	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1482	2755	608	1	60801	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1483	2757	220	299	220299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1484	2758	220	11	22011	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1485	2759	220	3	22003	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1486	2760	220	1	22001	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1487	2760	220	2	22002	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1488	2761	220	5	22005	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1489	2761	220	20	22020	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1490	2762	633	10	63310	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1491	2763	633	1	63301	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1492	2764	633	5	63305	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1493	2765	633	2	63302	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1494	2766	619	3	61903	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1495	2767	619	4	61904	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1496	2768	619	299	619299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1497	2766	619	5	61905	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1498	2769	619	2	61902	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1499	2770	619	25	61925	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1500	2772	619	1	61901	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1501	2773	619	7	61907	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:00	2025-11-21 18:55:00	\N	\N
1502	2775	525	999	525999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1503	2776	525	12	52512	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1504	2777	525	3	52503	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1505	2778	525	2	52502	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1506	2778	525	1	52501	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1507	2778	525	7	52507	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1508	2779	525	6	52506	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1509	2779	525	5	52505	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1510	2780	231	6	23106	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1511	2781	231	5	23105	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1512	2781	231	7	23107	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1513	2781	231	1	23101	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1514	2781	231	15	23115	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1515	2782	231	3	23103	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1516	2783	231	2	23102	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1517	2783	231	4	23104	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1518	2783	231	50	23150	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1519	2784	231	8	23108	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1520	2785	231	299	231299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1521	2786	231	99	23199	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1522	2787	293	40	29340	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1523	2788	293	20	29320	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1524	2789	293	86	29386	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1525	2790	293	999	293999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1526	2791	293	299	293299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1527	2793	293	41	29341	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1528	2795	293	10	29310	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1529	2797	293	64	29364	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1530	2798	293	70	29370	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1531	2799	540	2	54002	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1532	2800	540	10	54010	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1533	2800	540	1	54001	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1534	2801	637	299	637299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1535	2802	637	30	63730	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1536	2803	637	19	63719	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1537	2803	637	50	63750	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1538	2804	637	60	63760	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1539	2804	637	10	63710	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1540	2806	637	70	63770	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1541	2807	637	4	63704	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1542	2809	637	71	63771	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1543	2811	637	82	63782	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1544	2812	637	1	63701	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1545	2813	655	21	65521	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1546	2814	655	7	65507	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1547	2815	655	299	655299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1548	2816	655	10	65510	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1549	2816	655	12	65512	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1550	2817	655	38	65538	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1551	2817	655	19	65519	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1552	2817	655	73	65573	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1553	2817	655	74	65574	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1554	2818	655	6	65506	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1555	2819	655	2	65502	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1556	2819	655	5	65505	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1557	2820	655	1	65501	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1558	2821	450	299	450299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1559	2822	450	2	45002	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1560	2823	450	7	45007	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1561	2824	450	6	45006	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1562	2822	450	8	45008	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1563	2822	450	4	45004	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1564	2825	450	3	45003	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1565	2825	450	5	45005	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1566	2825	450	12	45012	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1567	2825	450	11	45011	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1568	2826	659	299	659299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1569	2828	659	3	65903	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1570	2829	659	2	65902	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1571	2830	659	4	65904	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1572	2831	659	6	65906	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1573	2832	214	299	214299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1574	2834	214	36	21436	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1575	2835	214	2	21402	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1576	2837	214	14	21414	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1577	2838	214	22	21422	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1578	2841	214	15	21415	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1579	2842	214	18	21418	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1580	2846	214	8	21408	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1581	2848	214	999	214999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1582	2849	214	20	21420	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1583	2852	214	32	21432	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1584	2852	214	34	21434	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1585	2853	214	21	21421	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1586	2856	214	26	21426	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1587	2857	214	25	21425	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1588	2858	214	17	21417	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1589	2859	214	38	21438	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1590	2859	214	7	21407	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1591	2859	214	5	21405	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1592	2864	214	11	21411	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1593	2864	214	3	21403	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1594	2864	214	9	21409	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1595	2871	214	19	21419	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1596	2872	214	35	21435	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1597	2858	214	16	21416	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1598	2877	214	27	21427	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1599	2878	214	12	21412	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1600	2879	214	1	21401	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1601	2879	214	37	21437	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1602	2879	214	6	21406	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1603	2880	214	29	21429	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1604	2880	214	4	21404	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1605	2880	214	23	21423	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1606	2880	214	33	21433	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1607	2882	214	10	21410	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1608	2883	413	5	41305	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1609	2884	413	3	41303	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1610	2885	413	8	41308	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1611	2886	413	1	41301	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1612	2887	413	2	41302	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1613	2888	634	0	63400	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1614	2889	634	999	634999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1615	2890	634	22	63422	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1616	2890	634	3	63403	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1617	2890	634	2	63402	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1618	2891	634	7	63407	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1619	2891	634	15	63415	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1620	2888	634	5	63405	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1621	2888	634	8	63408	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1622	2892	634	1	63401	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1623	2892	634	6	63406	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1624	2893	746	3	74603	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1625	2894	746	999	746999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1626	2895	746	1	74601	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1627	2896	746	2	74602	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1628	2897	746	4	74604	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1629	2898	653	2	65302	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1630	2899	653	1	65301	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1631	2900	653	10	65310	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1632	2901	240	16	24016	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1633	2902	240	35	24035	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1634	2903	240	13	24013	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1635	2904	240	30	24030	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1636	2905	240	11	24011	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1637	2906	240	9	24009	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1638	2907	240	32	24032	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1639	2908	240	22	24022	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1640	2909	240	63	24063	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1641	2910	240	999	240999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1642	2911	240	18	24018	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1643	2912	240	27	24027	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1644	2913	240	17	24017	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1645	2914	240	2	24002	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1646	2915	240	23	24023	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1647	2916	240	36	24036	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1648	2917	240	28	24028	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1649	2918	240	12	24012	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1650	2919	240	29	24029	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1651	2920	240	33	24033	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1652	2921	240	43	24043	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1653	2922	240	25	24025	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1654	2923	240	40	24040	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1655	2924	240	39	24039	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1656	2925	240	31	24031	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1657	2926	240	20	24020	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1658	2927	240	15	24015	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1659	2928	240	37	24037	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1660	2929	240	45	24045	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1661	2930	240	10	24010	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1662	2931	240	7	24007	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1663	2931	240	5	24005	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1664	2931	240	14	24014	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1665	2932	240	44	24044	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1666	2933	240	24	24024	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1667	2933	240	6	24006	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1668	2934	240	42	24042	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1669	2933	240	8	24008	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1670	2933	240	4	24004	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1671	2935	240	1	24001	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1672	2936	240	3	24003	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1673	2937	240	48	24048	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1674	2938	240	21	24021	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1675	2939	240	26	24026	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1676	2940	240	19	24019	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1677	2941	240	46	24046	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1678	2942	240	47	24047	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1679	2943	240	38	24038	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1680	2944	228	58	22858	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1681	2945	228	9	22809	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1682	2945	228	5	22805	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1683	2946	228	999	228999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1684	2947	228	7	22807	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1685	2948	228	66	22866	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1686	2949	228	54	22854	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1687	2950	228	69	22869	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1688	2951	228	52	22852	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1689	2952	228	65	22865	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1690	2953	228	51	22851	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1691	2954	228	3	22803	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1692	2955	228	6	22806	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1693	2947	228	53	22853	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1694	2947	228	12	22812	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1695	2947	228	8	22808	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1696	2947	228	2	22802	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1697	2947	228	60	22860	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1698	2956	228	1	22801	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1699	2957	228	62	22862	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1700	2958	228	70	22870	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1701	2960	228	59	22859	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1702	2961	417	2	41702	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1703	2962	417	9	41709	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1704	2962	417	1	41701	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1705	2963	466	68	46668	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1706	2964	466	5	46605	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1707	2965	466	11	46611	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1708	2965	466	92	46692	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1709	2966	466	2	46602	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1710	2966	466	7	46607	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1711	2966	466	6	46606	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1712	2966	466	3	46603	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1713	2966	466	1	46601	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1714	2967	466	10	46610	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1715	2968	466	56	46656	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1716	2969	466	88	46688	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1717	2970	466	90	46690	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:01	2025-11-21 18:55:01	\N	\N
1718	2971	466	99	46699	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1719	2972	466	97	46697	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1720	2973	466	93	46693	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1721	2970	466	89	46689	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1722	2974	466	9	46609	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1723	2975	436	4	43604	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1724	2976	436	5	43605	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1725	2977	436	2	43602	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1726	2978	436	12	43612	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1727	2979	436	3	43603	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1728	2978	436	1	43601	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1729	2980	640	5	64005	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1730	2981	640	8	64008	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1731	2982	640	6	64006	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1732	2983	640	9	64009	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1733	2984	640	99	64099	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1734	2985	640	14	64014	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1735	2986	640	11	64011	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1736	2987	640	7	64007	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1737	2988	640	2	64002	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1738	2989	640	1	64001	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1739	2990	640	4	64004	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1740	2991	640	13	64013	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1741	2992	640	3	64003	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1742	2993	520	20	52020	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1743	2994	520	15	52015	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1744	2995	520	3	52003	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1745	2995	520	1	52001	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1746	2996	520	23	52023	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1747	2997	520	999	520999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1748	2998	520	0	52000	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1749	2999	520	5	52005	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1750	2999	520	18	52018	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1751	3000	520	4	52004	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1752	3000	520	99	52099	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1753	3001	615	3	61503	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1754	3002	615	2	61502	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1755	3003	615	1	61501	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1756	3004	539	88	53988	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1757	3005	539	999	539999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1758	3006	539	43	53943	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1759	3007	539	1	53901	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1760	3008	374	12	37412	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1761	3008	374	120	374120	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1762	3009	374	130	374130	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1763	3010	374	140	374140	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1764	3011	605	999	605999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1765	3012	605	6	60506	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1766	3013	605	3	60503	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1767	3014	605	1	60501	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1768	3015	605	2	60502	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1769	3016	286	299	286299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1770	3017	286	4	28604	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1771	3017	286	3	28603	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1772	3021	286	999	286999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1773	3036	286	1	28601	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1774	3037	286	2	28602	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1775	3038	438	1	43801	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1776	3039	438	2	43802	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1777	3040	376	350	376350	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1778	3041	376	50	37650	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1779	3042	376	352	376352	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1780	3043	553	1	55301	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1781	3044	641	1	64101	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1782	3044	641	22	64122	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1783	3045	641	999	641999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1784	3046	641	66	64166	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1785	3047	641	30	64130	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1786	3048	641	4	64104	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1787	3049	641	11	64111	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1788	3050	641	10	64110	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1789	3051	641	14	64114	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1790	3052	641	33	64133	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1791	3053	641	18	64118	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1792	3054	255	7	25507	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1793	3055	255	5	25505	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1794	3055	255	39	25539	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1795	3056	255	4	25504	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1796	3057	255	67	25567	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1797	3057	255	2	25502	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1798	3057	255	3	25503	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1799	3058	255	6	25506	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1800	3059	255	21	25521	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1801	3060	255	99	25599	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1802	3061	255	50	25550	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1803	3061	255	1	25501	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1804	3057	255	68	25568	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1805	3062	424	3	42403	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1806	3063	424	2	42402	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1807	3063	431	2	43102	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1808	3063	430	2	43002	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1809	3064	234	99	23499	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1810	3067	234	78	23478	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1811	3070	234	29	23429	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1812	3074	234	76	23476	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1813	3074	234	0	23400	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1814	3075	234	8	23408	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1815	3078	234	18	23418	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1816	3085	235	2	23502	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1817	3086	234	32	23432	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1818	3086	234	31	23431	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1819	3086	234	30	23430	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1820	3087	234	999	234999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1821	3088	234	17	23417	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1822	3089	234	4	23404	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1823	3091	234	39	23439	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1824	3093	234	24	23424	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1825	3094	234	72	23472	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1826	3095	234	71	23471	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1827	3096	234	20	23420	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1828	3096	234	94	23494	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1829	3097	234	23	23423	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1830	3100	234	3	23403	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1831	3101	234	35	23435	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1832	3102	234	50	23450	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1833	3105	234	14	23414	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1834	3107	234	26	23426	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1835	3109	234	58	23458	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1836	3110	234	28	23428	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1837	3112	234	75	23475	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1838	3114	234	56	23456	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1839	3115	234	95	23495	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1840	3115	234	12	23412	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1841	3115	234	13	23413	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1842	3117	234	51	23451	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1843	3119	234	34	23434	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1844	3119	234	33	23433	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1845	3120	234	74	23474	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1846	3126	234	57	23457	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1847	3129	234	40	23440	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1848	3130	234	55	23455	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1849	3131	234	36	23436	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1850	3134	234	37	23437	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1851	3135	234	16	23416	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1852	3137	234	27	23427	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1853	3141	234	2	23402	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1854	3141	234	11	23411	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1855	3141	234	10	23410	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1856	3142	234	22	23422	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1857	3143	234	19	23419	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1858	3146	234	9	23409	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1859	3147	234	25	23425	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1860	3148	234	1	23401	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1861	3149	234	998	234998	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1862	3149	234	38	23438	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1863	3140	234	7	23407	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1864	3140	234	92	23492	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1865	3140	234	89	23489	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1866	3140	234	15	23415	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1867	3140	234	91	23491	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1868	3140	234	77	23477	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1869	3152	310	850	310850	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1870	3153	310	510	310510	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1871	3154	310	190	310190	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1872	3155	312	90	31290	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1873	3156	310	710	310710	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1874	3157	310	410	310410	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1875	3157	310	380	310380	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1876	3157	310	170	310170	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1877	3157	310	150	310150	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1878	3157	310	680	310680	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1879	3157	310	70	31070	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1880	3157	310	560	310560	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1881	3157	310	980	310980	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1882	3158	311	810	311810	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1883	3158	311	800	311800	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1884	3158	311	440	311440	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1885	3159	310	900	310900	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1886	3160	311	590	311590	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1887	3161	311	500	311500	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1888	3162	310	830	310830	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1889	3163	311	483	311483	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1890	3163	311	110	311110	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1891	3163	311	285	311285	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1892	3163	311	488	311488	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1893	3163	311	274	311274	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1894	3163	310	10	31010	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1895	3163	311	279	311279	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1896	3163	311	288	311288	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1897	3163	310	910	310910	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:02	2025-11-21 18:55:02	\N	\N
1898	3163	311	284	311284	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1899	3163	311	482	311482	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1900	3163	311	487	311487	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1901	3163	311	273	311273	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1902	3163	310	4	31004	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1903	3163	311	278	311278	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1904	3163	311	287	311287	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1905	3163	310	890	310890	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1906	3163	311	283	311283	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1907	3163	311	481	311481	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1908	3163	311	486	311486	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1909	3163	311	272	311272	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1910	3163	311	277	311277	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1911	3163	310	590	310590	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1912	3163	311	282	311282	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1913	3163	311	480	311480	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1914	3163	311	485	311485	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1915	3163	311	271	311271	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1916	3163	311	276	311276	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1917	3163	310	13	31013	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1918	3163	311	281	311281	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1919	3163	311	390	311390	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1920	3163	311	484	311484	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1921	3163	311	270	311270	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1922	3163	311	286	311286	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1923	3163	311	489	311489	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1924	3163	311	275	311275	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1925	3163	310	12	31012	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1926	3163	311	280	311280	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1927	3163	311	289	311289	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1928	3164	312	280	312280	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1929	3164	312	270	312270	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1930	3164	310	360	310360	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1931	3165	311	120	311120	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1932	3165	310	480	310480	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1933	3166	310	420	310420	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1934	3167	310	180	310180	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1935	3168	310	620	310620	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1936	3169	310	6	31006	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1937	3169	310	60	31060	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1938	3170	310	700	310700	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1939	3171	312	30	31230	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1940	3171	311	140	311140	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1941	3172	312	40	31240	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1942	3173	310	440	310440	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1943	3174	310	990	310990	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1944	3175	312	130	312130	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1945	3175	312	120	312120	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1946	3175	310	750	310750	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1947	3176	310	90	31090	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1948	3177	310	610	310610	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1949	3178	311	311	311311	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1950	3179	311	460	311460	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1951	3180	311	370	311370	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1952	3180	310	430	310430	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1953	3181	310	920	310920	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1954	3182	311	340	311340	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1955	3183	312	170	312170	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1956	3183	311	410	311410	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1957	3184	310	770	310770	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1958	3185	310	650	310650	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1959	3186	310	870	310870	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1960	3187	312	180	312180	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1961	3187	310	690	310690	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1962	3188	311	310	311310	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1963	3189	310	16	31016	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1964	3190	310	40	31040	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1965	3191	310	780	310780	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1966	3192	311	330	311330	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1967	3193	310	400	310400	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1968	3194	311	20	31120	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1969	3194	311	10	31110	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1970	3194	312	220	312220	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1971	3194	312	10	31210	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1972	3194	311	920	311920	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1973	3195	310	350	310350	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1974	3196	310	570	310570	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1975	3197	310	290	310290	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1976	3198	310	34	31034	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1977	3199	310	600	310600	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1978	3200	311	300	311300	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1979	3201	310	130	310130	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1980	3202	312	230	312230	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1981	3202	311	610	311610	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1982	3203	310	450	310450	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1983	3204	311	710	311710	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1984	3205	310	670	310670	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1985	3205	310	11	31011	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1986	3206	311	420	311420	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1987	3207	310	999	310999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1988	3208	310	760	310760	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1989	3209	310	580	310580	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1990	3210	311	170	311170	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1991	3211	311	670	311670	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1992	3212	310	100	310100	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1993	3213	310	940	310940	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1994	3214	310	500	310500	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1995	3215	312	160	312160	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1996	3215	311	430	311430	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1997	3216	311	350	311350	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1998	3217	310	46	31046	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
1999	3218	311	260	311260	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2000	3219	310	320	310320	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2001	3154	310	15	31015	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2002	3220	316	11	31611	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2003	3221	312	530	312530	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2004	3221	310	120	310120	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2005	3221	316	10	31610	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2006	3221	312	190	312190	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2007	3221	311	880	311880	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2008	3221	311	870	311870	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2009	3221	311	490	311490	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2010	3222	310	240	310240	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2011	3222	310	660	310660	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2012	3222	310	230	310230	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2013	3222	310	31	31031	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2014	3222	310	220	310220	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2015	3222	310	270	310270	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2016	3222	310	210	310210	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2017	3222	310	260	310260	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2018	3222	310	200	310200	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2019	3222	310	250	310250	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2020	3222	310	160	310160	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2021	3222	310	800	310800	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2022	3222	310	300	310300	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2023	3222	310	280	310280	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2024	3222	310	330	310330	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2025	3222	310	310	310310	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2026	3223	310	740	310740	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2027	3224	310	14	31014	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2028	3154	310	950	310950	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2029	3225	310	860	310860	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2030	3226	311	830	311830	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2031	3226	311	50	31150	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2032	3227	310	460	310460	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2033	3228	310	490	310490	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2034	3229	311	860	311860	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2035	3229	310	960	310960	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2036	3229	312	290	312290	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2037	3230	310	20	31020	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2038	3231	311	220	311220	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2039	3231	310	730	310730	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2040	3232	311	650	311650	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2041	3233	310	38	31038	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2042	3234	310	520	310520	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2043	3154	310	3	31003	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2044	3154	310	23	31023	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2045	3154	310	24	31024	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2046	3154	310	25	31025	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2047	3235	310	530	310530	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2048	3154	310	26	31026	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2049	3236	310	340	310340	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2050	3237	311	70	31170	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2051	3238	310	390	310390	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2052	3239	748	3	74803	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2053	3239	748	0	74800	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2054	3239	748	1	74801	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2055	3240	748	10	74810	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2056	3241	748	7	74807	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2057	3242	434	4	43404	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2058	3243	434	1	43401	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2059	3244	434	7	43407	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2060	3245	434	5	43405	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2061	3246	434	2	43402	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2062	3247	541	5	54105	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2063	3248	541	1	54101	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2064	3249	225	299	225299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2065	3250	734	3	73403	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2066	3250	734	2	73402	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2067	3250	734	1	73401	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2068	3251	734	6	73406	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2069	3252	734	4	73404	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2070	3253	452	7	45207	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2071	3254	452	8	45208	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2072	3255	452	1	45201	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2073	3256	452	9	45209	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2074	3257	452	3	45203	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2075	3258	452	5	45205	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2076	3259	452	6	45206	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2077	3259	452	4	45204	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2078	3260	452	2	45202	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2079	3262	543	299	543299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2080	3263	543	1	54301	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2081	3264	421	999	421999	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2082	3265	421	4	42104	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2083	3266	421	2	42102	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2084	3267	421	1	42101	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2085	3268	421	3	42103	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2086	3269	645	1	64501	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2087	3270	645	299	645299	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2088	3271	645	2	64502	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2089	3272	645	3	64503	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2090	3273	648	4	64804	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2091	3274	648	1	64801	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2092	3275	648	3	64803	f	\N	\N	import:itu	import:itu	2025-11-21 18:55:03	2025-11-21 18:55:03	\N	\N
2	1404	289	68	28968	f	\N	1	import:itu	networks.edit	2025-11-21 18:54:55	2025-11-22 13:08:29	\N	\N
2096	3324	710	21	71021	f	1	1	networks.edit	networks.edit	2025-11-27 13:43:34	2025-11-27 13:43:34	\N	\N
2097	3316	710	30	71030	f	1	1	networks.edit	networks.edit	2025-11-27 13:44:14	2025-11-27 13:44:14	\N	\N
2098	3313	710	73	71073	f	1	1	networks.edit	networks.edit	2025-11-27 13:44:46	2025-11-27 13:44:46	\N	\N
\.


--
-- Data for Name: networks_base; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.networks_base (id, name, mcc, mnc, mcc_mnc, country_id, created_at, updated_at, created_by_user_id, updated_by_user_id, created_by_source, updated_by_source, marked_for_deletion, lower_name) FROM stdin;
1452	COMPATEL	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	compatel
1453	DEPARTMENT OF DEFENSE	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	department of defense
1454	FIX LINE	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	fix line
1455	GET SIM	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	get sim
1456	H3G LTD.	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	h3g ltd.
1457	PIVOTEL GROUP LTD	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	pivotel group ltd
1458	LYCAMOBILE	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	lycamobile
1459	MESSAGEBIRD	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	messagebird
1460	NORFOLK TELECOM	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	norfolk telecom
1461	RAILCORP/VODAFONE	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	railcorp/vodafone
1462	OPTUS	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	optus
1463	PIVOTEL	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	pivotel
1464	RAILCORP	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	railcorp
1465	SINCH	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	sinch
1466	SYMBIO	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	symbio
3273	ECONET	\N	\N	\N	419	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	econet
3274	NETONE	\N	\N	\N	419	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	netone
1467	TELSTRA	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	telstra
1468	THE OZITEL NETWORK PTY.	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	the ozitel network pty.
1469	VICTRACK	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	victrack
1470	VODAFONE	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	vodafone
1471	A1 TELEKOM	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	a1 telekom
1472	ARGONET	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	argonet
1473	T-MOBILE / MAGENTA	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	t-mobile / magenta
1474	DIALOG TELEKOM	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	dialog telekom
1475	DIGITAL PRIVACY	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	digital privacy
1476	DIMOCO	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	dimoco
1477	EDUCOM	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	educom
1478	FIX LINE	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	fix line
1479	HOLDING GRAZ	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	holding graz
1480	HUTCHINSON DREI	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	hutchinson drei
1481	INNSBRUCKER KOMMUNALBETRIEBE	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	innsbrucker kommunalbetriebe
1482	KABELPLUS	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	kabelplus
1483	LENOVO CONNECT	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	lenovo connect
1484	LINK MOBILITY	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	link mobility
1485	LIWEST MOBIL	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	liwest mobil
1486	MASS RESPONSE SERVICE	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	mass response service
1487	MTEL	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	mtel
1488	OBB INFRASTRUKTUR	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	obb infrastruktur
1489	HUTCHISON DREI / 3	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	hutchison drei / 3
1490	PLINTRON	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	plintron
1491	SIMPLE SMS	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	simple sms
1492	SKYMOND MOBILE	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	skymond mobile
1493	SMARTEL SERVICES	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	smartel services
1494	SMARTSPACE	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	smartspace
1495	TELFONI	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	telfoni
1496	TISMI	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	tismi
1497	VENTOCOM	\N	\N	\N	206	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	ventocom
1498	AZERCELL	\N	\N	\N	207	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	azercell
1499	BAKCELL	\N	\N	\N	207	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	bakcell
1500	FONEX	\N	\N	\N	207	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	fonex
1501	NAR MOBILE	\N	\N	\N	207	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	nar mobile
1502	NAXTEL	\N	\N	\N	207	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	naxtel
1503	ALIV	\N	\N	\N	208	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	aliv
1504	CYBERCELL / BATELCO	\N	\N	\N	208	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	cybercell / batelco
1505	SMART COMMUNICATIONS	\N	\N	\N	208	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	smart communications
1506	BATELCO	\N	\N	\N	209	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	batelco
1507	FAILED CALLS	\N	\N	\N	209	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	failed calls
1508	FIX LINE	\N	\N	\N	209	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	fix line
1509	ROYAL COURT	\N	\N	\N	209	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	royal court
1510	VIVA	\N	\N	\N	209	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	viva
1511	ZAIN	\N	\N	\N	209	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	zain
1512	AIRTEL	\N	\N	\N	210	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	airtel
1513	BANGLALINK	\N	\N	\N	210	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	banglalink
1514	CITYCELL	\N	\N	\N	210	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	citycell
1515	GRAMEENPHONE	\N	\N	\N	210	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	grameenphone
1516	TELETALK	\N	\N	\N	210	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	teletalk
1517	AIRTEL/WARID	\N	\N	\N	210	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	airtel/warid
1518	CINGULAR WIRELESS	\N	\N	\N	211	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	cingular wireless
1519	DIGICEL	\N	\N	\N	211	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	digicel
1520	FAILED CALLS	\N	\N	\N	211	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	failed calls
1521	FLOW / LIME	\N	\N	\N	211	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	flow / lime
1522	OZONE	\N	\N	\N	211	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	ozone
1523	SUNBEACH	\N	\N	\N	211	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	sunbeach
1524	BELCEL JV	\N	\N	\N	212	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	belcel jv
1525	LIFE:)	\N	\N	\N	212	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	life:)
1526	MDC/VELCOM	\N	\N	\N	212	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	mdc/velcom
1527	MTS	\N	\N	\N	212	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	mts
1528	VELCOM A1	\N	\N	\N	212	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	velcom a1
1529	BASE	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	base
1530	BICS	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	bics
1531	DENSE AIR	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	dense air
1532	DUST MOBILE	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	dust mobile
1533	ERICSSON	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	ericsson
1534	FEBO	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	febo
1535	FIX LINE	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	fix line
1536	GIANCOM	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	giancom
1537	INFRABEL	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	infrabel
1538	INTERACTIVE DIGITAL MEDIA / IDM	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	interactive digital media / idm
1539	L-MOBI	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	l-mobi
1540	LANCELOT	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	lancelot
1541	LEGOS	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	legos
1542	LYCAMOBILE	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	lycamobile
1543	MOBILE VIKINGS	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	mobile vikings
1544	MOBISTAR / ORANGE	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	mobistar / orange
1545	NORD CONNECT	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	nord connect
1546	ONOFF	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	onoff
1547	PM FACTORY	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	pm factory
1548	PROXIMUS	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	proximus
1549	TELENET MOBILE	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	telenet mobile
1550	VECTONE MOBILE	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	vectone mobile
1551	VOOMOBILE	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	voomobile
1552	VOXBONE / BANDWIDTH	\N	\N	\N	213	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	voxbone / bandwidth
1553	DIGICELL	\N	\N	\N	214	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	digicell
1554	FAILED CALLS	\N	\N	\N	214	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	failed calls
1555	INTERNATIONAL TELCO (INTELCO)	\N	\N	\N	214	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	international telco (intelco)
1556	SMART	\N	\N	\N	214	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	smart
1557	BELL BENIN/BBCOM	\N	\N	\N	215	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	bell benin/bbcom
1558	GLOMOBILE	\N	\N	\N	215	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	glomobile
1559	LIBERCOM	\N	\N	\N	215	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	libercom
1560	MOOV	\N	\N	\N	215	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	moov
1561	MTN	\N	\N	\N	215	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	mtn
1562	BERMUDA DIGITAL COMMUNICATIONS LTD (BDC)	\N	\N	\N	216	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	bermuda digital communications ltd (bdc)
1563	CELLONE LTD	\N	\N	\N	216	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	cellone ltd
1564	DIGICEL	\N	\N	\N	216	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	digicel
1565	FAILED CALLS	\N	\N	\N	216	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	failed calls
1566	M3 WIRELESS LTD	\N	\N	\N	216	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	m3 wireless ltd
1567	ONE	\N	\N	\N	216	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	one
1568	TELECOMMUNICATIONS (BERMUDA & WEST INDIES) LTD (DIGICEL BERMUDA)	\N	\N	\N	216	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	telecommunications (bermuda & west indies) ltd (digicel bermuda)
1569	B-MOBILE	\N	\N	\N	217	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	b-mobile
1570	BHUTAN TELECOM LTD (BTL)	\N	\N	\N	217	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	bhutan telecom ltd (btl)
1571	TASHICELL	\N	\N	\N	217	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	tashicell
1572	ENTEL PCS	\N	\N	\N	218	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	entel pcs
1573	VIVA/NUEVATEL	\N	\N	\N	218	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	viva/nuevatel
1574	TIGO	\N	\N	\N	218	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	tigo
1575	FIX LINE	\N	\N	\N	219	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	fix line
1576	BH MOBILE	\N	\N	\N	220	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	bh mobile
1577	ERONET	\N	\N	\N	220	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	eronet
1578	M:TEL	\N	\N	\N	220	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	m:tel
1579	BEMOBILE	\N	\N	\N	221	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	bemobile
1580	MASCOM	\N	\N	\N	221	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	mascom
1581	ORANGE	\N	\N	\N	221	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	orange
1582	AMERICANET	\N	\N	\N	222	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	americanet
1583	CLARO/ALBRA/AMERICA MOVIL	\N	\N	\N	222	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	claro/albra/america movil
1584	VIVO S.A./TELEMIG	\N	\N	\N	222	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	vivo s.a./telemig
1585	CTBC CELULAR SA (CTBC)	\N	\N	\N	222	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	ctbc celular sa (ctbc)
1586	TIM	\N	\N	\N	222	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	tim
1587	NEXTEL (TELET)	\N	\N	\N	222	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	nextel (telet)
1588	BRAZIL TELCOM	\N	\N	\N	222	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	brazil telcom
1589	AMAZONIA CELULAR S/A	\N	\N	\N	222	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	amazonia celular s/a
1590	OI (TNL PCS / OI)	\N	\N	\N	222	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	oi (tnl pcs / oi)
1591	PORTO SEGURO TELECOMUNICACOES	\N	\N	\N	222	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	porto seguro telecomunicacoes
1592	SERCONTEL CEL	\N	\N	\N	222	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	sercontel cel
1593	CTBC/TRIANGULO	\N	\N	\N	222	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	ctbc/triangulo
1594	UNICEL DO BRASIL TELECOMUNICACOES LTDA	\N	\N	\N	222	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	unicel do brasil telecomunicacoes ltda
1595	CARIBBEAN CELLULAR	\N	\N	\N	223	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	caribbean cellular
1596	DIGICEL	\N	\N	\N	223	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	digicel
1597	LIME	\N	\N	\N	223	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	lime
1598	B-MOBILE	\N	\N	\N	224	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	b-mobile
1599	DATASTREAM (DTSCOM)	\N	\N	\N	224	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	datastream (dtscom)
1600	TELEKOM BRUNEI BHD (TELBRU)	\N	\N	\N	224	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	telekom brunei bhd (telbru)
1601	A1	\N	\N	\N	225	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	a1
1602	VIVACOM	\N	\N	\N	225	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	vivacom
1603	BULSATCOM	\N	\N	\N	225	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	bulsatcom
1604	T.COM	\N	\N	\N	225	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	t.com
1605	TELENOR	\N	\N	\N	225	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	telenor
1606	ORANGE	\N	\N	\N	226	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	orange
1607	TELECEL	\N	\N	\N	226	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	telecel
1608	TELMOB	\N	\N	\N	226	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	telmob
1609	AFRICEL / SAFARIS	\N	\N	\N	227	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	africel / safaris
1611	LEO	\N	\N	\N	227	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	leo
1612	LUMITEL	\N	\N	\N	227	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	lumitel
1613	ONAMOB	\N	\N	\N	227	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	onamob
1614	SMART	\N	\N	\N	227	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	smart
1615	QB	\N	\N	\N	228	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	qb
1616	CELLCARD	\N	\N	\N	228	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	cellcard
1617	COOTEL	\N	\N	\N	228	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	cootel
1618	METFONE	\N	\N	\N	228	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	metfone
1619	MPTC	\N	\N	\N	228	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	mptc
1620	QB/CAMBODIA ADV. COMMS.	\N	\N	\N	228	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	qb/cambodia adv. comms.
1621	SEATEL	\N	\N	\N	228	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	seatel
1622	SMART	\N	\N	\N	228	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	smart
1623	SOTELCO/BEELINE	\N	\N	\N	228	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	sotelco/beeline
1624	MTN	\N	\N	\N	229	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	mtn
1625	NEXTTEL	\N	\N	\N	229	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	nexttel
1626	ORANGE	\N	\N	\N	229	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	orange
1627	BC TEL MOBILITY	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	bc tel mobility
1628	BELL ALIANT	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	bell aliant
1629	BELL MOBILITY	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	bell mobility
1630	CITYWEST MOBILITY	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	citywest mobility
1631	CLEARNET	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	clearnet
1632	DMTS MOBILITY	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	dmts mobility
1633	GLOBALSTAR CANADA	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	globalstar canada
1634	LATITUDE WIRELESS	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	latitude wireless
1635	FIDO (ROGERS AT&T/ MICROCELL)	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	fido (rogers at&t/ microcell)
1636	MOBILICITY	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	mobilicity
1637	MT&T MOBILITY	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	mt&t mobility
1638	MTS MOBILITY	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	mts mobility
1639	NB TEL MOBILITY	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	nb tel mobility
1640	NEW TEL MOBILITY	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	new tel mobility
1641	PUBLIC MOBILE	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	public mobile
1642	QUEBECTEL MOBILITY	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	quebectel mobility
1643	ROGERS AT&T WIRELESS	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	rogers at&t wireless
1644	SASK TEL MOBILITY	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	sask tel mobility
1645	TBAY MOBILITY	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	tbay mobility
1646	TELUS MOBILITY	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	telus mobility
1647	VIDEOTRON	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	videotron
1648	WIND	\N	\N	\N	230	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	wind
1649	CVMOVEL	\N	\N	\N	231	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	cvmovel
1650	UNITEL T+	\N	\N	\N	231	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	unitel t+
1651	DIGICEL	\N	\N	\N	232	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	digicel
1652	DIGICEL LTD.	\N	\N	\N	232	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	digicel ltd.
1653	FLOW / LIME	\N	\N	\N	232	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	flow / lime
1654	LOGIC	\N	\N	\N	232	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	logic
1655	AZUR	\N	\N	\N	233	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	azur
1656	FAILED CALLS	\N	\N	\N	233	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	failed calls
1657	MOOV	\N	\N	\N	233	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	moov
1658	ORANGE	\N	\N	\N	233	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	orange
1659	SOCATEL	\N	\N	\N	233	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	socatel
1660	TELECEL	\N	\N	\N	233	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	telecel
1661	AIRTEL	\N	\N	\N	234	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	airtel
1662	MOOV	\N	\N	\N	234	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	moov
1663	SALAM	\N	\N	\N	234	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	salam
1664	TCHAD MOBILE	\N	\N	\N	234	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	tchad mobile
1665	BLUE TWO CHILE SA	\N	\N	\N	235	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	blue two chile sa
1666	CELUPAGO SA	\N	\N	\N	235	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	celupago sa
1667	CIBELES TELECOM SA	\N	\N	\N	235	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	cibeles telecom sa
1668	CLARO	\N	\N	\N	235	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	claro
1669	ENTEL TELEFONIA	\N	\N	\N	235	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	entel telefonia
1670	ENTEL TELEFONIA MOV	\N	\N	\N	235	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	entel telefonia mov
1671	NETLINE TELEFONICA MOVIL LTDA	\N	\N	\N	235	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	netline telefonica movil ltda
1672	NEXTEL SA	\N	\N	\N	235	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	nextel sa
1673	SOCIEDAD FALABELLA MOVIL SPA	\N	\N	\N	235	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	sociedad falabella movil spa
1674	TELEFONICA	\N	\N	\N	235	2025-11-18 22:02:29	2025-11-18 22:02:29	\N	\N	\N	\N	f	telefonica
1675	TELESTAR MOVIL SA	\N	\N	\N	235	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	telestar movil sa
1676	TESAM SA	\N	\N	\N	235	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tesam sa
1677	TRIBE MOBILE SPA	\N	\N	\N	235	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tribe mobile spa
1678	VTR BANDA ANCHA SA	\N	\N	\N	235	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	vtr banda ancha sa
1679	CHINA MOBILE GSM	\N	\N	\N	236	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	china mobile gsm
1680	CHINA SPACE MOBILE SATELLITE TELECOMMUNICATIONS CO. LTD (CHINA SPACECOM)	\N	\N	\N	236	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	china space mobile satellite telecommunications co. ltd (china spacecom)
1681	CHINA TELECOM	\N	\N	\N	236	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	china telecom
1682	CHINA UNICOM	\N	\N	\N	236	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	china unicom
1683	FIX LINE	\N	\N	\N	236	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	fix line
1684	ATNET	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	atnet
1685	AVANTEL	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	avantel
1686	MOVISTAR	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	movistar
1687	CLARO	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	claro
1688	EDATEL	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	edatel
1689	ETB	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	etb
1690	EZTALK MOBILE	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	eztalk mobile
1691	FIX LINE	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	fix line
1692	FLASH MOBILE	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	flash mobile
1693	GOMOBILE	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	gomobile
1694	LIBRE TECNOLOGIAS	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	libre tecnologias
1695	MOVIL EXITO	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	movil exito
1696	PLINTRON	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	plintron
1697	SETROC MOBILE	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	setroc mobile
1698	SUMA MOVIL	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	suma movil
1699	TIGO	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tigo
1700	TUCEL	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tucel
1701	UNE	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	une
1702	VILACOM MOBILE	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	vilacom mobile
1703	VIRGIN MOBILE	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	virgin mobile
1704	WOM	\N	\N	\N	237	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	wom
1705	FAILED CALLS	\N	\N	\N	238	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	failed calls
1706	HURI	\N	\N	\N	238	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	huri
1707	TELMA	\N	\N	\N	238	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	telma
1708	AIRTEL	\N	\N	\N	239	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	airtel
1709	AZUR SA (ETC)	\N	\N	\N	239	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	azur sa (etc)
1710	MTN	\N	\N	\N	239	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	mtn
1711	WARID	\N	\N	\N	239	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	warid
1712	VODAFONE / BLUESKY	\N	\N	\N	240	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	vodafone / bluesky
1713	CLARO	\N	\N	\N	241	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	claro
1714	FIX LINE	\N	\N	\N	241	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	fix line
1715	ICE	\N	\N	\N	241	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	ice
1716	MOVISTAR	\N	\N	\N	241	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	movistar
1717	VIRTUALIS	\N	\N	\N	241	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	virtualis
1718	A1 / VIP	\N	\N	\N	242	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	a1 / vip
1719	FIX LINE	\N	\N	\N	242	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	fix line
1720	T-MOBILE	\N	\N	\N	242	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	t-mobile
1721	TELE FOCUS	\N	\N	\N	242	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tele focus
1722	TELEMACH / TELE2	\N	\N	\N	242	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	telemach / tele2
1723	CUBACEL/C-COM	\N	\N	\N	243	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	cubacel/c-com
1724	FIX LINE	\N	\N	\N	243	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	fix line
1725	EOCG WIRELESS NV	\N	\N	\N	244	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	eocg wireless nv
1726	FIX LINE	\N	\N	\N	244	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	fix line
1727	POLYCOM N.V./ DIGICEL	\N	\N	\N	244	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	polycom n.v./ digicel
1728	CABLENET / LEMONTEL	\N	\N	\N	245	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	cablenet / lemontel
1729	CYTAMOBILE-VODAFONE	\N	\N	\N	245	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	cytamobile-vodafone
1730	EPIC / MTN	\N	\N	\N	245	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	epic / mtn
1731	FIX LINE	\N	\N	\N	245	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	fix line
1732	PRIMETEL	\N	\N	\N	245	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	primetel
1733	+4U MOBILE	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	+4u mobile
1734	3TON	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	3ton
1735	CEZ	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	cez
1736	COMPATEL	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	compatel
1737	DRAGON	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	dragon
1738	ERIMOBILE	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	erimobile
1739	FAYN	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	fayn
1740	FIX LINE	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	fix line
1741	GOMOBIL	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	gomobil
1742	HA-LOO MOBIL	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	ha-loo mobil
1743	LAUDATIO	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	laudatio
1744	METRONET	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	metronet
1745	MOBIL21	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	mobil21
1746	NEJ MOBIL	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	nej mobil
1747	NETBOX MOBIL	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	netbox mobil
1748	NORDIC TELECOM	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	nordic telecom
1749	O2	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	o2
1750	ODORIK	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	odorik
1751	PODA	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	poda
1752	SAZKA	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	sazka
1753	SZDC	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	szdc
1754	T-MOBILE	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	t-mobile
1755	TESCO MOBILE	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tesco mobile
1756	TOPEFEKT	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	topefekt
1757	TT QUALITY	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tt quality
1758	UNIPHONE	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	uniphone
1759	VODAFONE	\N	\N	\N	246	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	vodafone
1760	AFRICELL	\N	\N	\N	247	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	africell
1761	AIRTEL	\N	\N	\N	247	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	airtel
1762	FAILED CALLS	\N	\N	\N	247	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	failed calls
1763	ORANGE	\N	\N	\N	247	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	orange
1764	SUPERCELL	\N	\N	\N	247	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	supercell
1765	TATEM	\N	\N	\N	247	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tatem
1766	TIGO/OASIS	\N	\N	\N	247	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tigo/oasis
1767	VODACOM	\N	\N	\N	247	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	vodacom
1768	YOZMA TIMETURNS	\N	\N	\N	247	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	yozma timeturns
1769	BANEDANMARK	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	banedanmark
1770	NET 1	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	net 1
1771	COBIRA	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	cobira
1772	COMPATEL	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	compatel
1773	FIX LINE	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	fix line
1774	GOTANET	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	gotanet
1775	GREENWAVE	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	greenwave
1776	3	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	3
1777	LINK MOBILITY	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	link mobility
1778	LYCAMOBILE	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	lycamobile
1779	MONTY MOBILE	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	monty mobile
1780	MUNDIO MOBILE	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	mundio mobile
1781	NEXCON.IO	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	nexcon.io
1782	ONOMONDO	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	onomondo
1783	PARETEUM	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	pareteum
1784	SYNIVERSE TECHNOLOGIES	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	syniverse technologies
1785	TDC	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tdc
1786	TELENOR	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	telenor
1787	TELIA	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	telia
1788	TISMI	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tismi
1789	VIAHUB	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	viahub
1790	VOXBONE / BANDWIDTH	\N	\N	\N	248	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	voxbone / bandwidth
1791	EVATIS	\N	\N	\N	249	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	evatis
1792	C & W	\N	\N	\N	250	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	c & w
1793	CINGULAR WIRELESS/DIGICEL	\N	\N	\N	250	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	cingular wireless/digicel
1794	WIRELESS VENTURES (DOMINICA) LTD (DIGICEL DOMINICA)	\N	\N	\N	250	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	wireless ventures (dominica) ltd (digicel dominica)
1795	CLARO	\N	\N	\N	251	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	claro
1796	ORANGE	\N	\N	\N	251	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	orange
1797	TRICOM	\N	\N	\N	251	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tricom
1798	VIVA	\N	\N	\N	251	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	viva
1799	FAILED CALLS	\N	\N	\N	252	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	failed calls
1800	FIX LINE	\N	\N	\N	252	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	fix line
1801	TELEMOR	\N	\N	\N	252	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	telemor
1802	TELKOMCEL	\N	\N	\N	252	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	telkomcel
1803	TIMOR TELECOM	\N	\N	\N	252	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	timor telecom
1804	CLARO/PORT	\N	\N	\N	253	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	claro/port
1805	CNT MOBILE	\N	\N	\N	253	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	cnt mobile
1806	FAILED CALL(S)	\N	\N	\N	253	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	failed call(s)
1807	MOVISTAR/OTECEL	\N	\N	\N	253	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	movistar/otecel
1808	TUENTI	\N	\N	\N	253	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tuenti
1809	ETISALAT	\N	\N	\N	254	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	etisalat
1810	FAILED CALLS	\N	\N	\N	254	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	failed calls
1811	ORANGE	\N	\N	\N	254	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	orange
1812	VODAFONE	\N	\N	\N	254	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	vodafone
1813	WE	\N	\N	\N	254	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	we
1814	CLARO/CTE	\N	\N	\N	255	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	claro/cte
1815	DIGICEL	\N	\N	\N	255	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	digicel
1816	INTELFON SA DE CV	\N	\N	\N	255	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	intelfon sa de cv
1817	TELEFONICA	\N	\N	\N	255	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	telefonica
1818	TELEMOVIL	\N	\N	\N	255	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	telemovil
1819	FAILED CALLS	\N	\N	\N	256	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	failed calls
1820	MUNI	\N	\N	\N	256	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	muni
1821	ORANGE	\N	\N	\N	256	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	orange
1822	ERITEL	\N	\N	\N	257	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	eritel
1823	ELISA	\N	\N	\N	258	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	elisa
1824	TELE2	\N	\N	\N	258	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tele2
1825	TELIA	\N	\N	\N	258	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	telia
1826	TRAVELSIM	\N	\N	\N	258	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	travelsim
1827	ETHIO MOBILE	\N	\N	\N	259	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	ethio mobile
1828	SURE	\N	\N	\N	260	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	sure
1829	FAROESE TELECOM	\N	\N	\N	261	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	faroese telecom
1830	HEY / KALL	\N	\N	\N	261	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	hey / kall
1831	TOSA	\N	\N	\N	261	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tosa
1832	DIGICELL	\N	\N	\N	262	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	digicell
1833	VODAFONE	\N	\N	\N	262	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	vodafone
1834	ALCOM	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	alcom
1835	BENEMEN	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	benemen
1836	COMPATEL	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	compatel
1837	CUUMA	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	cuuma
1838	DNA	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	dna
1839	ELISA	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	elisa
1840	INTERACTIVE DIGITAL MEDIA / IDM	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	interactive digital media / idm
1841	IPIFY	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	ipify
1842	LANCELOT	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	lancelot
1843	MI CARRIER SERVICES	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	mi carrier services
1844	MOBIWEB	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	mobiweb
1845	VIAHUB	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	viahub
1846	NORD CONNECT	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	nord connect
1847	NSN	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	nsn
1848	RAILI	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	raili
1849	TDC OY FINLAND	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tdc oy finland
1850	TELAVOX	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	telavox
1851	TELIA	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	telia
1852	TELIT	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	telit
1853	TISMI	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	tismi
1854	TRAVELSIM	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	travelsim
1855	TWILIO	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	twilio
1856	UKKO MOBILE	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	ukko mobile
1857	VIRVE	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	virve
1858	VOXBONE / BANDWIDTH	\N	\N	\N	263	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	voxbone / bandwidth
1859	ADD-ON MULTIMEDIA	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	add-on multimedia
1860	AFONE MOBILE	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	afone mobile
1861	AIRMOB	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	airmob
1862	ALPHALINK	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	alphalink
1863	ANNATEL	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	annatel
1864	IP DIRECTIONS	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	ip directions
1865	ATLAS	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	atlas
1866	AUCHAN	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	auchan
1867	AXIALYS	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	axialys
1868	BAZILE	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	bazile
1869	BJT	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	bjt
1870	BOUYGUES TELECOM	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	bouygues telecom
1871	BRETAGNE TELECOM	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	bretagne telecom
1872	CAT	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	cat
1873	CELESTE	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	celeste
1874	CELLHIRE	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	cellhire
1875	CODEPI	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	codepi
1876	COOLWAVE	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	coolwave
1877	CORIOLIS	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	coriolis
1878	CPRO	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	cpro
1879	CRH	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	crh
1880	CRT	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	crt
1881	CTEXCEL	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	ctexcel
1882	DOCTOLIB	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	doctolib
1883	FAILED CALLS	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	failed calls
1884	FIX LINE	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	fix line
1885	FOLIATEAM	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	foliateam
1886	FREE MOBILE	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	free mobile
1887	GLOBALSTAR	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	globalstar
1888	HALYS	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	halys
1889	HAPPY TELECOM	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	happy telecom
1890	HEXATEL	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	hexatel
1891	HUB ONE	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	hub one
1892	I-VIA	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	i-via
1893	ORANGE	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	orange
1894	IP TELECOM	\N	\N	\N	264	2025-11-18 22:02:30	2025-11-18 22:02:30	\N	\N	\N	\N	f	ip telecom
1895	IPTIS	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	iptis
1896	JOI	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	joi
1897	KERTEL	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	kertel
1898	KEYYO MOBILE	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	keyyo mobile
1899	LA POSTE MOBILE	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	la poste mobile
1900	LASOTEL	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	lasotel
1901	LEBARA	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	lebara
1902	LEGOS	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	legos
1903	LINKT	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	linkt
1904	LITEYEAR	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	liteyear
1905	LYCAMOBILE	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	lycamobile
1906	MOBIQUITHINGS	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	mobiquithings
1907	NETCOM	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	netcom
1908	NETWORTH TELECOM	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	networth telecom
1909	NORDNET	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	nordnet
1910	NRJ	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	nrj
1911	ONOFF	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	onoff
1912	OPENIP	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	openip
1913	PARITEL	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	paritel
1914	PRIXTEL	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	prixtel
1915	SFR	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	sfr
1916	SCT TELECOM	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	sct telecom
1917	SEWAN COMMUNICATIONS	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	sewan communications
1918	SIMBIOZ	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	simbioz
1919	SYMA MOBILE	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	syma mobile
1920	TDF	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	tdf
1921	TEL/TE	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	tel/te
1922	TISMI	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	tismi
1923	TRANSATEL	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	transatel
1924	TRUNKLINE	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	trunkline
1925	TRUPHONE	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	truphone
1926	UNYC	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	unyc
1927	VA SOLUTIONS	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	va solutions
1928	VECTONE MOBILE	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	vectone mobile
1929	VOIP TELECOM	\N	\N	\N	264	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	voip telecom
1930	BOUYGUES/DIGICEL	\N	\N	\N	265	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	bouygues/digicel
1931	ORANGE CARIBE	\N	\N	\N	265	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	orange caribe
1932	OUTREMER TELECOM	\N	\N	\N	265	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	outremer telecom
1933	TELCELL GSM	\N	\N	\N	265	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	telcell gsm
1934	PACIFIC MOBILE TELECOM (PMT)	\N	\N	\N	266	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	pacific mobile telecom (pmt)
1935	VINI/TIKIPHONE	\N	\N	\N	266	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	vini/tikiphone
1936	AIRTEL	\N	\N	\N	267	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	airtel
1937	AZUR/USAN S.A.	\N	\N	\N	267	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	azur/usan s.a.
1938	FAILED CALLS	\N	\N	\N	267	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	failed calls
1939	LIBERTIS	\N	\N	\N	267	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	libertis
1940	MOOV/TELECEL	\N	\N	\N	267	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	moov/telecel
1941	AFRICEL	\N	\N	\N	268	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	africel
1942	COMIUM	\N	\N	\N	268	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	comium
1943	GAMCEL	\N	\N	\N	268	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	gamcel
1944	QCELL	\N	\N	\N	268	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	qcell
1945	BEELINE	\N	\N	\N	193	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	beeline
1946	GEOCELL	\N	\N	\N	193	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	geocell
1947	GLOBALCELL	\N	\N	\N	193	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	globalcell
1948	IBERIATEL LTD.	\N	\N	\N	193	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	iberiatel ltd.
1949	MAGTICOM	\N	\N	\N	193	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	magticom
1950	MOBILIVE	\N	\N	\N	193	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	mobilive
1951	MYPHONE	\N	\N	\N	193	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	myphone
1952	PREMIUM NET	\N	\N	\N	193	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	premium net
1953	SILKNET	\N	\N	\N	193	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	silknet
1954	TELECOM 1	\N	\N	\N	193	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	telecom 1
1955	1&1	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	1&1
1956	ARGON NETWORKS	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	argon networks
1957	BUNDESAMT FÜR AUSRÜSTUNG, INFORMATIONSTECHNIK UND NUTZUNG DER BUNDESWEHR	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	bundesamt für ausrüstung, informationstechnik und nutzung der bundeswehr
1958	DB NETZ	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	db netz
1959	TELEFONICA / E-PLUS	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	telefonica / e-plus
1960	FIX LINE	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	fix line
1961	LEBARA	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	lebara
1962	LYCAMOBILE	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	lycamobile
1963	MULTICONNECT	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	multiconnect
1964	SIPGATE	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	sipgate
1965	TELCOVILLAGE	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	telcovillage
1966	TELEFONICA / O2	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	telefonica / o2
1967	TELEKOM / T-MOBILE	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	telekom / t-mobile
1968	TISMI	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	tismi
1969	TRUPHONE	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	truphone
1970	VODAFONE	\N	\N	\N	269	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	vodafone
1971	AIRTEL	\N	\N	\N	270	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	airtel
1972	COMSYS	\N	\N	\N	270	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	comsys
1973	EXPRESSO GHANA LTD	\N	\N	\N	270	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	expresso ghana ltd
1974	GLO	\N	\N	\N	270	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	glo
1975	MTN	\N	\N	\N	270	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	mtn
1976	NATIONAL SECURITY	\N	\N	\N	270	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	national security
1977	SURFLINE	\N	\N	\N	270	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	surfline
1978	VODAFONE	\N	\N	\N	270	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	vodafone
1979	CTS MOBILE	\N	\N	\N	271	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	cts mobile
1980	EAZI TELECOM	\N	\N	\N	271	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	eazi telecom
1981	FIX LINE	\N	\N	\N	271	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	fix line
1982	GIBFIBRESPEED	\N	\N	\N	271	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	gibfibrespeed
1983	GIBTEL	\N	\N	\N	271	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	gibtel
1984	AMD TELECOM	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	amd telecom
1985	APIFON	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	apifon
1986	BWS	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	bws
1987	CYTA MOBILE	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	cyta mobile
1988	FIX LINE	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	fix line
1989	INTER TELECOM	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	inter telecom
1990	INTERCONNECT	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	interconnect
1991	M-STAT	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	m-stat
1992	OSE	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	ose
1993	OTE	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	ote
1994	OTEGLOBE	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	oteglobe
1995	PREMIUM NET	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	premium net
1996	WIND	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	wind
1997	YUBOTO	\N	\N	\N	191	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	yuboto
1998	TELE GREENLAND	\N	\N	\N	272	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	tele greenland
1999	CABLE & WIRELESS	\N	\N	\N	273	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	cable & wireless
2000	DIGICEL	\N	\N	\N	273	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	digicel
2001	DAUPHIN TELECOM SU (GUADELOUPE TELECOM)	\N	\N	\N	274	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	dauphin telecom su (guadeloupe telecom)
2002	DOCOMO	\N	\N	\N	275	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	docomo
2003	GTA WIRELESS	\N	\N	\N	275	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	gta wireless
2004	GUAM TELEPH. AUTH	\N	\N	\N	275	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	guam teleph. auth
2005	IT&E OVERSEAS	\N	\N	\N	275	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	it&e overseas
2006	WAVE RUNNER LLC	\N	\N	\N	275	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	wave runner llc
2007	CLARO	\N	\N	\N	276	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	claro
2008	TELEFONICA	\N	\N	\N	276	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	telefonica
2009	TIGO/COMCEL	\N	\N	\N	276	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	tigo/comcel
2010	CELLCOM	\N	\N	\N	277	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	cellcom
2011	INTERCEL	\N	\N	\N	277	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	intercel
2012	MTN	\N	\N	\N	277	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	mtn
2013	ORANGE	\N	\N	\N	277	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	orange
2014	SOTELGUI	\N	\N	\N	277	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	sotelgui
2016	GUINETEL	\N	\N	\N	278	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	guinetel
2017	MTN	\N	\N	\N	278	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	mtn
2018	ORANGE	\N	\N	\N	278	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	orange
2019	CELLINK PLUS	\N	\N	\N	279	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	cellink plus
2020	DIGICEL	\N	\N	\N	279	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	digicel
2021	COMCEL	\N	\N	\N	280	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	comcel
2022	DIGICEL	\N	\N	\N	280	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	digicel
2023	NATCOM	\N	\N	\N	280	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	natcom
2024	DIGICEL	\N	\N	\N	281	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	digicel
2025	HONDUTEL	\N	\N	\N	281	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	hondutel
2026	SERCOM/CLARO	\N	\N	\N	281	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	sercom/claro
2027	TELEFONICA/CELTEL	\N	\N	\N	281	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	telefonica/celtel
2028	CHINA MOBILE/PEOPLES	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	china mobile/peoples
2029	CHINA MOTION	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	china motion
2030	CHINA UNICOM LTD	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	china unicom ltd
2031	CHINA-HONGKONG TELECOM LTD (CHKTL)	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	china-hongkong telecom ltd (chktl)
2032	CITIC TELECOM LTD.	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	citic telecom ltd.
2033	CSL LTD.	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	csl ltd.
2034	CSL/NEW WORLD PCS LTD.	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	csl/new world pcs ltd.
2035	CTEXCEL	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	ctexcel
2036	H3G/HUTCHINSON	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	h3g/hutchinson
2037	HKT/PCCW	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	hkt/pccw
2038	SHARED BY PRIVATE TETRA SYSTEMS	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	shared by private tetra systems
2039	MULTIBYTE INFO TECHNOLOGY LTD	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	multibyte info technology ltd
2040	TRUEPHONE	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	truephone
2041	VODAFONE/SMARTONE	\N	\N	\N	282	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	vodafone/smartone
2042	ANTENNA	\N	\N	\N	283	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	antenna
2043	DIGI	\N	\N	\N	283	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	digi
2044	FIX LINE	\N	\N	\N	283	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	fix line
2045	INVITECH	\N	\N	\N	283	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	invitech
2046	MOBIL4	\N	\N	\N	283	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	mobil4
2047	MVM NET	\N	\N	\N	283	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	mvm net
2048	NETFONE	\N	\N	\N	283	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	netfone
2049	TARR	\N	\N	\N	283	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	tarr
2050	TELEKOM	\N	\N	\N	283	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	telekom
2051	TELENOR	\N	\N	\N	283	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	telenor
2052	UPC MAGYARORSZAG KFT.	\N	\N	\N	283	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	upc magyarorszag kft.
2053	VIDANET	\N	\N	\N	283	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	vidanet
2054	VODAFONE	\N	\N	\N	283	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	vodafone
2055	AMITELO	\N	\N	\N	284	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	amitelo
2056	ICECELL	\N	\N	\N	284	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	icecell
2057	NOVA	\N	\N	\N	284	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	nova
2058	SIMINN	\N	\N	\N	284	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	siminn
2059	TISMI	\N	\N	\N	284	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	tismi
2060	VIKING WIRELESS	\N	\N	\N	284	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	viking wireless
2061	VODAFONE	\N	\N	\N	284	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	vodafone
2062	AIRCEL	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	aircel
2063	AIRCEL DIGILINK INDIA	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	aircel digilink india
2064	AIRTEL	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	airtel
2065	BARAKHAMBA SALES & SERV.	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	barakhamba sales & serv.
2066	BSNL	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	bsnl
2067	BHARTI AIRTEL LIMITED (DELHI)	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	bharti airtel limited (delhi)
2068	BHARTI AIRTEL LIMITED (KARNATAKA) (INDIA)	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	bharti airtel limited (karnataka) (india)
2069	CELLONE A&N	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	cellone a&n
2070	ESCORTS TELECOM LTD.	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	escorts telecom ltd.
2071	ESCOTEL MOBILE COMMUNICATIONS	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	escotel mobile communications
2072	FASCEL LIMITED	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	fascel limited
2073	FASCEL	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	fascel
2074	FIX LINE	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	fix line
2075	HEXACOM INDIA	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	hexacom india
2076	HEXCOM INDIA	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	hexcom india
2077	IDEA CELLULAR LTD.	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	idea cellular ltd.
2078	MAHANAGAR TELEPHONE NIGAM	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	mahanagar telephone nigam
2079	RELIABLE INTERNET SERVICES	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	reliable internet services
2080	RELIANCE TELECOM PRIVATE	\N	\N	\N	285	2025-11-18 22:02:31	2025-11-18 22:02:31	\N	\N	\N	\N	f	reliance telecom private
2081	RPG CELLULAR	\N	\N	\N	285	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	rpg cellular
2082	SPICE	\N	\N	\N	285	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	spice
2083	STERLING CELLULAR LTD.	\N	\N	\N	285	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	sterling cellular ltd.
2084	TATA / KARNATAKA	\N	\N	\N	285	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	tata / karnataka
2085	USHA MARTIN TELECOM	\N	\N	\N	285	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	usha martin telecom
2086	VARIOUS NETWORKS	\N	\N	\N	285	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	various networks
2087	UNKNOWN	\N	\N	\N	285	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	unknown
2088	VODAFONE/ESSAR/HUTCH	\N	\N	\N	285	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	vodafone/essar/hutch
2089	AXIS/NATRINDO	\N	\N	\N	286	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	axis/natrindo
2090	ESIA (PT BAKRIE TELECOM) (CDMA)	\N	\N	\N	286	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	esia (pt bakrie telecom) (cdma)
2091	FIX LINE	\N	\N	\N	286	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	fix line
2092	FLEXI (PT TELKOM) (CDMA)	\N	\N	\N	286	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	flexi (pt telkom) (cdma)
2093	H3G CP	\N	\N	\N	286	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	h3g cp
2094	INDOSAT/SATELINDO/M3	\N	\N	\N	286	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	indosat/satelindo/m3
2095	PT PASIFIK SATELIT NUSANTARA (PSN)	\N	\N	\N	286	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	pt pasifik satelit nusantara (psn)
2096	PT SAMPOERNA TELEKOMUNIKASI INDONESIA (STI)	\N	\N	\N	286	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	pt sampoerna telekomunikasi indonesia (sti)
2097	PT SMARTFREN TELECOM TBK	\N	\N	\N	286	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	pt smartfren telecom tbk
2098	PT. EXCELCOM	\N	\N	\N	286	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	pt. excelcom
2099	TELKOMSEL	\N	\N	\N	286	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	telkomsel
2100	ANTARCTICA	\N	\N	\N	287	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	antarctica
2101	FIX LINE	\N	\N	\N	288	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	fix line
2102	MOBILE TELECOMMUNICATIONS COMPANY OF ESFAHAN JV-PJS (MTCE)	\N	\N	\N	288	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	mobile telecommunications company of esfahan jv-pjs (mtce)
2103	MTCE	\N	\N	\N	288	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	mtce
2104	MTN/IRANCELL	\N	\N	\N	288	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	mtn/irancell
2105	RIGHTEL	\N	\N	\N	288	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	rightel
2106	TALIYA	\N	\N	\N	288	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	taliya
2107	MCI/TCI	\N	\N	\N	288	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	mci/tci
2108	TKC/KFZO	\N	\N	\N	288	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	tkc/kfzo
2109	ASIA CELL	\N	\N	\N	289	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	asia cell
2110	FASTLINK	\N	\N	\N	289	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	fastlink
2111	ITISALUNA AND KALEMAT	\N	\N	\N	289	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	itisaluna and kalemat
2112	KOREK	\N	\N	\N	289	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	korek
2113	MOBITEL	\N	\N	\N	289	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	mobitel
2114	ORASCOM TELECOM	\N	\N	\N	289	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	orascom telecom
2115	SANATEL	\N	\N	\N	289	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	sanatel
2116	ZAIN	\N	\N	\N	289	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	zain
2117	ACCESS TELECOM LTD.	\N	\N	\N	290	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	access telecom ltd.
2118	METEOR / EIR MOBILE	\N	\N	\N	290	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	meteor / eir mobile
2119	LYCAMOBILE	\N	\N	\N	290	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	lycamobile
2120	TESCO MOBILE	\N	\N	\N	290	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	tesco mobile
2121	3	\N	\N	\N	290	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	3
2122	VIRGIN MEDIA	\N	\N	\N	290	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	virgin media
2123	VODAFONE	\N	\N	\N	290	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	vodafone
2124	019 MOBILE	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	019 mobile
2125	ANNATEL MOBILE	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	annatel mobile
2126	BEEZZ	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	beezz
2127	BYNET	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	bynet
2128	CELLACT	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	cellact
2129	CELLCOM	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	cellcom
2130	FAILED CALLS	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	failed calls
2131	GOLAN TELECOM	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	golan telecom
2132	HOME CELLULAR	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	home cellular
2133	HOT MOBILE	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	hot mobile
2134	ITURAN	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	ituran
2135	MASKYOO	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	maskyoo
2136	ORANGE	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	orange
2137	PELEPHONE	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	pelephone
2138	RAMI LEVY COMMUNICATIONS	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	rami levy communications
2139	T2T	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	t2t
2140	TELZAR/AZI	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	telzar/azi
2141	VON WAVES	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	von waves
2142	WE4G	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	we4g
2143	YOUPHONE	\N	\N	\N	291	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	youphone
2144	A-TONO	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	a-tono
2145	AGILE TELECOM	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	agile telecom
2146	BT MOBILE	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	bt mobile
2147	ESENDEX	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	esendex
2148	COMPATEL	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	compatel
2149	COOPVOCE	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	coopvoce
2150	DIGI	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	digi
2151	DIREQ	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	direq
2152	ELSACOM	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	elsacom
2153	ENEL	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	enel
2154	FASTWEB	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	fastweb
2155	FIX LINE	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	fix line
2156	WINDTRE / HI3G	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	windtre / hi3g
2157	ILIAD	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	iliad
2158	IPSE 2000	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	ipse 2000
2159	KALEYRA	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	kaleyra
2160	SMS.IT / LINK MOBILITY	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	sms.it / link mobility
2161	LYCAMOBILE	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	lycamobile
2162	NOVERCA ITALIA	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	noverca italia
2163	PLINTRON	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	plintron
2164	POSTE MOBILE	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	poste mobile
2165	PREMIUM NUMBERS	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	premium numbers
2167	RFI	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	rfi
2168	SPUSU	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	spusu
2169	TELECOM ITALIA MOBILE	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	telecom italia mobile
2170	TIM	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	tim
2171	SPARKLE	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	sparkle
2172	MUNDIO	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	mundio
2173	HO.	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	ho.
2174	VIANOVA MOBILE	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	vianova mobile
2175	VODAFONE	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	vodafone
2176	VOIP LINE	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	voip line
2177	VOLA	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	vola
2178	WEBCOM	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	webcom
2179	WINDTRE / WIND	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	windtre / wind
2180	AIRCOMM SA	\N	\N	\N	293	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	aircomm sa
2181	COMIUM	\N	\N	\N	293	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	comium
2182	COMSTAR	\N	\N	\N	293	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	comstar
2183	MOOV	\N	\N	\N	293	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	moov
2184	MTN	\N	\N	\N	293	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	mtn
2185	ORANGE	\N	\N	\N	293	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	orange
2186	ORICELL	\N	\N	\N	293	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	oricell
2187	CABLE & WIRELESS	\N	\N	\N	294	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	cable & wireless
2188	DIGICEL/MOSSEL	\N	\N	\N	294	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	digicel/mossel
2189	Y-MOBILE	\N	\N	\N	295	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	y-mobile
2190	KDDI	\N	\N	\N	295	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	kddi
2191	NTT DOCOMO	\N	\N	\N	295	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	ntt docomo
2192	OKINAWA CELLULAR	\N	\N	\N	295	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	okinawa cellular
2193	RAKUTEN MOBILE	\N	\N	\N	295	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	rakuten mobile
2194	SOFTBANK	\N	\N	\N	295	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	softbank
2195	FIX LINE	\N	\N	\N	296	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	fix line
2196	ORANGE	\N	\N	\N	296	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	orange
2197	UMNIAH	\N	\N	\N	296	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	umniah
2198	XPRESS	\N	\N	\N	296	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	xpress
2199	ZAIN	\N	\N	\N	296	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	zain
2200	BEELINE/KAR-TEL LLP	\N	\N	\N	297	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	beeline/kar-tel llp
2201	DALACOM/ALTEL	\N	\N	\N	297	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	dalacom/altel
2202	K-CELL	\N	\N	\N	297	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	k-cell
2203	TELE2/NEO/MTS	\N	\N	\N	297	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	tele2/neo/mts
2204	AIRTEL	\N	\N	\N	298	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	airtel
2205	EFERIO	\N	\N	\N	298	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	eferio
2206	FINSERVE AFRICA	\N	\N	\N	298	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	finserve africa
2207	HOMELAND MEDIA	\N	\N	\N	298	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	homeland media
2208	INFURA	\N	\N	\N	298	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	infura
2209	JAMBO TELCOMS	\N	\N	\N	298	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	jambo telcoms
2210	JAMII TELECOMMUNICATIONS	\N	\N	\N	298	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	jamii telecommunications
2211	MOBILE PAY	\N	\N	\N	298	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	mobile pay
2212	SAFARICOM	\N	\N	\N	298	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	safaricom
2213	TELKOM	\N	\N	\N	298	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	telkom
2214	KIRIBATI FRIGATE	\N	\N	\N	299	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	kiribati frigate
2215	D3 MOBILE	\N	\N	\N	300	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	d3 mobile
2216	DARDAFON.NET LLC	\N	\N	\N	300	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	dardafon.net llc
2217	IPKO	\N	\N	\N	300	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	ipko
2218	MTS	\N	\N	\N	300	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	mts
2219	VALA	\N	\N	\N	300	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	vala
2220	FIX LINE	\N	\N	\N	301	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	fix line
2221	ZAIN	\N	\N	\N	301	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	zain
2222	VIVA	\N	\N	\N	301	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	viva
2223	OOREDOO	\N	\N	\N	301	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	ooredoo
2224	BEELINE	\N	\N	\N	302	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	beeline
2225	FAILED CALLS	\N	\N	\N	302	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	failed calls
2226	KT MOBILE	\N	\N	\N	302	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	kt mobile
2227	MEGACOM	\N	\N	\N	302	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	megacom
2228	O!	\N	\N	\N	302	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	o!
2229	SAIMA	\N	\N	\N	302	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	saima
2230	SEM MOBILE	\N	\N	\N	302	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	sem mobile
2231	ETL MOBILE	\N	\N	\N	303	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	etl mobile
2232	LAO TEL	\N	\N	\N	303	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	lao tel
2233	BEELINE/TIGO/MILLICOM	\N	\N	\N	303	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	beeline/tigo/millicom
2234	UNITEL/LAT	\N	\N	\N	303	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	unitel/lat
2235	BITE	\N	\N	\N	304	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	bite
2236	LMT	\N	\N	\N	304	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	lmt
2237	PREMIUM NUMBERS	\N	\N	\N	304	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	premium numbers
2238	SIA MASTER TELECOM	\N	\N	\N	304	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	sia master telecom
2239	SIA RIGATTA	\N	\N	\N	304	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	sia rigatta
2240	TELE2	\N	\N	\N	304	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	tele2
2241	TET	\N	\N	\N	304	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	tet
2242	TRIATEL	\N	\N	\N	304	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	triatel
2243	VENTA MOBILE	\N	\N	\N	304	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	venta mobile
2244	XOMOBILE	\N	\N	\N	304	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	xomobile
2245	CELLIS	\N	\N	\N	305	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	cellis
2246	FTML CELLIS	\N	\N	\N	305	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	ftml cellis
2247	MIC2/LIBANCELL/MTC	\N	\N	\N	305	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	mic2/libancell/mtc
2248	MIC1 (ALFA)	\N	\N	\N	305	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	mic1 (alfa)
2249	ECONET	\N	\N	\N	306	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	econet
2250	VODACOM	\N	\N	\N	306	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	vodacom
2251	LIBERCELL	\N	\N	\N	307	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	libercell
2252	LIBTELCO	\N	\N	\N	307	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	libtelco
2253	MTN / LONESTAR	\N	\N	\N	307	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	mtn / lonestar
2254	NOVAFONE	\N	\N	\N	307	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	novafone
2255	ORANGE	\N	\N	\N	307	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	orange
2256	AL-MADAR	\N	\N	\N	308	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	al-madar
2257	HATEF	\N	\N	\N	308	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	hatef
2258	LIBYANA	\N	\N	\N	308	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	libyana
2259	LIBYAPHONE MOBILE	\N	\N	\N	308	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	libyaphone mobile
2260	7ACHT	\N	\N	\N	309	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	7acht
2261	CUBIC	\N	\N	\N	309	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	cubic
2262	DATAMOBILE	\N	\N	\N	309	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	datamobile
2263	DIMOCO	\N	\N	\N	309	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	dimoco
2264	EMNIFY	\N	\N	\N	309	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	emnify
2265	FIRST MOBILE AG	\N	\N	\N	309	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	first mobile ag
2266	FL GSM	\N	\N	\N	309	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	fl gsm
2267	FL1	\N	\N	\N	309	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	fl1
2268	SORACOM	\N	\N	\N	309	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	soracom
2269	ALPMOBILE/TELE2	\N	\N	\N	309	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	alpmobile/tele2
2270	TELNA	\N	\N	\N	309	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	telna
2271	BITE	\N	\N	\N	310	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	bite
2272	LTG	\N	\N	\N	310	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	ltg
2273	MEDIAFON	\N	\N	\N	310	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	mediafon
2274	SKYCALL	\N	\N	\N	310	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	skycall
2275	TELE2	\N	\N	\N	310	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	tele2
2276	TELETEL	\N	\N	\N	310	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	teletel
2277	TELIA	\N	\N	\N	310	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	telia
2278	BLUE COMMUNICATIONS	\N	\N	\N	311	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	blue communications
2279	BOUYGUES TELECOM	\N	\N	\N	311	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	bouygues telecom
2280	E-LUX MOBILE	\N	\N	\N	311	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	e-lux mobile
2281	ELTRONA	\N	\N	\N	311	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	eltrona
2282	FIX LINE	\N	\N	\N	311	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	fix line
2283	LUXEMBOURG ONLINE	\N	\N	\N	311	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	luxembourg online
2284	MTX CONNECT	\N	\N	\N	311	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	mtx connect
2285	ORANGE	\N	\N	\N	311	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	orange
2286	POST	\N	\N	\N	311	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	post
2287	TANGO	\N	\N	\N	311	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	tango
2288	C.T.M. TELEMOVEL+	\N	\N	\N	312	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	c.t.m. telemovel+
2289	CHINA TELECOM	\N	\N	\N	312	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	china telecom
2290	HUTCHISON TELEPHONE CO. LTD	\N	\N	\N	312	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	hutchison telephone co. ltd
2457	FAILED CALLS	\N	\N	\N	344	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	failed calls
2291	SMARTONE MOBILE	\N	\N	\N	312	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	smartone mobile
2292	AIRTEL	\N	\N	\N	313	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	airtel
2293	BIP	\N	\N	\N	313	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	bip
2294	ORANGE	\N	\N	\N	313	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	orange
2295	SACEL	\N	\N	\N	313	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	sacel
2296	TELMA	\N	\N	\N	313	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	telma
2297	AIRTEL	\N	\N	\N	314	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	airtel
2298	TNM	\N	\N	\N	314	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	tnm
2299	ALTEL COMMUNICATIONS	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	altel communications
2300	ART900	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	art900
2301	TELEKOM MALAYSIA	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	telekom malaysia
2302	BARAKA TELECOM SDN BHD	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	baraka telecom sdn bhd
2303	CELCOM	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	celcom
2304	DIGI	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	digi
2305	ELECTCOMS WIRELESS SDN BHD	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	electcoms wireless sdn bhd
2306	FIX LINE	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	fix line
2307	MKN	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	mkn
2308	MAXIS	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	maxis
2309	MAXIS BROADBAND	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	maxis broadband
2310	OCESB	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	ocesb
2311	REDTONE MOBILE	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	redtone mobile
2312	REDTONE	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	redtone
2313	SAMATA COMMUNICATIONS SDN BHD	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	samata communications sdn bhd
2314	TT DOTCOM	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	tt dotcom
2315	TUNE TALK	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	tune talk
2316	U MOBILE	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	u mobile
2317	WEBE DIGITAL	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	webe digital
2318	XOX COM	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	xox com
2320	YES	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	yes
2321	DHIRAAGU/C&W	\N	\N	\N	316	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	dhiraagu/c&w
2322	OOREDO/WATANIYA	\N	\N	\N	316	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	ooredo/wataniya
2323	MALITEL	\N	\N	\N	317	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	malitel
2324	ORANGE	\N	\N	\N	317	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	orange
2325	TELECEL	\N	\N	\N	317	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	telecel
2326	VODAFONE	\N	\N	\N	318	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	vodafone
2327	FIX LINE	\N	\N	\N	318	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	fix line
2328	GO MOBILE	\N	\N	\N	318	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	go mobile
2329	MELITA	\N	\N	\N	318	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	melita
2330	FAILED CALLS	\N	\N	\N	319	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	failed calls
2331	MINTA	\N	\N	\N	319	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	minta
2332	UTS CARAIBE	\N	\N	\N	320	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	uts caraibe
2333	CHINGUITEL	\N	\N	\N	321	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	chinguitel
2334	MATTEL	\N	\N	\N	321	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	mattel
2335	MAURITEL	\N	\N	\N	321	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	mauritel
2336	CHILI	\N	\N	\N	322	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	chili
2337	EMTEL	\N	\N	\N	322	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	emtel
2338	MY.T MOBILE	\N	\N	\N	322	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	my.t mobile
2339	MAORE MOBILE	\N	\N	\N	323	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	maore mobile
2340	SFR	\N	\N	\N	323	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	sfr
2341	AT&T/IUSACELL	\N	\N	\N	324	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	at&t/iusacell
2342	MOVISTAR/PEGASO	\N	\N	\N	324	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	movistar/pegaso
2343	NEXTEL	\N	\N	\N	324	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	nextel
2344	OPERADORA UNEFON SA DE CV	\N	\N	\N	324	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	operadora unefon sa de cv
2345	SAI PCS	\N	\N	\N	324	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	sai pcs
2346	TELCEL/AMERICA MOVIL	\N	\N	\N	324	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	telcel/america movil
2347	FSM TELECOMMUNICATIONS CORP.	\N	\N	\N	325	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	fsm telecommunications corp.
2348	EVENTIS MOBILE	\N	\N	\N	326	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	eventis mobile
2349	UNITE	\N	\N	\N	326	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	unite
2350	MOLDCELL	\N	\N	\N	326	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	moldcell
2351	ORANGE	\N	\N	\N	326	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	orange
2352	MONACO TELECOM	\N	\N	\N	327	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	monaco telecom
2353	G-MOBILE CORPORATION LTD	\N	\N	\N	328	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	g-mobile corporation ltd
2354	MOBICOM	\N	\N	\N	328	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	mobicom
2355	SKYTEL CO. LTD	\N	\N	\N	328	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	skytel co. ltd
2356	UNITEL	\N	\N	\N	328	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	unitel
2319	Y-MAX	\N	\N	\N	315	2025-11-18 22:02:33	2025-11-18 22:02:33	\N	\N	\N	\N	f	y-max
2357	MTEL	\N	\N	\N	329	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	mtel
2358	TELEKOM / T-MOBILE	\N	\N	\N	329	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	telekom / t-mobile
2359	TELENOR	\N	\N	\N	329	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	telenor
2360	CABLE & WIRELESS	\N	\N	\N	330	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	cable & wireless
2361	AL HOURIA TELECOM	\N	\N	\N	331	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	al houria telecom
2362	IAM	\N	\N	\N	331	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	iam
2363	INWI	\N	\N	\N	331	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	inwi
2364	ORANGE	\N	\N	\N	331	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	orange
2365	MOVITEL	\N	\N	\N	332	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	movitel
2366	TMCEL	\N	\N	\N	332	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	tmcel
2367	VODACOM	\N	\N	\N	332	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	vodacom
2368	FIX LINE (MYANMAR	\N	\N	\N	333	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	fix line (myanmar
2369	MYANMAR POST & TELECO.	\N	\N	\N	333	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	myanmar post & teleco.
2370	MYTEL (MYANMAR	\N	\N	\N	333	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	mytel (myanmar
2371	OREEDOO	\N	\N	\N	333	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	oreedoo
2372	TELENOR	\N	\N	\N	333	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	telenor
2373	DEMSHI	\N	\N	\N	334	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	demshi
2374	MTC	\N	\N	\N	334	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	mtc
2375	SWITCH/NAM. TELEC.	\N	\N	\N	334	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	switch/nam. telec.
2376	TN MOBILE	\N	\N	\N	334	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	tn mobile
2377	FIX LINE	\N	\N	\N	335	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	fix line
2378	NCELL	\N	\N	\N	335	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	ncell
2379	NT MOBILE / NAMASTE	\N	\N	\N	335	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	nt mobile / namaste
2380	SMART CELL	\N	\N	\N	335	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	smart cell
2381	6GMOBILE BV	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	6gmobile bv
2382	88 MOBILE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	88 mobile
2383	AGMS	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	agms
2384	ASPIDER SOLUTIONS	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	aspider solutions
2385	BELCENTRALE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	belcentrale
2386	BODYTRACE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	bodytrace
2387	COMBIRD MOBILE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	combird mobile
2388	DEAN MOBILE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	dean mobile
2389	EAZIT	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	eazit
2390	ELEPHANTTALK	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	elephanttalk
2391	EZIMOBILE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	ezimobile
2392	FIX LINE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	fix line
2393	INTERACTIVE DIGITAL MEDIA / IDM	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	interactive digital media / idm
2394	INTERCITY MOBILE COMMUNICATIONS BV	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	intercity mobile communications bv
2395	INTOVOICE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	intovoice
2396	KEENMOBILE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	keenmobile
2397	KORE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	kore
2398	KPN/TELFORT	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	kpn/telfort
2399	L-MOBI	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	l-mobi
2400	LANCELOT	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	lancelot
2401	LYCAMOBILE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	lycamobile
2402	MESSAGEBIRD	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	messagebird
2403	MGAGE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	mgage
2404	MOTTO	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	motto
2405	MOVE / TELEENA	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	move / teleena
2406	VECTONE MOBILE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	vectone mobile
2407	OKTA8	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	okta8
2408	PREMIUM ROUTING	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	premium routing
2409	PRIVATE MOBILITY	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	private mobility
2410	PRORAIL	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	prorail
2411	REDWORKS	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	redworks
2412	SPEAKUP	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	speakup
2413	T-MOBILE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	t-mobile
2414	T-MOBILE/FORMER ORANGE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	t-mobile/former orange
2416	TISMI	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	tismi
2417	TRUPHONE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	truphone
2418	UNIFY MOBILE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	unify mobile
2419	VOICEWORKS MOBILE	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	voiceworks mobile
2420	ZIGGO	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	ziggo
2421	ZIGGO SERVICES	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	ziggo services
2422	CINGULAR WIRELESS	\N	\N	\N	336	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	cingular wireless
2423	TELCELL GSM	\N	\N	\N	336	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	telcell gsm
2424	SETEL GSM	\N	\N	\N	336	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	setel gsm
2425	UTS WIRELESS	\N	\N	\N	336	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	uts wireless
2426	OPT MOBILIS	\N	\N	\N	337	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	opt mobilis
2427	2DEGREES	\N	\N	\N	338	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	2degrees
2428	FIX LINE	\N	\N	\N	338	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	fix line
2429	SPARK MOBILE	\N	\N	\N	338	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	spark mobile
2430	TELSTRA	\N	\N	\N	338	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	telstra
2431	VODAFONE	\N	\N	\N	338	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	vodafone
2432	WALKER WIRELESS LTD.	\N	\N	\N	338	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	walker wireless ltd.
2436	CLARO	\N	\N	\N	\N	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	claro
2437	AIRTEL	\N	\N	\N	340	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	airtel
2438	MOOV	\N	\N	\N	340	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	moov
2439	NIGER TELECOMS	\N	\N	\N	340	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	niger telecoms
2440	ORANGE	\N	\N	\N	340	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	orange
2441	9MOBILE	\N	\N	\N	341	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	9mobile
2442	AIRTEL	\N	\N	\N	341	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	airtel
2443	ALPHA TECHNOLOGIES	\N	\N	\N	341	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	alpha technologies
2444	GLO MOBILE	\N	\N	\N	341	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	glo mobile
2445	MTN	\N	\N	\N	341	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	mtn
2446	NTEL	\N	\N	\N	341	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	ntel
2447	SMILE	\N	\N	\N	341	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	smile
2448	STARCOMMS	\N	\N	\N	341	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	starcomms
2449	VISAFONE	\N	\N	\N	341	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	visafone
2450	ZODAFONES	\N	\N	\N	341	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	zodafones
2451	NIUE TELECOM	\N	\N	\N	342	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	niue telecom
2452	FAILED CALLS	\N	\N	\N	343	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	failed calls
2453	KANGSUNG NET	\N	\N	\N	343	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	kangsung net
2454	KORYOLINK	\N	\N	\N	343	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	koryolink
2455	SUN NET	\N	\N	\N	343	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	sun net
2456	A1	\N	\N	\N	344	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	a1
2458	LATRON	\N	\N	\N	344	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	latron
2459	LYCAMOBILE	\N	\N	\N	344	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	lycamobile
2460	MOBIK	\N	\N	\N	344	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	mobik
2461	TELEKABEL	\N	\N	\N	344	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	telekabel
2462	TELEKOM	\N	\N	\N	344	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	telekom
2463	VIP MOBILE	\N	\N	\N	344	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	vip mobile
2464	ALTIBOX MOBIL	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	altibox mobil
2465	BANE NOR	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	bane nor
2466	BIGBLU	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	bigblu
2467	CHILIMOBIL	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	chilimobil
2468	COM4	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	com4
2469	ERATE	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	erate
2470	FIX LINE	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	fix line
2471	GLOBALCONNECT	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	globalconnect
2472	IBIDIUM	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	ibidium
2473	ICE	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	ice
2474	INTILITY	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	intility
2475	IRISTEL	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	iristel
2476	JETNETT	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	jetnett
2477	LYCAMOBILE	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	lycamobile
2478	NETWORK NORWAY	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	network norway
2479	NEXTGENTEL	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	nextgentel
2480	NKOM	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	nkom
2481	NODNETT	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	nodnett
2482	PUZZEL	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	puzzel
2483	SIERRA WIRELESS	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	sierra wireless
2484	SVEA	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	svea
2485	TDC MOBIL A/S	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	tdc mobil a/s
2486	TELAVOX	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	telavox
2487	TELE2	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	tele2
2488	TELENOR	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	telenor
2489	TELETOPIA	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	teletopia
2490	TELIA / NETCOM	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	telia / netcom
2491	UNIFON	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	unifon
2492	VENTELO AS	\N	\N	\N	345	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	ventelo as
2493	NAWRAS	\N	\N	\N	346	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	nawras
2494	OMAN MOBILE/GTO	\N	\N	\N	346	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	oman mobile/gto
2495	FAILED CALLS	\N	\N	\N	347	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	failed calls
2496	INSTAPHONE	\N	\N	\N	347	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	instaphone
2497	JAZZ	\N	\N	\N	347	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	jazz
2498	SCOM	\N	\N	\N	347	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	scom
2499	TELENOR	\N	\N	\N	347	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	telenor
2500	UFONE	\N	\N	\N	347	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	ufone
2501	WARID	\N	\N	\N	347	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	warid
2502	ZONG	\N	\N	\N	347	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	zong
2503	PALAU MOBILE CORP. (PMC) (PALAU	\N	\N	\N	348	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	palau mobile corp. (pmc) (palau
2504	PALAU NATIONAL COMMUNICATIONS CORP. (PNCC) (PALAU	\N	\N	\N	348	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	palau national communications corp. (pncc) (palau
2505	PECI/PALAUTEL (PALAU	\N	\N	\N	348	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	peci/palautel (palau
2506	JAWWAL	\N	\N	\N	349	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	jawwal
2507	OOREDOO	\N	\N	\N	349	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	ooredoo
2508	CABLE & W./MAS MOVIL	\N	\N	\N	350	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	cable & w./mas movil
2509	CLARO	\N	\N	\N	350	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	claro
2510	DIGICEL	\N	\N	\N	350	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	digicel
2511	FIX LINE	\N	\N	\N	350	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	fix line
2512	MOVISTAR	\N	\N	\N	350	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	movistar
2513	DIGICEL	\N	\N	\N	351	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	digicel
2514	FIX LINE	\N	\N	\N	351	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	fix line
2515	GREENCOM PNG LTD	\N	\N	\N	351	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	greencom png ltd
2516	PACIFIC MOBILE	\N	\N	\N	351	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	pacific mobile
2517	CLARO/HUTCHISON	\N	\N	\N	352	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	claro/hutchison
2518	COMPA	\N	\N	\N	352	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	compa
2519	HOLA/VOX	\N	\N	\N	352	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	hola/vox
2520	TIM/NUCLEO/PERSONAL	\N	\N	\N	352	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	tim/nucleo/personal
2521	TIGO/TELECEL	\N	\N	\N	352	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	tigo/telecel
2522	CLARO /AMER.MOV./TIM	\N	\N	\N	353	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	claro /amer.mov./tim
2523	GLOBALSTAR	\N	\N	\N	353	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	globalstar
2524	MOVISTAR	\N	\N	\N	353	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	movistar
2525	NEXTEL	\N	\N	\N	353	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	nextel
2526	VIETTEL MOBILE	\N	\N	\N	353	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	viettel mobile
2527	FIX LINE	\N	\N	\N	354	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	fix line
2528	GLOBE TELECOM	\N	\N	\N	354	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	globe telecom
2529	NEXT MOBILE	\N	\N	\N	354	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	next mobile
2530	RED MOBILE/CURE	\N	\N	\N	354	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	red mobile/cure
2531	SMART	\N	\N	\N	354	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	smart
2532	SUN/DIGITEL	\N	\N	\N	354	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	sun/digitel
2533	3S	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	3s
2534	AERO2	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	aero2
2535	AERO2 SP	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	aero2 sp
2536	AGILE TELECOM	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	agile telecom
2537	AMD TELECOM	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	amd telecom
2538	BENEMEN	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	benemen
2539	BSG	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	bsg
2540	CALLFREEDOM SP. Z O.O.	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	callfreedom sp. z o.o.
2541	CARITAS LACZY	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	caritas laczy
2542	CLUDO	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	cludo
2543	COMPATEL	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	compatel
2544	CYFROWY POLSAT	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	cyfrowy polsat
2545	E-TELKO	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	e-telko
2546	EZ MOBILE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	ez mobile
2547	FIX LINE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	fix line
2548	I.M. CONSULTING	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	i.m. consulting
2549	INEA	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	inea
2550	IZZI	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	izzi
2551	JMDI J. MALESZKO	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	jmdi j. maleszko
2552	KLUCZ MOBILE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	klucz mobile
2553	LAJT MOBILE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	lajt mobile
2554	LOVO	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	lovo
2555	LYCAMOBILE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	lycamobile
2556	MESSAGEBIRD	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	messagebird
2557	METRO MOBILE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	metro mobile
2558	MOBILE VIKINGS	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	mobile vikings
2559	MOBILEDATA	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	mobiledata
2560	MOBIWEB	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	mobiweb
2561	MOBYLAND	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	mobyland
2562	MOJA GSM	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	moja gsm
2563	MOVE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	move
2564	MULTIMOBILE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	multimobile
2565	MUNDIO MOBILE SP. Z O.O.	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	mundio mobile sp. z o.o.
2566	NASZA WIZJA	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	nasza wizja
2567	NAU MOBILE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	nau mobile
2568	NC+ MOBILE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	nc+ mobile
2569	NETBALT	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	netbalt
2570	NETIA	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	netia
2571	NEXT MOBILE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	next mobile
2572	NIMBOW	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	nimbow
2573	NORDISK POLSKA	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	nordisk polska
2574	NTEL SOLUTIONS	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	ntel solutions
2575	ORANGE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	orange
2576	PKP	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	pkp
2577	PLAY	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	play
2578	PLUS	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	plus
2579	POLITECHNIKA LODZKA UCZELNIANE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	politechnika lodzka uczelniane
2580	POLSKA SPOLKA GAZOWNICTWA	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	polska spolka gazownictwa
2581	POLVOICE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	polvoice
2582	POMAGACZ	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	pomagacz
2583	PREMIUM MOBILE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	premium mobile
2584	SAT FILM	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	sat film
2585	SGT	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	sgt
2586	SMSHIGHWAY	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	smshighway
2587	SOFTELNET	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	softelnet
2588	T-MOBILE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	t-mobile
2589	TELCO LEADERS	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	telco leaders
2590	TELE GO	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	tele go
2591	TELECUBE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	telecube
2592	TELENABLER	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	telenabler
2593	TELGAM	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	telgam
2594	TISMI	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	tismi
2595	TOYAMOBILNA	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	toyamobilna
2596	TWILIO	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	twilio
2597	UPC	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	upc
2598	VECTRA	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	vectra
2599	VIRGIN MOBILE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	virgin mobile
2600	VONAGE	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	vonage
2601	VOXBONE / BANDWIDTH	\N	\N	\N	355	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	voxbone / bandwidth
2602	FIX LINE	\N	\N	\N	356	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	fix line
2603	LYCAMOBILE	\N	\N	\N	356	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	lycamobile
2604	MEO	\N	\N	\N	356	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	meo
2605	NOS	\N	\N	\N	356	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	nos
2606	NOWO	\N	\N	\N	356	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	nowo
2607	ONI	\N	\N	\N	356	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	oni
2608	VODAFONE	\N	\N	\N	356	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	vodafone
2609	PUERTO RICO TELEPHONE COMPANY INC. (PRTC)	\N	\N	\N	357	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	puerto rico telephone company inc. (prtc)
2610	OOREDOO/QTEL	\N	\N	\N	358	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	ooredoo/qtel
2611	VODAFONE	\N	\N	\N	358	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	vodafone
2612	ONLY	\N	\N	\N	359	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	only
2613	ORANGE	\N	\N	\N	359	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	orange
2614	SFR	\N	\N	\N	359	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	sfr
2615	ZEOP MOBILE	\N	\N	\N	359	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	zeop mobile
2616	DIGI MOBIL	\N	\N	\N	360	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	digi mobil
2617	ENIGMA SYSTEMS	\N	\N	\N	360	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	enigma systems
2618	IRISTEL	\N	\N	\N	360	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	iristel
2619	LYCAMOBILE	\N	\N	\N	360	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	lycamobile
2620	ORANGE	\N	\N	\N	360	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	orange
2621	ROMTELECOM SA	\N	\N	\N	360	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	romtelecom sa
2622	TELEKOM	\N	\N	\N	360	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	telekom
2623	TELEKOM ROMANIA	\N	\N	\N	360	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	telekom romania
2624	VODAFONE	\N	\N	\N	360	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	vodafone
2625	A-MOBILE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	a-mobile
2626	ANTARES	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	antares
2627	AQUAFON	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	aquafon
2628	ARKTUR	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	arktur
2629	ASTRAN	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	astran
2630	ASVT	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	asvt
2631	AURORA TELECOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	aurora telecom
2632	BEELINE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	beeline
2633	BEELINE/VIMPELCOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	beeline/vimpelcom
2634	BELITON	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	beliton
2635	BIT-CENTR	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	bit-centr
2636	CENTER 2M	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	center 2m
2637	CIFRA 1	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	cifra 1
2638	COUNTRYCOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	countrycom
2639	DTC/DON TELECOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	dtc/don telecom
2640	ECO NETWORKS	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	eco networks
2641	ELEMTE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	elemte
2642	ER-TELECOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	er-telecom
2643	FAILED CALLS	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	failed calls
2644	FIX LINE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	fix line
2645	GAZPROM TELECOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	gazprom telecom
2646	GLOBAL TELECOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	global telecom
2648	GLONASS MOBILE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	glonass mobile
2649	INTEGRAL	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	integral
2650	INTERNOD	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	internod
2651	INTERSVYAZ-2	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	intersvyaz-2
2652	KRYMTELECOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	krymtelecom
2647	GLONASS	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	glonass
2653	KUBAN GSM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	kuban gsm
2654	KVATROPLUS	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	kvatroplus
2655	LARDEX	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	lardex
2656	LETAI MOBILE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	letai mobile
2657	LYCAMOBILE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	lycamobile
2658	MATRIX MOBILE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	matrix mobile
2659	MEDIA-MARKET	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	media-market
2660	MEGAFON	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	megafon
2661	METRO-PEI	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	metro-pei
2662	MGTS	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	mgts
2663	MIATEL	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	miatel
2664	MOSTELECOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	mostelecom
2665	MOTIV	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	motiv
2666	MSN TELEKOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	msn telekom
2667	MTS	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	mts
2668	MTT	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	mtt
2669	NCC	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	ncc
2670	NCI	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	nci
2671	NETBYNET	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	netbynet
2672	NEW MOBILE COMMUNICATIONS	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	new mobile communications
2673	NTC	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	ntc
2674	OBIT	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	obit
2675	OJSC ALTAYSVYAZ	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	ojsc altaysvyaz
2676	ORANGE BUSINESS SERVICES	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	orange business services
2677	PIN	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	pin
2678	PLINTRON	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	plintron
2679	PRINTELEFONE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	printelefone
2680	QUANTECH	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	quantech
2681	RECONN	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	reconn
2682	RETEYL INNOVATSII	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	reteyl innovatsii
2683	SBERBANK-TELECOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	sberbank-telecom
2684	SEVTELECOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	sevtelecom
2685	SIBCHALLENGE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	sibchallenge
2686	SIM SIM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	sim sim
2687	SINTONIK	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	sintonik
2688	SKY NETWORKS	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	sky networks
2689	SKYLINK	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	skylink
2690	SKYNET	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	skynet
2691	SONET	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	sonet
2692	SPRINT	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	sprint
2693	START	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	start
2694	STAVTELESOT	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	stavtelesot
2695	SUNSIM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	sunsim
2696	SURGUTNEFTEGAZ	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	surgutneftegaz
2697	SVYAZRESURS-MOBILE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	svyazresurs-mobile
2698	TANDER	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	tander
2699	TELE2	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	tele2
2700	TELE2/ECC/VOLGOGR.	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	tele2/ecc/volgogr.
2701	TELECOM XXL	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	telecom xxl
2702	TINKOFF MOBILE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	tinkoff mobile
2703	TMT	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	tmt
2704	TRANSMOBILCOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	transmobilcom
2705	TRASTEL	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	trastel
2706	TRN-TELECOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	trn-telecom
2707	TTK	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	ttk
2708	TTK-SVYAZ	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	ttk-svyaz
2709	TVE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	tve
2710	UNITTELECOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	unittelecom
2711	UNYCEL	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	unycel
2713	VAINAH TELECOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	vainah telecom
2714	VIKOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	vikom
2715	VIRGIN CONNECT	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	virgin connect
2716	VOENTELECOM	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	voentelecom
2717	VOLNA MOBILE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	volna mobile
2718	VTB MOBILE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	vtb mobile
2719	WIN MOBILE	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	win mobile
2720	YOTA	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	yota
2721	ZAO SMARTS	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	zao smarts
2722	AIRTEL	\N	\N	\N	362	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	airtel
2723	MTN	\N	\N	\N	362	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	mtn
2724	FAILED CALLS	\N	\N	\N	363	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	failed calls
2725	CABLE & WIRELESS	\N	\N	\N	364	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	cable & wireless
2726	DIGICEL	\N	\N	\N	364	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	digicel
2727	UTS CARIGLOBE	\N	\N	\N	364	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	uts cariglobe
2728	CABLE & WIRELESS	\N	\N	\N	365	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	cable & wireless
2729	CINGULAR WIRELESS	\N	\N	\N	365	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	cingular wireless
2730	DIGICEL (ST LUCIA) LIMITED	\N	\N	\N	365	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	digicel (st lucia) limited
2731	AMERIS	\N	\N	\N	366	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	ameris
2732	C & W	\N	\N	\N	367	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	c & w
2733	CINGULAR	\N	\N	\N	367	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	cingular
2734	DIGICEL	\N	\N	\N	367	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	digicel
2735	FIX LINE	\N	\N	\N	368	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	fix line
2736	SAMOATEL MOBILE	\N	\N	\N	368	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	samoatel mobile
2737	TELECOM SAMOA CELLULAR LTD.	\N	\N	\N	368	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	telecom samoa cellular ltd.
2738	PRIMA	\N	\N	\N	369	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	prima
2739	TELENET	\N	\N	\N	369	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	telenet
2740	CSTMOVEL	\N	\N	\N	370	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	cstmovel
2741	UNITEL	\N	\N	\N	370	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	unitel
2742	AEROMOBILE	\N	\N	\N	287	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	aeromobile
2743	INMARSAT	\N	\N	\N	287	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	inmarsat
2744	MARITIME COMMUNICATIONS PARTNER AS	\N	\N	\N	287	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	maritime communications partner as
2745	THURAYA SATELLITE	\N	\N	\N	287	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	thuraya satellite
2746	ZAIN	\N	\N	\N	371	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	zain
2747	ETIHAD/ETISALAT/MOBILY	\N	\N	\N	371	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	etihad/etisalat/mobily
2748	LEBARA MOBILE	\N	\N	\N	371	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	lebara mobile
2750	VIRGIN MOBILE	\N	\N	\N	371	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	virgin mobile
2751	2S MOBILE	\N	\N	\N	372	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	2s mobile
2752	EXPRESSO	\N	\N	\N	372	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	expresso
2753	FREE	\N	\N	\N	372	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	free
2754	HAYO	\N	\N	\N	372	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	hayo
2755	ORANGE	\N	\N	\N	372	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	orange
2756	PROMOBILE	\N	\N	\N	372	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	promobile
2757	FAILED CALLS	\N	\N	\N	373	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	failed calls
2758	GLOBALTEL	\N	\N	\N	373	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	globaltel
2759	MTS	\N	\N	\N	373	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	mts
2760	TELENOR	\N	\N	\N	373	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	telenor
2761	VIP	\N	\N	\N	373	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	vip
2762	AIRTEL	\N	\N	\N	374	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	airtel
2763	CABLE & WIRELESS	\N	\N	\N	374	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	cable & wireless
2764	INTELVISION	\N	\N	\N	374	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	intelvision
2765	SMARTCOM	\N	\N	\N	374	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	smartcom
2766	AFRICELL	\N	\N	\N	375	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	africell
2767	COMIUM	\N	\N	\N	375	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	comium
2768	IPTEL	\N	\N	\N	375	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	iptel
2769	TIGO/MILLICOM	\N	\N	\N	375	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	tigo/millicom
2770	MOBITEL	\N	\N	\N	375	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	mobitel
2771	ONLIME	\N	\N	\N	375	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	onlime
2772	ORANGE	\N	\N	\N	375	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	orange
2773	QCELL	\N	\N	\N	375	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	qcell
2774	SIERRATEL	\N	\N	\N	375	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	sierratel
2775	FIX LINE	\N	\N	\N	376	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	fix line
2776	GRID COMMUNICATIONS PTE LTD	\N	\N	\N	376	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	grid communications pte ltd
2777	MOBILEONE LTD	\N	\N	\N	376	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	mobileone ltd
2778	SINGTEL	\N	\N	\N	376	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	singtel
2779	STARHUB	\N	\N	\N	376	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	starhub
2780	O2	\N	\N	\N	377	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	o2
2781	ORANGE	\N	\N	\N	377	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	orange
2782	SWAN / 4KA	\N	\N	\N	377	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	swan / 4ka
2783	TELEKOM	\N	\N	\N	377	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	telekom
2784	UNIPHONE	\N	\N	\N	377	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	uniphone
2785	VONAGE	\N	\N	\N	377	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	vonage
2786	ZSR	\N	\N	\N	377	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	zsr
2787	A1 / SI.MOBIL	\N	\N	\N	378	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	a1 / si.mobil
2788	COMPATEL	\N	\N	\N	378	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	compatel
2789	ELEKTRO GORENJSKA	\N	\N	\N	378	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	elektro gorenjska
2790	FIX LINE	\N	\N	\N	378	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	fix line
2791	HOT MOBIL	\N	\N	\N	378	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	hot mobil
2792	ME2	\N	\N	\N	378	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	me2
2793	MOBITEL	\N	\N	\N	378	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	mobitel
2794	NOVATEL	\N	\N	\N	378	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	novatel
2795	SLOVENSKE ZELEZNICE	\N	\N	\N	378	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	slovenske zeleznice
2796	SOFTNET	\N	\N	\N	378	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	softnet
2797	T-2	\N	\N	\N	378	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	t-2
2798	TELEMACH / TUSMOBIL	\N	\N	\N	378	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	telemach / tusmobil
2799	BEMOBILE	\N	\N	\N	379	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	bemobile
2800	BREEZE	\N	\N	\N	379	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	breeze
2801	AIRSOM	\N	\N	\N	380	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	airsom
2802	GOLIS	\N	\N	\N	380	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	golis
2803	HORMUUD	\N	\N	\N	380	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	hormuud
2804	NATIONLINK	\N	\N	\N	380	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	nationlink
2805	NETCO	\N	\N	\N	380	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	netco
2806	ONKOD	\N	\N	\N	380	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	onkod
2807	SOMAFONE	\N	\N	\N	380	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	somafone
2808	SOMNETWORKS	\N	\N	\N	380	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	somnetworks
2809	SOMTEL	\N	\N	\N	380	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	somtel
2810	STG	\N	\N	\N	380	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	stg
2811	TELCOM MOBILE	\N	\N	\N	380	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	telcom mobile
2812	TELESOM	\N	\N	\N	380	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	telesom
2813	CAPE TOWN METROPOLITAN	\N	\N	\N	381	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	cape town metropolitan
2814	CELL C	\N	\N	\N	381	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	cell c
2815	LYCAMOBILE	\N	\N	\N	381	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	lycamobile
2816	MTN	\N	\N	\N	381	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	mtn
2817	RAIN	\N	\N	\N	381	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	rain
2818	SENTECH	\N	\N	\N	381	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	sentech
2819	TELKOM	\N	\N	\N	381	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	telkom
2820	VODACOM	\N	\N	\N	381	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	vodacom
2821	FAILED CALLS	\N	\N	\N	382	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	failed calls
2822	OLLEH / KT	\N	\N	\N	382	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	olleh / kt
2823	KT POWERTEL	\N	\N	\N	382	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	kt powertel
2824	LG U+	\N	\N	\N	382	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	lg u+
2825	SK TELECOM	\N	\N	\N	382	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	sk telecom
2826	DIGITEL	\N	\N	\N	383	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	digitel
2827	FAILED CALLS	\N	\N	\N	383	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	failed calls
2828	GEMTEL LTD (SOUTH SUDAN	\N	\N	\N	383	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	gemtel ltd (south sudan
2829	MTN	\N	\N	\N	383	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	mtn
2830	NETWORK OF THE WORLD LTD (NOW) (SOUTH SUDAN	\N	\N	\N	383	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	network of the world ltd (now) (south sudan
2831	ZAIN	\N	\N	\N	383	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	zain
2832	ACN	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	acn
2833	ADAMO TELECOM	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	adamo telecom
2834	ALAI	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	alai
2835	ALTA TECNOLOGIA EN COMUNICACIONS	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	alta tecnologia en comunicacions
2836	AUREA	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	aurea
2837	AVATEL MOVIL	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	avatel movil
2838	DIGI.MOBIL	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	digi.mobil
2839	BILLING FINANCIAL	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	billing financial
2840	BLUEPHONE	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	bluephone
2842	CABLEUROPA SAU (ONO)	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	cableuropa sau (ono)
2843	CLOUDCOMMS	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	cloudcomms
2844	DIALOGA	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	dialoga
2845	DRAGONET	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	dragonet
2846	EUSKALTEL MOVIL	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	euskaltel movil
2847	EVOLUTIO	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	evolutio
2848	FIX LINE	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	fix line
2849	FONYOU WIRELESS SL	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	fonyou wireless sl
2850	GLOBAL	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	global
2851	GNET	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	gnet
2852	ION MOBILE	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	ion mobile
2853	JAZZ TELECOM SAU	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	jazz telecom sau
2854	JETNET	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	jetnet
2855	LEMONVIL	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	lemonvil
2856	LLEIDA	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	lleida
2857	LYCAMOBILE	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	lycamobile
2858	MOBIL R	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	mobil r
2859	MOVISTAR	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	movistar
2860	OLEPHONE	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	olephone
2861	ON MOVIL	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	on movil
2862	ONITI TELECOM	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	oniti telecom
2863	OPERADORSCAT	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	operadorscat
2864	ORANGE	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	orange
2865	PEPEPHONE	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	pepephone
2866	PTV TELECOM MOVIL	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	ptv telecom movil
2867	QUATTRE	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	quattre
2868	R CABLE Y TELEC. GALICIA SA	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	r cable y telec. galicia sa
2869	SARENET	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	sarenet
2870	SEWAN	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	sewan
2871	SIMYO	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	simyo
2872	SUMA MOVIL	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	suma movil
2873	SUOP	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	suop
2874	SYMA	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	syma
2875	TELSOME	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	telsome
2876	THE TELECOM BOUTIQUE	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	the telecom boutique
2877	TRUPHONE	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	truphone
2878	VENUS MOVIL	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	venus movil
2879	VODAFONE	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	vodafone
2880	YOIGO	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	yoigo
2881	YOU MOBILE	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	you mobile
2882	ZINNIA	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	zinnia
2883	AIRTEL	\N	\N	\N	385	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	airtel
2884	ETISALAT/TIGO	\N	\N	\N	385	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	etisalat/tigo
2885	H3G HUTCHISON	\N	\N	\N	385	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	h3g hutchison
2886	MOBITEL LTD.	\N	\N	\N	385	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	mobitel ltd.
2887	MTN/DIALOG	\N	\N	\N	385	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	mtn/dialog
2888	CANAR TELECOM	\N	\N	\N	386	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	canar telecom
2889	FIX LINE	\N	\N	\N	386	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	fix line
2890	MTN	\N	\N	\N	386	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	mtn
2891	SUDANI ONE	\N	\N	\N	386	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	sudani one
2892	ZAIN	\N	\N	\N	386	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	zain
2893	DIGICEL	\N	\N	\N	387	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	digicel
2894	FIX LINE	\N	\N	\N	387	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	fix line
2895	TELESUR	\N	\N	\N	387	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	telesur
2896	TELECOMMUNICATIEBEDRIJF SURINAME (TELESUR)	\N	\N	\N	387	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	telecommunicatiebedrijf suriname (telesur)
2897	UNIQA	\N	\N	\N	387	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	uniqa
2898	ESWATINI MOBILE	\N	\N	\N	388	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	eswatini mobile
2899	ESWATINITELECOM	\N	\N	\N	388	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	eswatinitelecom
2900	SWAZI MTN	\N	\N	\N	388	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	swazi mtn
2901	42 TELECOM AB	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	42 telecom ab
2902	42 TELECOM	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	42 telecom
2903	A3	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	a3
2904	NEXTGEN MOBILE LTD (CARDBOARDFISH)	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	nextgen mobile ltd (cardboardfish)
2905	COM HEM	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	com hem
2906	COM4	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	com4
2907	COMPATEL	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	compatel
2908	EUTEL	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	eutel
2909	FINK TELECOM	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	fink telecom
2910	FIX LINE	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	fix line
2911	MESSIT / MINICALL	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	messit / minicall
2912	GLOBETOUCH	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	globetouch
2913	GOTANET	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	gotanet
2914	3	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	3
2915	INFOBIP	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	infobip
2916	INTERACTIVE DIGITAL MEDIA / IDM	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	interactive digital media / idm
2917	LINK MOBILITY	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	link mobility
2918	LYCAMOBILE	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	lycamobile
2919	MI CARRIER SERVICES	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	mi carrier services
2920	MOBILE ARTS	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	mobile arts
2921	MOBIWEB	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	mobiweb
2922	MONTY MOBILE	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	monty mobile
2923	NETMORE	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	netmore
2924	PRIMLIGHT	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	primlight
2925	REBTEL	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	rebtel
2926	SIERRA WIRELESS	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	sierra wireless
2927	SIERRA WIRELESS SWEDEN AB	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	sierra wireless sweden ab
2928	SINCH	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	sinch
2929	SPIRIUS	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	spirius
2930	SPRING MOBIL AB	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	spring mobil ab
2931	TELE2	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	tele2
2932	TELENABLER	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	telenabler
2933	TELENOR	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	telenor
2934	TELENOR CONNEXION	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	telenor connexion
2935	TELIA	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	telia
2936	NET 1	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	net 1
2937	TISMI	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	tismi
2938	TRAFIKVERKET	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	trafikverket
2939	TWILIO	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	twilio
2940	VECTONE MOBILE	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	vectone mobile
2941	VIAHUB	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	viahub
2942	VIATEL	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	viatel
2943	VOXBONE / BANDWIDTH	\N	\N	\N	389	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	voxbone / bandwidth
2944	BEEONE	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	beeone
2945	COMFONE	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	comfone
2946	FIX LINE	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	fix line
2947	SUNRISE	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	sunrise
2948	INOVIA	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	inovia
2949	LYCAMOBILE	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	lycamobile
2950	MTEL	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	mtel
2951	MUNDIO MOBILE AG	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	mundio mobile ag
2952	NEXPHONE	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	nexphone
2953	RELARIO	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	relario
2954	SALT MOBILE	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	salt mobile
2955	SBB	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	sbb
2956	SWISSCOM	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	swisscom
2957	TELECOM26	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	telecom26
2958	TISMI	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	tismi
2959	UPC CABLECOM GMBH	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	upc cablecom gmbh
2960	VECTONE MOBILE	\N	\N	\N	390	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	vectone mobile
2961	MTN/SPACETEL	\N	\N	\N	391	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	mtn/spacetel
2962	SYRIATEL HOLDINGS	\N	\N	\N	391	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	syriatel holdings
2963	ACES TAIWAN - ACES TAIWAN TELECOMMUNICATIONS CO LTD	\N	\N	\N	392	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	aces taiwan - aces taiwan telecommunications co ltd
2964	ASIA PACIFIC TELECOM CO. LTD (APT)	\N	\N	\N	392	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	asia pacific telecom co. ltd (apt)
2965	CHUNGHWA TELECOM LDM	\N	\N	\N	392	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	chunghwa telecom ldm
2966	FAR EASTONE	\N	\N	\N	392	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	far eastone
2967	GLOBAL MOBILE CORP.	\N	\N	\N	392	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	global mobile corp.
2968	INTERNATIONAL TELECOM CO. LTD (FITEL)	\N	\N	\N	392	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	international telecom co. ltd (fitel)
2969	KG TELECOM	\N	\N	\N	392	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	kg telecom
2970	T-STAR/VIBO	\N	\N	\N	392	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	t-star/vibo
2971	TRANSASIA	\N	\N	\N	392	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	transasia
2972	TAIWAN CELLULAR	\N	\N	\N	392	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	taiwan cellular
2973	MOBITAI	\N	\N	\N	392	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	mobitai
2974	VMAX TELECOM CO. LTD	\N	\N	\N	392	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	vmax telecom co. ltd
2975	BABILON-M	\N	\N	\N	393	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	babilon-m
2976	BEE LINE	\N	\N	\N	393	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	bee line
2977	CJSC INDIGO TAJIKISTAN	\N	\N	\N	393	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	cjsc indigo tajikistan
2978	TCELL/JC SOMONCOM	\N	\N	\N	393	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	tcell/jc somoncom
2979	MEGAFON	\N	\N	\N	393	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	megafon
2980	AIRTEL	\N	\N	\N	394	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	airtel
2981	BENSON INFORMATICS LTD	\N	\N	\N	394	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	benson informatics ltd
2982	DOVETEL (T) LTD	\N	\N	\N	394	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	dovetel (t) ltd
2983	HALOTEL / VIETTEL	\N	\N	\N	394	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	halotel / viettel
2984	MKULIMA AFRICAN TELECOMMUNICATION	\N	\N	\N	394	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	mkulima african telecommunication
2985	MO MOBILE	\N	\N	\N	394	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	mo mobile
2986	SMILE COMMUNICATIONS	\N	\N	\N	394	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	smile communications
2987	TANZANIA TELECOMMUNICATION CORPORATION	\N	\N	\N	394	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	tanzania telecommunication corporation
2988	TIGO / MIC	\N	\N	\N	394	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	tigo / mic
2989	TRI TELECOMM. LTD.	\N	\N	\N	394	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	tri telecomm. ltd.
2990	VODACOM	\N	\N	\N	394	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	vodacom
2991	WIAFRICA	\N	\N	\N	394	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	wiafrica
2992	ZANZIBAR TELECOM / ZANTEL	\N	\N	\N	394	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	zanzibar telecom / zantel
2993	ACES THAILAND - ACES REGIONAL SERVICES CO LTD	\N	\N	\N	395	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	aces thailand - aces regional services co ltd
2994	ACT MOBILE	\N	\N	\N	395	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	act mobile
2995	AIS/ADVANCED INFO SERVICE	\N	\N	\N	395	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	ais/advanced info service
2996	DIGITAL PHONE CO.	\N	\N	\N	395	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	digital phone co.
2997	FIX LINE	\N	\N	\N	395	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	fix line
2998	HUTCH/CAT CDMA	\N	\N	\N	395	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	hutch/cat cdma
2999	TOTAL ACCESS (DTAC)	\N	\N	\N	395	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	total access (dtac)
3000	TRUE MOVE/ORANGE	\N	\N	\N	395	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	true move/orange
3001	ATLANTIQUE TELECOM / MOOV	\N	\N	\N	396	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	atlantique telecom / moov
3002	TELECEL/MOOV	\N	\N	\N	396	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	telecel/moov
3003	TOGO CELLULAIRE / TOGOCEL	\N	\N	\N	396	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	togo cellulaire / togocel
3004	DIGICEL	\N	\N	\N	397	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	digicel
3005	FIX LINE	\N	\N	\N	397	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	fix line
3006	SHORELINE COMMUNICATION	\N	\N	\N	397	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	shoreline communication
3007	TONGA COMMUNICATIONS	\N	\N	\N	397	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	tonga communications
3008	BMOBILE/TSTT	\N	\N	\N	398	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	bmobile/tstt
3009	DIGICEL	\N	\N	\N	398	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	digicel
3010	LAQTEL LTD.	\N	\N	\N	398	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	laqtel ltd.
3011	FIX LINE	\N	\N	\N	399	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	fix line
3012	LYCAMOBILE	\N	\N	\N	399	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	lycamobile
3013	OOREDOO	\N	\N	\N	399	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	ooredoo
3014	ORANGE	\N	\N	\N	399	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	orange
3015	TT MOBILE	\N	\N	\N	399	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	tt mobile
3016	ASISTAN TELEKOM	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	asistan telekom
3017	AVEA	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	avea
3018	BASAKCELL	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	basakcell
3019	COMPATEL	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	compatel
3020	FENIX TELEKOM	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	fenix telekom
3021	FIX LINE	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	fix line
3022	FONIVA	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	foniva
3023	ISNET	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	isnet
3024	MAXIPHONE	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	maxiphone
3025	MEDIUM TELEKOM	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	medium telekom
3026	MOBILISIM	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	mobilisim
3027	NETGSM	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	netgsm
3028	NIDA	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	nida
3029	ORIS	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	oris
3030	PELICELL	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	pelicell
3031	PLUS TELEKOM	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	plus telekom
3032	ROITEL	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	roitel
3033	SESNET	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	sesnet
3034	TCDD	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	tcdd
3035	TTM	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	ttm
3036	TURKCELL	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	turkcell
3037	VODAFONE	\N	\N	\N	400	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	vodafone
3038	MTS/BARASH COMMUNICATION	\N	\N	\N	401	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	mts/barash communication
3039	ALTYN ASYR/TM-CELL	\N	\N	\N	401	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	altyn asyr/tm-cell
3040	CABLE & WIRELESS (TCI) LTD	\N	\N	\N	402	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	cable & wireless (tci) ltd
3041	DIGICEL TCI LTD	\N	\N	\N	402	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	digicel tci ltd
3042	ISLANDCOM COMMUNICATIONS LTD.	\N	\N	\N	402	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	islandcom communications ltd.
3043	TUVALU TELECOMMUNICATION CORPORATION (TTC)	\N	\N	\N	403	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	tuvalu telecommunication corporation (ttc)
3044	AIRTEL	\N	\N	\N	404	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	airtel
3045	FIX LINE	\N	\N	\N	404	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	fix line
3046	I-TEL LTD	\N	\N	\N	404	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	i-tel ltd
3047	K2 TELECOM LTD	\N	\N	\N	404	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	k2 telecom ltd
3048	LYCAMOBILE	\N	\N	\N	404	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	lycamobile
3049	MANGO	\N	\N	\N	404	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	mango
3050	MTN	\N	\N	\N	404	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	mtn
3051	ORANGE	\N	\N	\N	404	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	orange
3052	SMILE	\N	\N	\N	404	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	smile
3053	SURETELECOM UGANDA LTD	\N	\N	\N	404	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	suretelecom uganda ltd
3054	3MOB	\N	\N	\N	405	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	3mob
3055	GOLDEN TELECOM	\N	\N	\N	405	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	golden telecom
3056	IT	\N	\N	\N	405	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	it
3057	KYIVSTAR	\N	\N	\N	405	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	kyivstar
3058	LIFECELL	\N	\N	\N	405	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	lifecell
3059	PEOPLENET	\N	\N	\N	405	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	peoplenet
3060	PHOENIX	\N	\N	\N	405	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	phoenix
3061	VODAFONE	\N	\N	\N	405	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	vodafone
3062	DU	\N	\N	\N	406	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	du
3063	ETISALAT	\N	\N	\N	406	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	etisalat
3064	08DIRECT	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	08direct
3065	24SEVEN	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	24seven
3066	ACE CALL	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	ace call
3067	AIRWAVE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	airwave
3068	ANDREWS & ARNOLD	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	andrews & arnold
3069	ANYWHERE SIM	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	anywhere sim
3070	AQL	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	aql
3071	AQL WHOLESALE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	aql wholesale
3072	VOXBONE / BANDWIDTH	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	voxbone / bandwidth
3073	BELLINGHAM TELECOMMUNICATIONS	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	bellingham telecommunications
3074	BT GROUP	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	bt group
3075	BT ONEPHONE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	bt onephone
3076	CFL COMMUNICATIONS	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	cfl communications
3077	CITRUS	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	citrus
3078	CLOUD9	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	cloud9
3079	COMPATEL	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	compatel
3080	CONFABULATE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	confabulate
3081	CORE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	core
3082	CORE TELECOM	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	core telecom
3083	CORE TELECOM LTD	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	core telecom ltd
3084	DMB	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	dmb
3085	EVERYTH. EV.WH.	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	everyth. ev.wh.
3086	T-MOBILE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	t-mobile
3087	FIX LINE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	fix line
3088	FLEXTEL	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	flextel
3089	FMS SOLUTIONS	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	fms solutions
3090	FOGG	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	fogg
3091	GAMMA MOBILE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	gamma mobile
3092	GLOBAL REACH NETWORKS	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	global reach networks
3093	GREENFONE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	greenfone
3094	HANHAA MOBILE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	hanhaa mobile
3095	HOME OFFICE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	home office
3096	3	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	3
3097	ICRON NETWORK	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	icron network
3098	IPV6	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	ipv6
3099	IV RESPONSE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	iv response
3100	JERSEY AIRTEL	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	jersey airtel
3101	JSC INGENICUM	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	jsc ingenicum
3102	JT MOBILE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	jt mobile
3103	KONTAKT MOBILE	\N	\N	\N	407	2025-11-18 22:02:37	2025-11-18 22:02:37	\N	\N	\N	\N	f	kontakt mobile
3104	LANONYX TELECOM	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	lanonyx telecom
3105	LINK MOBILITY	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	link mobility
3106	LLEIDA.NET	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	lleida.net
3107	LYCAMOBILE	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	lycamobile
3108	MAGRATHEA TELECOMMUNICATIONS	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	magrathea telecommunications
3109	MANX TELECOM MOBILE	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	manx telecom mobile
3110	MARATHON TELECOM	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	marathon telecom
3111	MARS COMMUNICATIONS	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	mars communications
3112	MASS RESPONSE SERVICE GMBH	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	mass response service gmbh
3113	MOBIWEB	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	mobiweb
3114	NCSC	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	ncsc
3115	NETWORK RAIL	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	network rail
3116	NODEMAX	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	nodemax
3117	NOW BROADBAND	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	now broadband
3118	NTA	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	nta
3119	ORANGE	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	orange
3120	PARETEUM	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	pareteum
3121	PREMIUM ROUTING	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	premium routing
3122	QX	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	qx
3123	RESILIENT	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	resilient
3124	SARK TELECOM	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	sark telecom
3125	SIMWOOD ESMS	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	simwood esms
3126	SKY	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	sky
3127	SOUND ADVERTISING	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	sound advertising
3128	SPACETEL	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	spacetel
3129	SPUSU	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	spusu
3130	SURE GUERNSEY	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	sure guernsey
3131	SURE ISLE OF MAN	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	sure isle of man
3132	SURE JERSEY	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	sure jersey
3133	SWIFTNET	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	swiftnet
3134	SYNECTIV	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	synectiv
3135	TALK TALK	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	talk talk
3136	TANGO NETWORKS	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	tango networks
3137	TATA COMMUNICATIONS LTD	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	tata communications ltd
3138	TELECOM 10	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	telecom 10
3139	TELECOM2	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	telecom2
3140	VODAFONE	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	vodafone
3141	O2	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	o2
3142	TELESIGN MOBILE	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	telesign mobile
3143	TELEWARE	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	teleware
3144	TELNA MOBILE	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	telna mobile
3145	TGL SERVICES	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	tgl services
3146	TISMI	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	tismi
3147	TRUPHONE	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	truphone
3148	VECTONE MOBILE	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	vectone mobile
3149	VIRGIN MOBILE	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	virgin mobile
3150	VOICETEC SYSTEMS	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	voicetec systems
3151	ZIRON	\N	\N	\N	407	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	ziron
3152	AERIS COMM. INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	aeris comm. inc.
3153	AIRTEL WIRELESS LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	airtel wireless llc
3154	UNKNOWN	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	unknown
3155	ALLIED WIRELESS COMMUNICATIONS CORPORATION	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	allied wireless communications corporation
3156	ARCTIC SLOPE TELEPHONE ASSOCIATION COOPERATIVE INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	arctic slope telephone association cooperative inc.
3157	AT&T WIRELESS INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	at&t wireless inc.
3158	BLUEGRASS WIRELESS LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	bluegrass wireless llc
3159	CABLE & COMMUNICATIONS CORP.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	cable & communications corp.
3160	CALIFORNIA RSA NO. 3 LIMITED PARTNERSHIP	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	california rsa no. 3 limited partnership
3161	CAMBRIDGE TELEPHONE COMPANY INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	cambridge telephone company inc.
3162	CAPROCK CELLULAR LTD.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	caprock cellular ltd.
3163	VERIZON WIRELESS	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	verizon wireless
3164	CELLULAR NETWORK PARTNERSHIP LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	cellular network partnership llc
3165	CHOICE PHONE LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	choice phone llc
3166	CINCINNATI BELL WIRELESS LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	cincinnati bell wireless llc
3167	CINGULAR WIRELESS	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	cingular wireless
3168	COLEMAN COUNTY TELCO /TRANS TX	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	coleman county telco /trans tx
3169	CONSOLIDATED TELCOM	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	consolidated telcom
3170	CROSS VALLIANT CELLULAR PARTNERSHIP	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	cross valliant cellular partnership
3171	CROSS WIRELESS TELEPHONE CO.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	cross wireless telephone co.
3172	CUSTER TELEPHONE COOPERATIVE INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	custer telephone cooperative inc.
3173	DOBSON CELLULAR SYSTEMS	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	dobson cellular systems
3174	E.N.M.R. TELEPHONE COOP.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	e.n.m.r. telephone coop.
3175	EAST KENTUCKY NETWORK LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	east kentucky network llc
3176	EDGE WIRELESS LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	edge wireless llc
3177	ELKHART TELCO. / EPIC TOUCH CO.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	elkhart telco. / epic touch co.
3178	FARMERS	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	farmers
3179	FISHER WIRELESS SERVICES INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	fisher wireless services inc.
3180	GCI COMMUNICATION CORP.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	gci communication corp.
3181	GET MOBILE INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	get mobile inc.
3182	ILLINOIS VALLEY CELLULAR RSA 2 PARTNERSHIP	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	illinois valley cellular rsa 2 partnership
3183	IOWA RSA NO. 2 LIMITED PARTNERSHIP	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	iowa rsa no. 2 limited partnership
3184	IOWA WIRELESS SERVICES LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	iowa wireless services llc
3185	JASPER	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	jasper
3186	KAPLAN TELEPHONE COMPANY INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	kaplan telephone company inc.
3187	KEYSTONE WIRELESS LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	keystone wireless llc
3188	LAMAR COUNTY CELLULAR	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	lamar county cellular
3189	LEAP WIRELESS INTERNATIONAL INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	leap wireless international inc.
3190	MATANUSKA TEL. ASSN. INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	matanuska tel. assn. inc.
3191	MESSAGE EXPRESS CO. / AIRLINK PCS	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	message express co. / airlink pcs
3192	MICHIGAN WIRELESS LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	michigan wireless llc
3193	MINNESOTA SOUTH. WIREL. CO. / HICKORY	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	minnesota south. wirel. co. / hickory
3194	MISSOURI RSA NO 5 PARTNERSHIP	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	missouri rsa no 5 partnership
3195	MOHAVE CELLULAR LP	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	mohave cellular lp
3196	MTPCS LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	mtpcs llc
3197	NEP CELLCORP INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	nep cellcorp inc.
3198	NEVADA WIRELESS LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	nevada wireless llc
3199	NEW-CELL INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	new-cell inc.
3200	NEXUS COMMUNICATIONS INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	nexus communications inc.
3201	NORTH CAROLINA RSA 3 CELLULAR TEL. CO.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	north carolina rsa 3 cellular tel. co.
3202	NORTH DAKOTA NETWORK COMPANY	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	north dakota network company
3203	NORTHEAST COLORADO CELLULAR INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	northeast colorado cellular inc.
3204	NORTHEAST WIRELESS NETWORKS LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	northeast wireless networks llc
3205	NORTHSTAR	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	northstar
3206	NORTHWEST MISSOURI CELLULAR LIMITED PARTNERSHIP	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	northwest missouri cellular limited partnership
3207	VARIOUS NETWORKS	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	various networks
3208	PANHANDLE TELEPHONE COOPERATIVE INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	panhandle telephone cooperative inc.
3209	PCS ONE	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	pcs one
3210	PETROCOM	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	petrocom
3211	PINE BELT CELLULAR, INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	pine belt cellular, inc.
3212	PLATEAU TELECOMMUNICATIONS INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	plateau telecommunications inc.
3213	POKA LAMBRO TELCO LTD.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	poka lambro telco ltd.
3214	PUBLIC SERVICE CELLULAR INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	public service cellular inc.
3215	RSA 1 LIMITED PARTNERSHIP	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	rsa 1 limited partnership
3216	SAGEBRUSH CELLULAR INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	sagebrush cellular inc.
3235	WEST VIRGINIA WIRELESS	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	west virginia wireless
3236	WESTLINK COMMUNICATIONS, LLC	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	westlink communications, llc
3237	WISCONSIN RSA #7 LIMITED PARTNERSHIP	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	wisconsin rsa #7 limited partnership
3238	YORKVILLE TELEPHONE COOPERATIVE	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	yorkville telephone cooperative
3239	ANCEL/ANTEL	\N	\N	\N	409	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	ancel/antel
3240	CLARO/AM WIRELESS	\N	\N	\N	409	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	claro/am wireless
3241	MOVISTAR	\N	\N	\N	409	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	movistar
3242	BEE LINE/UNITEL	\N	\N	\N	410	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	bee line/unitel
3243	BUZTEL	\N	\N	\N	410	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	buztel
3244	MTS/UZDUNROBITA	\N	\N	\N	410	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	mts/uzdunrobita
3245	UCELL/COSCOM	\N	\N	\N	410	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	ucell/coscom
3246	UZMACOM	\N	\N	\N	410	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	uzmacom
3247	DIGICEL	\N	\N	\N	411	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	digicel
3248	SMILE	\N	\N	\N	411	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	smile
3249	FAILED CALLS	\N	\N	\N	412	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	failed calls
3250	DIGITEL C.A.	\N	\N	\N	413	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	digitel c.a.
3251	MOVILNET C.A.	\N	\N	\N	413	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	movilnet c.a.
3252	MOVISTAR/TELCEL	\N	\N	\N	413	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	movistar/telcel
3253	GMOBILE	\N	\N	\N	414	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	gmobile
3254	I-TELECOM	\N	\N	\N	414	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	i-telecom
3255	MOBIFONE	\N	\N	\N	414	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	mobifone
1399	COSMOTE	\N	\N	\N	191	2025-11-18 20:53:34	2025-11-18 20:53:34	\N	\N	\N	\N	f	cosmote
1400	VODAFONE	\N	\N	\N	191	2025-11-18 20:53:34	2025-11-18 20:53:34	\N	\N	\N	\N	f	vodafone
1401	NOVA	\N	\N	\N	191	2025-11-18 20:53:34	2025-11-18 20:53:34	\N	\N	\N	\N	f	nova
1402	VODAFONE	\N	\N	\N	192	2025-11-18 20:53:34	2025-11-18 20:53:34	\N	\N	\N	\N	f	vodafone
1403	KPN	\N	\N	\N	192	2025-11-18 20:53:34	2025-11-18 20:53:34	\N	\N	\N	\N	f	kpn
1413	ONE / AMC	\N	\N	\N	195	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	one / amc
1414	PLUS COMMUNICATION SH.A	\N	\N	\N	195	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	plus communication sh.a
1415	VODAFONE	\N	\N	\N	195	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	vodafone
1416	DJEZZY	\N	\N	\N	196	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	djezzy
1417	MOBILIS	\N	\N	\N	196	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	mobilis
1418	OOREDOO	\N	\N	\N	196	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	ooredoo
1419	ASTCA MOBILE	\N	\N	\N	197	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	astca mobile
1420	BLUESKY	\N	\N	\N	197	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	bluesky
1421	ANDORRA TELECOM / MOBILAND	\N	\N	\N	198	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	andorra telecom / mobiland
1422	MOVICEL	\N	\N	\N	199	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	movicel
1423	UNITEL	\N	\N	\N	199	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	unitel
1424	DIGICEL	\N	\N	\N	200	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	digicel
1425	FLOW	\N	\N	\N	200	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	flow
1426	DIGICEL	\N	\N	\N	201	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	digicel
1427	FLOW	\N	\N	\N	201	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	flow
1428	IMOBILE / APUA	\N	\N	\N	201	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	imobile / apua
1429	CLARO	\N	\N	\N	202	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	claro
1430	EXPRESS	\N	\N	\N	202	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	express
1431	FIX LINE	\N	\N	\N	202	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	fix line
1432	IMOWI	\N	\N	\N	202	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	imowi
1433	IPLAN	\N	\N	\N	202	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	iplan
1434	KALLOFER	\N	\N	\N	202	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	kallofer
1435	MOVISTAR	\N	\N	\N	202	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	movistar
1436	MOVISTAR/TELEFONICA	\N	\N	\N	202	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	movistar/telefonica
1437	NEXTEL	\N	\N	\N	202	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	nextel
1438	NUESTRO	\N	\N	\N	202	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	nuestro
1404	A-MOBILE	\N	\N	\N	193	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	a-mobile
1405	AQUAFON	\N	\N	\N	193	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	aquafon
1406	AWCC	\N	\N	\N	194	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	awcc
1407	ETISALAT	\N	\N	\N	194	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	etisalat
1408	MOBIFONE	\N	\N	\N	194	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	mobifone
1409	MTN	\N	\N	\N	194	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	mtn
1410	ROSHAN	\N	\N	\N	194	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	roshan
1411	WASELTELECOM (WT)	\N	\N	\N	194	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	waseltelecom (wt)
1412	ALBTELECOM MOBILE / EAGLE	\N	\N	\N	195	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	albtelecom mobile / eagle
2712	URALTEL	\N	\N	\N	361	2025-11-18 22:02:35	2025-11-18 22:02:35	\N	\N	\N	\N	f	uraltel
1610	FIX LINE	\N	\N	\N	227	2025-11-18 22:02:29	2025-11-21 18:54:55	\N	\N	\N	\N	f	fix line
2015	FIX LINE	\N	\N	\N	278	2025-11-18 22:02:31	2025-11-21 18:54:55	\N	\N	\N	\N	f	fix line
2841	BT ESPANA SAU	\N	\N	\N	384	2025-11-18 22:02:36	2025-11-21 18:54:55	\N	\N	\N	\N	f	bt espana sau
2433	EMPRESA NICARAGUENSE DE TELECOMUNICACIONES SA (ENITEL)	\N	\N	\N	\N	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	empresa nicaraguense de telecomunicaciones sa (enitel)
2434	FIX LINE	\N	\N	\N	\N	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	fix line
2435	MOVISTAR	\N	\N	\N	\N	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	movistar
3324	EMPRESA NICARAGUENSE DE TELECOMUNICACIONES SA (ENITEL)	\N	\N	\N	448	2025-11-18 22:02:34	2025-11-27 12:07:56	\N	\N	\N	\N	f	empresa nicaraguense de telecomunicaciones sa (enitel)
1439	PERSONAL	\N	\N	\N	202	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	personal
1440	TELECENTRO	\N	\N	\N	202	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	telecentro
1441	BEELINE	\N	\N	\N	203	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	beeline
1442	KT	\N	\N	\N	203	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	kt
1443	ORANGE	\N	\N	\N	203	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	orange
1444	VIVA-MTS	\N	\N	\N	203	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	viva-mts
1445	DIGICEL	\N	\N	\N	204	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	digicel
1446	MIO	\N	\N	\N	204	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	mio
1447	SETAR	\N	\N	\N	204	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	setar
1448	AAPT LTD.	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	aapt ltd.
1449	ACMA	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	acma
1450	ADVANCED COMM TECH PTY.	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	advanced comm tech pty.
1451	AIRNET COMMERCIAL AUSTRALIA LTD..	\N	\N	\N	205	2025-11-18 22:02:28	2025-11-18 22:02:28	\N	\N	\N	\N	f	airnet commercial australia ltd..
3325	FIX LINE	\N	\N	\N	448	2025-11-18 22:02:34	2025-11-27 12:08:07	\N	\N	\N	\N	f	fix line
3313	CLARO	\N	\N	\N	448	2025-11-18 22:02:34	2025-11-27 13:08:44	\N	\N	\N	\N	f	claro
3316	MOVISTAR	\N	\N	\N	448	2025-11-18 22:02:34	2025-11-27 12:08:18	\N	\N	\N	\N	f	movistar
2166	RDCOM	\N	\N	\N	292	2025-11-18 22:02:32	2025-11-18 22:02:32	\N	\N	\N	\N	f	rdcom
2415	TELE2	\N	\N	\N	192	2025-11-18 22:02:34	2025-11-18 22:02:34	\N	\N	\N	\N	f	tele2
2749	STC/AL JAWAL	\N	\N	\N	371	2025-11-18 22:02:36	2025-11-18 22:02:36	\N	\N	\N	\N	f	stc/al jawal
3217	SIMMETRY	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	simmetry
3218	SLO CELLULAR INC / CELLULAR ONE OF SAN LUIS	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	slo cellular inc / cellular one of san luis
3219	SMITH BAGLEY INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	smith bagley inc.
3220	SOUTHERN COMMUNICATIONS SERVICES INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	southern communications services inc.
3221	SPRINT SPECTRUM	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	sprint spectrum
3222	T-MOBILE	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	t-mobile
3223	TELEMETRIX INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	telemetrix inc.
3224	TESTING	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	testing
3225	TEXAS RSA 15B2 LIMITED PARTNERSHIP	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	texas rsa 15b2 limited partnership
3226	THUMB CELLULAR LIMITED PARTNERSHIP	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	thumb cellular limited partnership
3227	TMP CORPORATION	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	tmp corporation
3228	TRITON PCS	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	triton pcs
3229	UINTAH BASIN ELECTRONICS TELECOMMUNICATIONS INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	uintah basin electronics telecommunications inc.
3230	UNION TELEPHONE CO.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	union telephone co.
3231	UNITED STATES CELLULAR CORP.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	united states cellular corp.
3232	UNITED WIRELESS COMMUNICATIONS INC.	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	united wireless communications inc.
3233	USA 3650 AT&T	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	usa 3650 at&t
3234	VERISIGN	\N	\N	\N	408	2025-11-18 22:02:38	2025-11-18 22:02:38	\N	\N	\N	\N	f	verisign
3256	REDDI	\N	\N	\N	414	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	reddi
3257	S-FONE/TELECOM	\N	\N	\N	414	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	s-fone/telecom
3258	VIETNAMOBILE	\N	\N	\N	414	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	vietnamobile
3259	VIETTEL	\N	\N	\N	414	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	viettel
3260	VINAPHONE	\N	\N	\N	414	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	vinaphone
3261	DIGICEL	\N	\N	\N	415	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	digicel
3262	FAILED CALLS	\N	\N	\N	416	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	failed calls
3263	MANUIA	\N	\N	\N	416	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	manuia
3264	FIX LINE	\N	\N	\N	417	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	fix line
3265	HITS/Y UNITEL	\N	\N	\N	417	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	hits/y unitel
3266	MTN/SPACETEL	\N	\N	\N	417	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	mtn/spacetel
3267	SABAPHONE	\N	\N	\N	417	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	sabaphone
3268	YEMEN MOB. CDMA	\N	\N	\N	417	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	yemen mob. cdma
3269	AIRTEL	\N	\N	\N	418	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	airtel
3270	FAILED CALLS	\N	\N	\N	418	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	failed calls
3271	MTN	\N	\N	\N	418	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	mtn
3272	ZAMTEL	\N	\N	\N	418	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	zamtel
3275	TELECEL	\N	\N	\N	419	2025-11-18 22:02:39	2025-11-18 22:02:39	\N	\N	\N	\N	f	telecel
3288	FIX LINE	\N	\N	\N	287	2025-11-20 10:06:13	2025-11-20 10:06:13	\N	\N	\N	\N	f	fix line
\.


--
-- Data for Name: password_reset_tokens; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.password_reset_tokens (email, token, created_at) FROM stdin;
\.


--
-- Data for Name: route_types; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.route_types (id, name, slug, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.sessions (id, user_id, ip_address, user_agent, payload, last_activity) FROM stdin;
\.


--
-- Data for Name: supplier_connections; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.supplier_connections (id, supplier_id, name, username, charge_type, notes, created_at, updated_at, product_type, connection_dead) FROM stdin;
1	1	connection_name1	username_!@1	per_submit	\N	2025-11-22 21:21:17	2025-11-22 21:52:01	Direct	f
2	1	sinch ss7	ss7	per_delivered	\N	2025-11-22 22:00:19	2025-11-22 22:00:19	SS7	f
3	2	Identifymobile	f672c1ef	per_delivered	\N	2025-11-26 14:08:58	2025-11-26 14:10:18	SS7	f
\.


--
-- Data for Name: supplier_offer_histories; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.supplier_offer_histories (id, supplier_offer_id, supplier_id, supplier_connection_id, country_id, network_id, network_mnc_id, price, mcc, mnc, mcc_mnc, product_type, known_hops, sender_id_supported, charge_type, is_exclusive, route_type, effective_date, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: supplier_offer_history; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.supplier_offer_history (id, supplier_offer_id, country_id, network_id, network_mnc_id, supplier_id, supplier_connection_id, price, mcc, mnc, mcc_mnc, product_type_id, known_hops_dropdown_item_id, sender_id_supported_dropdown_item_id, route_type_id, charge_model_id, charge_type, is_exclusive, effective_date, recorded_at, created_at, updated_at, product_type) FROM stdin;
\.


--
-- Data for Name: supplier_offers; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.supplier_offers (id, country_id, network_id, network_mnc_id, supplier_id, supplier_connection_id, price, mcc, mnc, mcc_mnc, product_type_id, known_hops_dropdown_item_id, sender_id_supported_dropdown_item_id, route_type_id, charge_model_id, charge_type, is_exclusive, effective_date, created_at, updated_at, product_type, known_hops, sender_id_supported, updated_by) FROM stdin;
8	191	1399	611	1	2	0.033000	\N	\N	\N	4	8	10	\N	\N	per_delivered	f	2025-11-25	2025-11-25 12:07:13	2025-11-25 15:42:15	SS7	\N	\N	1
12	191	1399	611	1	1	0.015000	\N	\N	\N	2	9	14	\N	\N	per_delivered	f	2025-11-25	2025-11-25 15:45:02	2025-11-25 20:33:30	HQ	\N	\N	1
13	191	1996	617	1	2	0.015000	\N	\N	\N	4	6	12	\N	\N	per_delivered	f	2025-11-25	2025-11-25 21:02:40	2025-11-25 21:02:40	SS7	\N	\N	\N
14	191	1400	618	1	1	0.015000	\N	\N	\N	5	8	16	\N	\N	per_submit	f	2025-11-25	2025-11-25 21:04:23	2025-11-25 21:04:23	Local Bypass	\N	\N	\N
15	193	1404	2	1	1	0.022000	\N	\N	\N	3	6	16	\N	\N	per_submit	f	2025-11-25	2025-11-25 21:05:26	2025-11-25 21:05:26	SIM	\N	\N	\N
16	193	1405	3	1	1	0.015000	\N	\N	\N	2	8	16	\N	\N	per_delivered	f	2025-11-26	2025-11-26 08:22:05	2025-11-26 08:22:05	HQ	\N	\N	\N
17	193	1405	3	1	2	0.030500	\N	\N	\N	5	6	16	\N	\N	per_delivered	f	2025-11-26	2025-11-26 10:04:04	2025-11-26 10:04:04	Local Bypass	\N	\N	1
18	191	1399	611	1	1	0.030500	\N	\N	\N	1	8	10	\N	\N	per_submit	f	2025-11-26	2025-11-26 10:53:38	2025-11-26 10:53:38	Direct	\N	\N	1
19	191	1399	611	1	1	0.030500	\N	\N	\N	5	7	10	\N	\N	per_delivered	f	2025-11-26	2025-11-26 11:05:23	2025-11-26 11:05:23	Local Bypass	\N	\N	1
20	194	1407	6	1	2	0.015000	\N	\N	\N	5	6	10	\N	\N	per_submit	f	2025-11-26	2025-11-26 11:06:02	2025-11-26 11:06:02	Local Bypass	\N	\N	1
21	360	2623	1409	2	3	0.015000	\N	\N	\N	4	6	10	\N	\N	per_delivered	f	2025-11-26	2025-11-26 14:11:47	2025-11-26 14:11:47	SS7	\N	\N	1
\.


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.suppliers (id, name, email, notes, created_at, updated_at) FROM stdin;
1	Sinch	noreply@sinch.com	\N	2025-11-22 20:37:51	2025-11-22 20:37:51
2	Identify Mobile	pricing@identifymobile.com	\N	2025-11-26 14:06:32	2025-11-26 14:06:32
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: app
--

COPY public.users (id, name, email, email_verified_at, password, remember_token, created_at, updated_at, is_admin, role) FROM stdin;
1	Admin	admin@example.com	2025-11-18 15:37:45	$2y$12$eumcFtZy.9wvOng4QMynRu7oZhLg8lYtV0m9ImIKco/5JBvR9D3z6	DuNMObwmsgoqhLkidOlhdbjXxInFESaSyDv57e6Ce1XZETP1y501q0RR35Nj	2025-11-18 15:37:45	2025-11-18 15:37:45	t	admin
\.


--
-- Name: auth_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.auth_logs_id_seq', 51, true);


--
-- Name: charge_models_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.charge_models_id_seq', 1, false);


--
-- Name: countries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.countries_id_seq', 449, true);


--
-- Name: country_mccs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.country_mccs_id_seq', 232, true);


--
-- Name: country_meta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.country_meta_id_seq', 1, false);


--
-- Name: dropdown_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.dropdown_items_id_seq', 16, true);


--
-- Name: dropdown_menus_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.dropdown_menus_id_seq', 3, true);


--
-- Name: failed_jobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.failed_jobs_id_seq', 1, false);


--
-- Name: imap_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.imap_settings_id_seq', 1, false);


--
-- Name: jobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.jobs_id_seq', 1, false);


--
-- Name: known_hops_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.known_hops_id_seq', 1, false);


--
-- Name: migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.migrations_id_seq', 45, true);


--
-- Name: network_meta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.network_meta_id_seq', 11, true);


--
-- Name: network_mncs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.network_mncs_id_seq', 2100, true);


--
-- Name: networks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.networks_id_seq', 3332, true);


--
-- Name: route_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.route_types_id_seq', 1, false);


--
-- Name: supplier_connections_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.supplier_connections_id_seq', 3, true);


--
-- Name: supplier_offer_histories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.supplier_offer_histories_id_seq', 1, false);


--
-- Name: supplier_offer_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.supplier_offer_history_id_seq', 1, false);


--
-- Name: supplier_offers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.supplier_offers_id_seq', 21, true);


--
-- Name: suppliers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.suppliers_id_seq', 2, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: app
--

SELECT pg_catalog.setval('public.users_id_seq', 1, true);


--
-- Name: auth_logs auth_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.auth_logs
    ADD CONSTRAINT auth_logs_pkey PRIMARY KEY (id);


--
-- Name: cache_locks cache_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.cache_locks
    ADD CONSTRAINT cache_locks_pkey PRIMARY KEY (key);


--
-- Name: cache cache_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.cache
    ADD CONSTRAINT cache_pkey PRIMARY KEY (key);


--
-- Name: charge_models charge_models_name_unique; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.charge_models
    ADD CONSTRAINT charge_models_name_unique UNIQUE (name);


--
-- Name: charge_models charge_models_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.charge_models
    ADD CONSTRAINT charge_models_pkey PRIMARY KEY (id);


--
-- Name: charge_models charge_models_slug_unique; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.charge_models
    ADD CONSTRAINT charge_models_slug_unique UNIQUE (slug);


--
-- Name: countries_base countries_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.countries_base
    ADD CONSTRAINT countries_pkey PRIMARY KEY (id);


--
-- Name: country_mccs country_mccs_mcc_unique; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.country_mccs
    ADD CONSTRAINT country_mccs_mcc_unique UNIQUE (mcc);


--
-- Name: country_mccs country_mccs_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.country_mccs
    ADD CONSTRAINT country_mccs_pkey PRIMARY KEY (id);


--
-- Name: country_meta country_meta_country_id_unique; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.country_meta
    ADD CONSTRAINT country_meta_country_id_unique UNIQUE (country_id);


--
-- Name: country_meta country_meta_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.country_meta
    ADD CONSTRAINT country_meta_pkey PRIMARY KEY (id);


--
-- Name: dropdown_items dropdown_items_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.dropdown_items
    ADD CONSTRAINT dropdown_items_pkey PRIMARY KEY (id);


--
-- Name: dropdown_menus dropdown_menus_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.dropdown_menus
    ADD CONSTRAINT dropdown_menus_pkey PRIMARY KEY (id);


--
-- Name: failed_jobs failed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.failed_jobs
    ADD CONSTRAINT failed_jobs_pkey PRIMARY KEY (id);


--
-- Name: failed_jobs failed_jobs_uuid_unique; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.failed_jobs
    ADD CONSTRAINT failed_jobs_uuid_unique UNIQUE (uuid);


--
-- Name: imap_settings imap_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.imap_settings
    ADD CONSTRAINT imap_settings_pkey PRIMARY KEY (id);


--
-- Name: job_batches job_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.job_batches
    ADD CONSTRAINT job_batches_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: known_hops known_hops_name_unique; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.known_hops
    ADD CONSTRAINT known_hops_name_unique UNIQUE (name);


--
-- Name: known_hops known_hops_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.known_hops
    ADD CONSTRAINT known_hops_pkey PRIMARY KEY (id);


--
-- Name: known_hops known_hops_slug_unique; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.known_hops
    ADD CONSTRAINT known_hops_slug_unique UNIQUE (slug);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: network_meta network_meta_network_id_unique; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.network_meta
    ADD CONSTRAINT network_meta_network_id_unique UNIQUE (network_id);


--
-- Name: network_meta network_meta_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.network_meta
    ADD CONSTRAINT network_meta_pkey PRIMARY KEY (id);


--
-- Name: network_mncs network_mncs_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.network_mncs
    ADD CONSTRAINT network_mncs_pkey PRIMARY KEY (id);


--
-- Name: networks_base networks_country_lowername_unique; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.networks_base
    ADD CONSTRAINT networks_country_lowername_unique UNIQUE (country_id, lower_name);


--
-- Name: networks_base networks_mcc_mnc_unique; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.networks_base
    ADD CONSTRAINT networks_mcc_mnc_unique UNIQUE (mcc_mnc);


--
-- Name: networks_base networks_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.networks_base
    ADD CONSTRAINT networks_pkey PRIMARY KEY (id);


--
-- Name: network_mncs nx_network_mncs_mcc_mnc; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.network_mncs
    ADD CONSTRAINT nx_network_mncs_mcc_mnc UNIQUE (mcc, mnc);


--
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (email);


--
-- Name: route_types route_types_name_unique; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.route_types
    ADD CONSTRAINT route_types_name_unique UNIQUE (name);


--
-- Name: route_types route_types_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.route_types
    ADD CONSTRAINT route_types_pkey PRIMARY KEY (id);


--
-- Name: route_types route_types_slug_unique; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.route_types
    ADD CONSTRAINT route_types_slug_unique UNIQUE (slug);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: supplier_connections supplier_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.supplier_connections
    ADD CONSTRAINT supplier_connections_pkey PRIMARY KEY (id);


--
-- Name: supplier_offer_histories supplier_offer_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.supplier_offer_histories
    ADD CONSTRAINT supplier_offer_histories_pkey PRIMARY KEY (id);


--
-- Name: supplier_offer_history supplier_offer_history_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.supplier_offer_history
    ADD CONSTRAINT supplier_offer_history_pkey PRIMARY KEY (id);


--
-- Name: supplier_offers supplier_offers_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.supplier_offers
    ADD CONSTRAINT supplier_offers_pkey PRIMARY KEY (id);


--
-- Name: suppliers suppliers_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);


--
-- Name: users users_email_unique; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_unique UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: auth_logs_user_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX auth_logs_user_id_index ON public.auth_logs USING btree (user_id);


--
-- Name: countries_iso2_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX countries_iso2_index ON public.countries_base USING btree (iso2);


--
-- Name: countries_iso2_unique_idx; Type: INDEX; Schema: public; Owner: app
--

CREATE UNIQUE INDEX countries_iso2_unique_idx ON public.countries_base USING btree (iso2);


--
-- Name: country_mccs_country_mcc_unique; Type: INDEX; Schema: public; Owner: app
--

CREATE UNIQUE INDEX country_mccs_country_mcc_unique ON public.country_mccs USING btree (country_id, mcc);


--
-- Name: country_mccs_mcc_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX country_mccs_mcc_index ON public.country_mccs USING btree (mcc);


--
-- Name: dropdown_items_position_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX dropdown_items_position_index ON public.dropdown_items USING btree ("position");


--
-- Name: jobs_queue_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX jobs_queue_index ON public.jobs USING btree (queue);


--
-- Name: network_meta_non_operational_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX network_meta_non_operational_index ON public.network_meta USING btree (non_operational);


--
-- Name: network_mncs_marked_for_deletion_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX network_mncs_marked_for_deletion_index ON public.network_mncs USING btree (marked_for_deletion);


--
-- Name: network_mncs_mcc_mnc_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX network_mncs_mcc_mnc_index ON public.network_mncs USING btree (mcc_mnc);


--
-- Name: network_mncs_network_mnc_unique; Type: INDEX; Schema: public; Owner: app
--

CREATE UNIQUE INDEX network_mncs_network_mnc_unique ON public.network_mncs USING btree (network_id, mnc, mcc);


--
-- Name: networks_lower_name_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX networks_lower_name_index ON public.networks_base USING btree (lower_name);


--
-- Name: networks_marked_for_deletion_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX networks_marked_for_deletion_index ON public.networks_base USING btree (marked_for_deletion);


--
-- Name: networks_mcc_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX networks_mcc_index ON public.networks_base USING btree (mcc);


--
-- Name: networks_mnc_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX networks_mnc_index ON public.networks_base USING btree (mnc);


--
-- Name: nx_network_mncs_mccmnc; Type: INDEX; Schema: public; Owner: app
--

CREATE UNIQUE INDEX nx_network_mncs_mccmnc ON public.network_mncs USING btree (mcc_mnc);


--
-- Name: sessions_last_activity_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX sessions_last_activity_index ON public.sessions USING btree (last_activity);


--
-- Name: sessions_user_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX sessions_user_id_index ON public.sessions USING btree (user_id);


--
-- Name: supplier_connections_supplier_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_connections_supplier_id_index ON public.supplier_connections USING btree (supplier_id);


--
-- Name: supplier_offer_histories_country_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_histories_country_id_index ON public.supplier_offer_histories USING btree (country_id);


--
-- Name: supplier_offer_histories_network_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_histories_network_id_index ON public.supplier_offer_histories USING btree (network_id);


--
-- Name: supplier_offer_histories_network_mnc_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_histories_network_mnc_id_index ON public.supplier_offer_histories USING btree (network_mnc_id);


--
-- Name: supplier_offer_histories_supplier_connection_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_histories_supplier_connection_id_index ON public.supplier_offer_histories USING btree (supplier_connection_id);


--
-- Name: supplier_offer_histories_supplier_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_histories_supplier_id_index ON public.supplier_offer_histories USING btree (supplier_id);


--
-- Name: supplier_offer_histories_supplier_offer_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_histories_supplier_offer_id_index ON public.supplier_offer_histories USING btree (supplier_offer_id);


--
-- Name: supplier_offer_history_charge_model_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_history_charge_model_id_index ON public.supplier_offer_history USING btree (charge_model_id);


--
-- Name: supplier_offer_history_country_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_history_country_id_index ON public.supplier_offer_history USING btree (country_id);


--
-- Name: supplier_offer_history_known_hops_dropdown_item_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_history_known_hops_dropdown_item_id_index ON public.supplier_offer_history USING btree (known_hops_dropdown_item_id);


--
-- Name: supplier_offer_history_mcc_mnc_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_history_mcc_mnc_index ON public.supplier_offer_history USING btree (mcc_mnc);


--
-- Name: supplier_offer_history_network_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_history_network_id_index ON public.supplier_offer_history USING btree (network_id);


--
-- Name: supplier_offer_history_network_mnc_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_history_network_mnc_id_index ON public.supplier_offer_history USING btree (network_mnc_id);


--
-- Name: supplier_offer_history_product_type_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_history_product_type_id_index ON public.supplier_offer_history USING btree (product_type_id);


--
-- Name: supplier_offer_history_route_type_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_history_route_type_id_index ON public.supplier_offer_history USING btree (route_type_id);


--
-- Name: supplier_offer_history_sender_id_supported_dropdown_item_id_ind; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_history_sender_id_supported_dropdown_item_id_ind ON public.supplier_offer_history USING btree (sender_id_supported_dropdown_item_id);


--
-- Name: supplier_offer_history_supplier_connection_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_history_supplier_connection_id_index ON public.supplier_offer_history USING btree (supplier_connection_id);


--
-- Name: supplier_offer_history_supplier_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_history_supplier_id_index ON public.supplier_offer_history USING btree (supplier_id);


--
-- Name: supplier_offer_history_supplier_offer_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offer_history_supplier_offer_id_index ON public.supplier_offer_history USING btree (supplier_offer_id);


--
-- Name: supplier_offers_charge_model_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offers_charge_model_id_index ON public.supplier_offers USING btree (charge_model_id);


--
-- Name: supplier_offers_country_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offers_country_id_index ON public.supplier_offers USING btree (country_id);


--
-- Name: supplier_offers_known_hops_dropdown_item_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offers_known_hops_dropdown_item_id_index ON public.supplier_offers USING btree (known_hops_dropdown_item_id);


--
-- Name: supplier_offers_mcc_mnc_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offers_mcc_mnc_index ON public.supplier_offers USING btree (mcc_mnc);


--
-- Name: supplier_offers_network_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offers_network_id_index ON public.supplier_offers USING btree (network_id);


--
-- Name: supplier_offers_network_mnc_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offers_network_mnc_id_index ON public.supplier_offers USING btree (network_mnc_id);


--
-- Name: supplier_offers_product_type_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offers_product_type_id_index ON public.supplier_offers USING btree (product_type_id);


--
-- Name: supplier_offers_route_type_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offers_route_type_id_index ON public.supplier_offers USING btree (route_type_id);


--
-- Name: supplier_offers_sender_id_supported_dropdown_item_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offers_sender_id_supported_dropdown_item_id_index ON public.supplier_offers USING btree (sender_id_supported_dropdown_item_id);


--
-- Name: supplier_offers_supplier_connection_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offers_supplier_connection_id_index ON public.supplier_offers USING btree (supplier_connection_id);


--
-- Name: supplier_offers_supplier_id_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX supplier_offers_supplier_id_index ON public.supplier_offers USING btree (supplier_id);


--
-- Name: users_role_index; Type: INDEX; Schema: public; Owner: app
--

CREATE INDEX users_role_index ON public.users USING btree (role);


--
-- Name: countries_base trg_countries_iso2_guard; Type: TRIGGER; Schema: public; Owner: app
--

CREATE TRIGGER trg_countries_iso2_guard BEFORE INSERT OR UPDATE ON public.countries_base FOR EACH ROW EXECUTE FUNCTION public.countries_iso2_guard();


--
-- Name: countries trg_countries_view_ins; Type: TRIGGER; Schema: public; Owner: app
--

CREATE TRIGGER trg_countries_view_ins INSTEAD OF INSERT ON public.countries FOR EACH ROW EXECUTE FUNCTION public.countries_view_upsert_ins();


--
-- Name: countries trg_countries_view_upd; Type: TRIGGER; Schema: public; Owner: app
--

CREATE TRIGGER trg_countries_view_upd INSTEAD OF UPDATE ON public.countries FOR EACH ROW EXECUTE FUNCTION public.countries_view_upsert_upd();


--
-- Name: network_mncs trg_network_mncs_normalize; Type: TRIGGER; Schema: public; Owner: app
--

CREATE TRIGGER trg_network_mncs_normalize BEFORE INSERT OR UPDATE ON public.network_mncs FOR EACH ROW EXECUTE FUNCTION public.normalize_network_mncs();


--
-- Name: networks_base trg_networks_name_normalize; Type: TRIGGER; Schema: public; Owner: app
--

CREATE TRIGGER trg_networks_name_normalize BEFORE INSERT OR UPDATE ON public.networks_base FOR EACH ROW EXECUTE FUNCTION public.networks_name_normalize();


--
-- Name: networks_base trg_networks_name_normalize_base; Type: TRIGGER; Schema: public; Owner: app
--

CREATE TRIGGER trg_networks_name_normalize_base BEFORE INSERT OR UPDATE ON public.networks_base FOR EACH ROW EXECUTE FUNCTION public.networks_name_normalize_base();


--
-- Name: networks trg_networks_view_ins; Type: TRIGGER; Schema: public; Owner: app
--

CREATE TRIGGER trg_networks_view_ins INSTEAD OF INSERT ON public.networks FOR EACH ROW EXECUTE FUNCTION public.networks_view_upsert_ins();


--
-- Name: networks trg_networks_view_upd; Type: TRIGGER; Schema: public; Owner: app
--

CREATE TRIGGER trg_networks_view_upd INSTEAD OF UPDATE ON public.networks FOR EACH ROW EXECUTE FUNCTION public.networks_view_upsert_upd();


--
-- Name: networks_base 1; Type: FK CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.networks_base
    ADD CONSTRAINT "1" FOREIGN KEY (country_id) REFERENCES public.countries_base(id) ON DELETE SET NULL;


--
-- Name: country_mccs country_mccs_country_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.country_mccs
    ADD CONSTRAINT country_mccs_country_id_foreign FOREIGN KEY (country_id) REFERENCES public.countries_base(id) ON DELETE CASCADE;


--
-- Name: dropdown_items dropdown_items_dropdown_menu_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.dropdown_items
    ADD CONSTRAINT dropdown_items_dropdown_menu_id_foreign FOREIGN KEY (dropdown_menu_id) REFERENCES public.dropdown_menus(id) ON DELETE CASCADE;


--
-- Name: network_mncs network_mncs_created_by_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.network_mncs
    ADD CONSTRAINT network_mncs_created_by_user_id_foreign FOREIGN KEY (created_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: network_mncs network_mncs_network_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.network_mncs
    ADD CONSTRAINT network_mncs_network_id_foreign FOREIGN KEY (network_id) REFERENCES public.networks_base(id) ON DELETE CASCADE;


--
-- Name: network_mncs network_mncs_updated_by_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.network_mncs
    ADD CONSTRAINT network_mncs_updated_by_user_id_foreign FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: networks_base networks_created_by_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.networks_base
    ADD CONSTRAINT networks_created_by_user_id_foreign FOREIGN KEY (created_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: networks_base networks_updated_by_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.networks_base
    ADD CONSTRAINT networks_updated_by_user_id_foreign FOREIGN KEY (updated_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: supplier_connections supplier_connections_supplier_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.supplier_connections
    ADD CONSTRAINT supplier_connections_supplier_id_foreign FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id) ON DELETE CASCADE;


--
-- Name: supplier_offers supplier_offers_updated_by_foreign; Type: FK CONSTRAINT; Schema: public; Owner: app
--

ALTER TABLE ONLY public.supplier_offers
    ADD CONSTRAINT supplier_offers_updated_by_foreign FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict o499dbc7G4lAtughocdxFqRlLBXQZ7kpofAWOnmyf9CkHf1SqL6dFnWHICeWG5s

