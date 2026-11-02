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
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: activity_logs_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.activity_logs_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'activity_logs is append-only';
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: activity_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_logs (
    id bigint NOT NULL,
    trackable_type character varying NOT NULL,
    trackable_id bigint NOT NULL,
    actor_id bigint,
    action character varying(40) NOT NULL,
    from_status character varying(15),
    to_status character varying(15),
    remark text,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    ip_address character varying(45),
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: activity_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.activity_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: activity_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.activity_logs_id_seq OWNED BY public.activity_logs.id;


--
-- Name: app_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_settings (
    id bigint NOT NULL,
    key character varying(100) NOT NULL,
    value text,
    updated_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: app_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.app_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: app_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.app_settings_id_seq OWNED BY public.app_settings.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: bank_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bank_accounts (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    account_holder_name character varying(150) NOT NULL,
    bank_name character varying(100) NOT NULL,
    branch_name character varying(100),
    account_number character varying(20) NOT NULL,
    ifsc_code character varying(11) NOT NULL,
    account_type character varying(10) DEFAULT 'savings'::character varying NOT NULL,
    "primary" boolean DEFAULT false NOT NULL,
    active boolean DEFAULT true NOT NULL,
    deleted_at timestamp(6) without time zone,
    delete_remark character varying(500),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_bank_accounts_ifsc CHECK (((ifsc_code)::text ~ '^[A-Z]{4}0[A-Z0-9]{6}$'::text)),
    CONSTRAINT chk_bank_accounts_number CHECK (((account_number)::text ~ '^[0-9]{6,20}$'::text)),
    CONSTRAINT chk_bank_accounts_type CHECK (((account_type)::text = ANY (ARRAY[('savings'::character varying)::text, ('current'::character varying)::text])))
);


--
-- Name: bank_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bank_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bank_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bank_accounts_id_seq OWNED BY public.bank_accounts.id;


--
-- Name: budget_line_item_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.budget_line_item_codes (
    id bigint NOT NULL,
    name character varying(500) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: budget_line_item_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.budget_line_item_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: budget_line_item_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.budget_line_item_codes_id_seq OWNED BY public.budget_line_item_codes.id;


--
-- Name: budget_line_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.budget_line_items (
    id bigint NOT NULL,
    name character varying(500) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: budget_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.budget_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: budget_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.budget_line_items_id_seq OWNED BY public.budget_line_items.id;


--
-- Name: cities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cities (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    state character varying(60),
    da_rate numeric(10,2),
    lodging_rate numeric(10,2),
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: cities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cities_id_seq OWNED BY public.cities.id;


--
-- Name: claim_approval_steps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.claim_approval_steps (
    id bigint NOT NULL,
    tour_claim_id bigint NOT NULL,
    approver_id bigint NOT NULL,
    "position" integer NOT NULL,
    reason character varying(200),
    acted_by_id bigint,
    acted_at timestamp(6) without time zone,
    remark character varying(500),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: claim_approval_steps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.claim_approval_steps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: claim_approval_steps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.claim_approval_steps_id_seq OWNED BY public.claim_approval_steps.id;


--
-- Name: claim_city_travels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.claim_city_travels (
    id bigint NOT NULL,
    tour_claim_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    travel_date date NOT NULL,
    departure_city character varying(100) NOT NULL,
    arrival_city character varying(100) NOT NULL,
    travel_mode_id bigint NOT NULL,
    bill_ticket_no character varying(60),
    remark character varying(255),
    amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    deduction_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    deduction_remark character varying(255),
    total_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    ticket_quota character varying(10) DEFAULT 'normal'::character varying NOT NULL,
    CONSTRAINT chk_claim_city_travels_amounts CHECK (((amount >= (0)::numeric) AND (deduction_amount >= (0)::numeric) AND (deduction_amount <= amount))),
    CONSTRAINT chk_claim_city_travels_quota CHECK (((ticket_quota)::text = ANY (ARRAY[('normal'::character varying)::text, ('tatkal'::character varying)::text]))),
    CONSTRAINT chk_claim_city_travels_total CHECK ((total_amount = (amount - deduction_amount)))
);


--
-- Name: claim_city_travels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.claim_city_travels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: claim_city_travels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.claim_city_travels_id_seq OWNED BY public.claim_city_travels.id;


--
-- Name: claim_cutoff_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.claim_cutoff_rules (
    id bigint NOT NULL,
    user_id bigint,
    cutoff_day smallint DEFAULT 5 NOT NULL,
    remark character varying(255),
    updated_by_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_cutoff_day_range CHECK (((cutoff_day >= 1) AND (cutoff_day <= 28)))
);


--
-- Name: claim_cutoff_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.claim_cutoff_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: claim_cutoff_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.claim_cutoff_rules_id_seq OWNED BY public.claim_cutoff_rules.id;


--
-- Name: claim_daily_allowances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.claim_daily_allowances (
    id bigint NOT NULL,
    tour_claim_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    departure_city character varying(100) NOT NULL,
    departure_at timestamp(6) without time zone NOT NULL,
    city_id bigint,
    arrival_city_name character varying(150),
    arrival_at timestamp(6) without time zone NOT NULL,
    no_of_days numeric(6,2) DEFAULT 0.0 NOT NULL,
    da_rate numeric(10,2) DEFAULT 0.0 NOT NULL,
    applicable_percent smallint DEFAULT 100 NOT NULL,
    amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    deduction_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    deduction_remark character varying(255),
    total_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_claim_da_percent CHECK ((applicable_percent = ANY (ARRAY[0, 25, 50, 100]))),
    CONSTRAINT chk_claim_da_times CHECK ((arrival_at >= departure_at)),
    CONSTRAINT chk_claim_daily_allowances_amounts CHECK (((amount >= (0)::numeric) AND (deduction_amount >= (0)::numeric) AND (deduction_amount <= amount))),
    CONSTRAINT chk_claim_daily_allowances_total CHECK ((total_amount = (amount - deduction_amount)))
);


--
-- Name: claim_daily_allowances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.claim_daily_allowances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: claim_daily_allowances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.claim_daily_allowances_id_seq OWNED BY public.claim_daily_allowances.id;


--
-- Name: claim_incidentals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.claim_incidentals (
    id bigint NOT NULL,
    tour_claim_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    expense_date date NOT NULL,
    particular character varying(255) NOT NULL,
    bill_no character varying(60),
    amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    deduction_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    deduction_remark character varying(255),
    total_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_claim_incidentals_amounts CHECK (((amount >= (0)::numeric) AND (deduction_amount >= (0)::numeric) AND (deduction_amount <= amount))),
    CONSTRAINT chk_claim_incidentals_total CHECK ((total_amount = (amount - deduction_amount)))
);


--
-- Name: claim_incidentals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.claim_incidentals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: claim_incidentals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.claim_incidentals_id_seq OWNED BY public.claim_incidentals.id;


--
-- Name: claim_local_travels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.claim_local_travels (
    id bigint NOT NULL,
    tour_claim_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    travel_date date NOT NULL,
    place_from character varying(150) NOT NULL,
    place_to character varying(150) NOT NULL,
    travel_mode_id bigint NOT NULL,
    meter_from numeric(10,1),
    meter_to numeric(10,1),
    kilometers numeric(9,2) DEFAULT 0.0 NOT NULL,
    rate_per_km numeric(8,2),
    purpose character varying(255),
    amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    deduction_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    deduction_remark character varying(255),
    total_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_claim_local_travels_amounts CHECK (((amount >= (0)::numeric) AND (deduction_amount >= (0)::numeric) AND (deduction_amount <= amount))),
    CONSTRAINT chk_claim_local_travels_km CHECK ((kilometers >= (0)::numeric)),
    CONSTRAINT chk_claim_local_travels_meter CHECK (((meter_from IS NULL) OR (meter_to IS NULL) OR (meter_to >= meter_from))),
    CONSTRAINT chk_claim_local_travels_total CHECK ((total_amount = (amount - deduction_amount)))
);


--
-- Name: claim_local_travels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.claim_local_travels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: claim_local_travels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.claim_local_travels_id_seq OWNED BY public.claim_local_travels.id;


--
-- Name: claim_lodgings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.claim_lodgings (
    id bigint NOT NULL,
    tour_claim_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    city_id bigint,
    place_name character varying(150),
    from_date timestamp(6) without time zone NOT NULL,
    to_date timestamp(6) without time zone NOT NULL,
    no_of_days numeric(6,2) DEFAULT 0.0 NOT NULL,
    rate numeric(10,2) DEFAULT 0.0 NOT NULL,
    remark character varying(255),
    amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    deduction_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    deduction_remark character varying(255),
    total_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    lodging_date date,
    CONSTRAINT chk_claim_lodgings_amounts CHECK (((amount >= (0)::numeric) AND (deduction_amount >= (0)::numeric) AND (deduction_amount <= amount))),
    CONSTRAINT chk_claim_lodgings_dates CHECK ((to_date >= from_date)),
    CONSTRAINT chk_claim_lodgings_total CHECK ((total_amount = (amount - deduction_amount)))
);


--
-- Name: claim_lodgings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.claim_lodgings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: claim_lodgings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.claim_lodgings_id_seq OWNED BY public.claim_lodgings.id;


--
-- Name: claim_queries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.claim_queries (
    id bigint NOT NULL,
    tour_claim_id bigint NOT NULL,
    asked_by_id bigint NOT NULL,
    asked_to_id bigint NOT NULL,
    asked_to_role character varying(10) NOT NULL,
    question text NOT NULL,
    answer text,
    answered_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_claim_queries_answer CHECK (((answered_at IS NULL) OR (length(btrim(COALESCE(answer, ''::text))) > 0))),
    CONSTRAINT chk_claim_queries_question CHECK ((length(btrim(question)) > 0)),
    CONSTRAINT chk_claim_queries_role CHECK (((asked_to_role)::text = ANY (ARRAY[('l1'::character varying)::text, ('l2'::character varying)::text])))
);


--
-- Name: claim_queries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.claim_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: claim_queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.claim_queries_id_seq OWNED BY public.claim_queries.id;


--
-- Name: claim_visit_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.claim_visit_reports (
    id bigint NOT NULL,
    tour_claim_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    visit_date date NOT NULL,
    place_visited character varying(200) NOT NULL,
    tasks_accomplished text,
    action_points text,
    time_frame character varying(100),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    planned_date date,
    tour_visit_id bigint,
    remark character varying(500)
);


--
-- Name: claim_visit_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.claim_visit_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: claim_visit_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.claim_visit_reports_id_seq OWNED BY public.claim_visit_reports.id;


--
-- Name: locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.locations (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    code character varying(20),
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.locations_id_seq OWNED BY public.locations.id;


--
-- Name: mileage_rates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mileage_rates (
    id bigint NOT NULL,
    travel_mode_id bigint NOT NULL,
    rate_per_km numeric(8,2) NOT NULL,
    effective_from date NOT NULL,
    remark character varying(255),
    created_by_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_mileage_rates_positive CHECK ((rate_per_km >= (0)::numeric))
);


--
-- Name: mileage_rates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mileage_rates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mileage_rates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mileage_rates_id_seq OWNED BY public.mileage_rates.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    actor_id bigint,
    notifiable_type character varying NOT NULL,
    notifiable_id bigint NOT NULL,
    kind character varying(40) NOT NULL,
    title character varying(200) NOT NULL,
    body text,
    url character varying(300) NOT NULL,
    read_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: project_budget_line_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_budget_line_items (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    budget_line_item_id bigint NOT NULL,
    budget_line_item_code_id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: project_budget_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_budget_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_budget_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_budget_line_items_id_seq OWNED BY public.project_budget_line_items.id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id bigint NOT NULL,
    name character varying(500) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: tour_approval_steps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tour_approval_steps (
    id bigint NOT NULL,
    tour_id bigint NOT NULL,
    approver_id bigint NOT NULL,
    "position" integer NOT NULL,
    reason character varying(200),
    acted_by_id bigint,
    acted_at timestamp(6) without time zone,
    remark character varying(500),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tour_approval_steps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tour_approval_steps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tour_approval_steps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tour_approval_steps_id_seq OWNED BY public.tour_approval_steps.id;


--
-- Name: tour_claims; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tour_claims (
    id bigint NOT NULL,
    tour_id bigint NOT NULL,
    user_id bigint NOT NULL,
    claim_type character varying(10) NOT NULL,
    status character varying(15) DEFAULT 'draft'::character varying NOT NULL,
    project_id bigint,
    budget_line_item_id bigint,
    budget_line_item_code_id bigint,
    general_description text,
    helmet_declaration boolean DEFAULT false NOT NULL,
    city_travel_total numeric(12,2) DEFAULT 0.0 NOT NULL,
    local_travel_total numeric(12,2) DEFAULT 0.0 NOT NULL,
    lodging_total numeric(12,2) DEFAULT 0.0 NOT NULL,
    da_total numeric(12,2) DEFAULT 0.0 NOT NULL,
    incidental_total numeric(12,2) DEFAULT 0.0 NOT NULL,
    grand_total numeric(12,2) DEFAULT 0.0 NOT NULL,
    advance_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    balance_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    l1_approver_id bigint,
    l2_approver_id bigint,
    submitted_at timestamp(6) without time zone,
    l1_approved_at timestamp(6) without time zone,
    l1_approved_by_id bigint,
    l2_approved_at timestamp(6) without time zone,
    l2_approved_by_id bigint,
    approved_at timestamp(6) without time zone,
    approved_by_id bigint,
    rejected_at timestamp(6) without time zone,
    rejected_by_id bigint,
    reject_remark text,
    cancelled_at timestamp(6) without time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    l1_remark text,
    l2_remark text,
    finance_remark text,
    returned_at timestamp(6) without time zone,
    returned_by_id bigint,
    return_remark text,
    deleted_at timestamp(6) without time zone,
    deleted_by_id bigint,
    delete_remark text,
    finance_approver_id bigint,
    bank_account_id bigint,
    extra_approver_id bigint,
    CONSTRAINT chk_claims_advance_positive CHECK ((advance_amount >= (0)::numeric)),
    CONSTRAINT chk_claims_approved_at_on_approval CHECK ((((status)::text <> 'approved'::text) OR (approved_at IS NOT NULL))),
    CONSTRAINT chk_claims_l1 CHECK ((((status)::text <> 'l1_approved'::text) OR ((l1_approved_at IS NOT NULL) AND (l2_approver_id IS NOT NULL)))),
    CONSTRAINT chk_claims_reject_remark CHECK ((((status)::text <> 'rejected'::text) OR (length(btrim(COALESCE(reject_remark, ''::text))) > 0))),
    CONSTRAINT chk_claims_return_remark CHECK ((((status)::text <> 'returned'::text) OR ((returned_at IS NOT NULL) AND (length(btrim(COALESCE(return_remark, ''::text))) > 0)))),
    CONSTRAINT chk_claims_submitted_l1 CHECK ((((status)::text <> 'submitted'::text) OR (l1_approver_id IS NOT NULL))),
    CONSTRAINT chk_claims_type CHECK (((claim_type)::text = ANY (ARRAY[('tour'::character varying)::text, ('local'::character varying)::text]))),
    CONSTRAINT chk_tour_claims_delete_remark CHECK (((deleted_at IS NULL) OR (length(btrim(COALESCE(delete_remark, ''::text))) > 0))),
    CONSTRAINT chk_tour_claims_extra_pointer CHECK ((((status)::text <> 'extra_pending'::text) OR (extra_approver_id IS NOT NULL))),
    CONSTRAINT chk_tour_claims_status CHECK (((status)::text = ANY (ARRAY[('draft'::character varying)::text, ('submitted'::character varying)::text, ('l1_approved'::character varying)::text, ('extra_pending'::character varying)::text, ('finance_pending'::character varying)::text, ('finance_query'::character varying)::text, ('approved'::character varying)::text, ('returned'::character varying)::text, ('rejected'::character varying)::text, ('cancelled'::character varying)::text])))
);


--
-- Name: tour_claims_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tour_claims_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tour_claims_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tour_claims_id_seq OWNED BY public.tour_claims.id;


--
-- Name: tour_visits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tour_visits (
    id bigint NOT NULL,
    tour_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    visit_date date NOT NULL,
    place character varying(200) NOT NULL,
    travel_mode_id bigint,
    planned_activity text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    ticket_quota character varying(10) DEFAULT 'normal'::character varying NOT NULL,
    CONSTRAINT chk_tour_visits_activity_len CHECK ((char_length(planned_activity) <= 500)),
    CONSTRAINT chk_tour_visits_quota CHECK (((ticket_quota)::text = ANY (ARRAY[('normal'::character varying)::text, ('tatkal'::character varying)::text])))
);


--
-- Name: tour_visits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tour_visits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tour_visits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tour_visits_id_seq OWNED BY public.tour_visits.id;


--
-- Name: tours; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tours (
    id bigint NOT NULL,
    reference_no character varying(30) NOT NULL,
    user_id bigint NOT NULL,
    tour_type character varying(10) DEFAULT 'tour'::character varying NOT NULL,
    from_date date NOT NULL,
    to_date date NOT NULL,
    claim_month date,
    general_description text,
    status character varying(15) DEFAULT 'draft'::character varying NOT NULL,
    approver_id bigint NOT NULL,
    submitted_at timestamp(6) without time zone,
    approved_at timestamp(6) without time zone,
    rejected_at timestamp(6) without time zone,
    decided_by_id bigint,
    decision_remark text,
    cancelled_at timestamp(6) without time zone,
    cancelled_by_id bigint,
    cancel_remark text,
    status_before_cancel character varying(15),
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    l2_approver_id bigint,
    l1_approved_by_id bigint,
    l1_approved_at timestamp(6) without time zone,
    l1_remark text,
    returned_at timestamp(6) without time zone,
    returned_by_id bigint,
    return_remark text,
    deleted_at timestamp(6) without time zone,
    deleted_by_id bigint,
    delete_remark text,
    bank_account_id bigint,
    l3_approver_id bigint,
    l2_approved_by_id bigint,
    l2_approved_at timestamp(6) without time zone,
    l2_remark character varying(500),
    CONSTRAINT chk_tours_approved_at CHECK ((((status)::text <> 'approved'::text) OR (approved_at IS NOT NULL))),
    CONSTRAINT chk_tours_cancel_needs_remark CHECK ((((status)::text <> 'cancelled'::text) OR ((cancelled_at IS NOT NULL) AND (cancel_remark IS NOT NULL) AND (length(btrim(cancel_remark)) > 0)))),
    CONSTRAINT chk_tours_date_order CHECK ((to_date >= from_date)),
    CONSTRAINT chk_tours_delete_remark CHECK (((deleted_at IS NULL) OR (length(btrim(COALESCE(delete_remark, ''::text))) > 0))),
    CONSTRAINT chk_tours_l1_at CHECK ((((status)::text <> 'l1_approved'::text) OR (l1_approved_at IS NOT NULL))),
    CONSTRAINT chk_tours_l2_at CHECK ((((status)::text <> 'l2_approved'::text) OR ((l2_approved_at IS NOT NULL) AND (l3_approver_id IS NOT NULL)))),
    CONSTRAINT chk_tours_local_month CHECK ((((tour_type)::text <> 'local'::text) OR (claim_month IS NOT NULL))),
    CONSTRAINT chk_tours_reject_remark CHECK ((((status)::text <> 'rejected'::text) OR (length(btrim(COALESCE(decision_remark, ''::text))) > 0))),
    CONSTRAINT chk_tours_rejected_at CHECK ((((status)::text <> 'rejected'::text) OR (rejected_at IS NOT NULL))),
    CONSTRAINT chk_tours_return_remark CHECK ((((status)::text <> 'returned'::text) OR ((returned_at IS NOT NULL) AND (length(btrim(COALESCE(return_remark, ''::text))) > 0)))),
    CONSTRAINT chk_tours_status CHECK (((status)::text = ANY (ARRAY[('draft'::character varying)::text, ('submitted'::character varying)::text, ('l1_approved'::character varying)::text, ('l2_approved'::character varying)::text, ('approved'::character varying)::text, ('returned'::character varying)::text, ('rejected'::character varying)::text, ('cancelled'::character varying)::text]))),
    CONSTRAINT chk_tours_submitted_at CHECK ((((status)::text = 'draft'::text) OR ((status)::text = 'cancelled'::text) OR (submitted_at IS NOT NULL))),
    CONSTRAINT chk_tours_type CHECK (((tour_type)::text = ANY (ARRAY[('tour'::character varying)::text, ('local'::character varying)::text])))
);


--
-- Name: tours_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tours_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tours_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tours_id_seq OWNED BY public.tours.id;


--
-- Name: travel_mode_approvers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.travel_mode_approvers (
    id bigint NOT NULL,
    travel_mode_id bigint NOT NULL,
    user_id bigint NOT NULL,
    kind character varying(10) DEFAULT 'approve'::character varying NOT NULL,
    "position" integer DEFAULT 1 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT chk_travel_mode_approvers_kind CHECK (((kind)::text = ANY (ARRAY[('approve'::character varying)::text, ('notify'::character varying)::text, ('tatkal'::character varying)::text])))
);


--
-- Name: travel_mode_approvers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.travel_mode_approvers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: travel_mode_approvers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.travel_mode_approvers_id_seq OWNED BY public.travel_mode_approvers.id;


--
-- Name: travel_modes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.travel_modes (
    id bigint NOT NULL,
    name character varying(60) NOT NULL,
    category character varying(20) DEFAULT 'public'::character varying NOT NULL,
    km_based boolean DEFAULT false NOT NULL,
    for_tour_plan boolean DEFAULT true NOT NULL,
    for_city_travel boolean DEFAULT true NOT NULL,
    for_local_travel boolean DEFAULT false NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_by_id bigint,
    updated_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    manual_total boolean DEFAULT false NOT NULL,
    extra_approver_id bigint,
    is_train boolean DEFAULT false NOT NULL,
    CONSTRAINT chk_travel_modes_category CHECK (((category)::text = ANY (ARRAY[('own_vehicle'::character varying)::text, ('public'::character varying)::text, ('office'::character varying)::text, ('none'::character varying)::text])))
);


--
-- Name: travel_modes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.travel_modes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: travel_modes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.travel_modes_id_seq OWNED BY public.travel_modes.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    emp_code character varying(30) NOT NULL,
    email character varying(150),
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    remember_created_at timestamp(6) without time zone,
    sign_in_count integer DEFAULT 0 NOT NULL,
    current_sign_in_at timestamp(6) without time zone,
    last_sign_in_at timestamp(6) without time zone,
    current_sign_in_ip character varying,
    last_sign_in_ip character varying,
    name character varying(150) NOT NULL,
    designation character varying(100),
    short_designation character varying(20),
    level character varying(10),
    mobile character varying(15),
    location_id bigint,
    reporting_manager_id bigint,
    role character varying(20) DEFAULT 'employee'::character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    l2_manager_id bigint,
    department character varying(100),
    branch character varying(100),
    sub_branch character varying(100),
    date_of_joining date,
    imported_at timestamp(6) without time zone,
    finance_approver_id bigint,
    CONSTRAINT chk_users_not_own_l2 CHECK (((l2_manager_id IS NULL) OR (l2_manager_id <> id))),
    CONSTRAINT chk_users_not_own_manager CHECK (((reporting_manager_id IS NULL) OR (reporting_manager_id <> id))),
    CONSTRAINT chk_users_role CHECK (((role)::text = ANY (ARRAY[('employee'::character varying)::text, ('mis'::character varying)::text, ('pd_hr'::character varying)::text, ('pd_finance'::character varying)::text, ('admin'::character varying)::text])))
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: activity_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_logs ALTER COLUMN id SET DEFAULT nextval('public.activity_logs_id_seq'::regclass);


--
-- Name: app_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_settings ALTER COLUMN id SET DEFAULT nextval('public.app_settings_id_seq'::regclass);


--
-- Name: bank_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_accounts ALTER COLUMN id SET DEFAULT nextval('public.bank_accounts_id_seq'::regclass);


--
-- Name: budget_line_item_codes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_line_item_codes ALTER COLUMN id SET DEFAULT nextval('public.budget_line_item_codes_id_seq'::regclass);


--
-- Name: budget_line_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_line_items ALTER COLUMN id SET DEFAULT nextval('public.budget_line_items_id_seq'::regclass);


--
-- Name: cities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cities ALTER COLUMN id SET DEFAULT nextval('public.cities_id_seq'::regclass);


--
-- Name: claim_approval_steps id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_approval_steps ALTER COLUMN id SET DEFAULT nextval('public.claim_approval_steps_id_seq'::regclass);


--
-- Name: claim_city_travels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_city_travels ALTER COLUMN id SET DEFAULT nextval('public.claim_city_travels_id_seq'::regclass);


--
-- Name: claim_cutoff_rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_cutoff_rules ALTER COLUMN id SET DEFAULT nextval('public.claim_cutoff_rules_id_seq'::regclass);


--
-- Name: claim_daily_allowances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_daily_allowances ALTER COLUMN id SET DEFAULT nextval('public.claim_daily_allowances_id_seq'::regclass);


--
-- Name: claim_incidentals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_incidentals ALTER COLUMN id SET DEFAULT nextval('public.claim_incidentals_id_seq'::regclass);


--
-- Name: claim_local_travels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_local_travels ALTER COLUMN id SET DEFAULT nextval('public.claim_local_travels_id_seq'::regclass);


--
-- Name: claim_lodgings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_lodgings ALTER COLUMN id SET DEFAULT nextval('public.claim_lodgings_id_seq'::regclass);


--
-- Name: claim_queries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_queries ALTER COLUMN id SET DEFAULT nextval('public.claim_queries_id_seq'::regclass);


--
-- Name: claim_visit_reports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_visit_reports ALTER COLUMN id SET DEFAULT nextval('public.claim_visit_reports_id_seq'::regclass);


--
-- Name: locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations ALTER COLUMN id SET DEFAULT nextval('public.locations_id_seq'::regclass);


--
-- Name: mileage_rates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mileage_rates ALTER COLUMN id SET DEFAULT nextval('public.mileage_rates_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: project_budget_line_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_budget_line_items ALTER COLUMN id SET DEFAULT nextval('public.project_budget_line_items_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


--
-- Name: tour_approval_steps id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_approval_steps ALTER COLUMN id SET DEFAULT nextval('public.tour_approval_steps_id_seq'::regclass);


--
-- Name: tour_claims id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims ALTER COLUMN id SET DEFAULT nextval('public.tour_claims_id_seq'::regclass);


--
-- Name: tour_visits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_visits ALTER COLUMN id SET DEFAULT nextval('public.tour_visits_id_seq'::regclass);


--
-- Name: tours id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours ALTER COLUMN id SET DEFAULT nextval('public.tours_id_seq'::regclass);


--
-- Name: travel_mode_approvers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travel_mode_approvers ALTER COLUMN id SET DEFAULT nextval('public.travel_mode_approvers_id_seq'::regclass);


--
-- Name: travel_modes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travel_modes ALTER COLUMN id SET DEFAULT nextval('public.travel_modes_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: activity_logs activity_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_logs
    ADD CONSTRAINT activity_logs_pkey PRIMARY KEY (id);


--
-- Name: app_settings app_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_settings
    ADD CONSTRAINT app_settings_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: bank_accounts bank_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_accounts
    ADD CONSTRAINT bank_accounts_pkey PRIMARY KEY (id);


--
-- Name: budget_line_item_codes budget_line_item_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_line_item_codes
    ADD CONSTRAINT budget_line_item_codes_pkey PRIMARY KEY (id);


--
-- Name: budget_line_items budget_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_line_items
    ADD CONSTRAINT budget_line_items_pkey PRIMARY KEY (id);


--
-- Name: cities cities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_pkey PRIMARY KEY (id);


--
-- Name: claim_approval_steps claim_approval_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_approval_steps
    ADD CONSTRAINT claim_approval_steps_pkey PRIMARY KEY (id);


--
-- Name: claim_city_travels claim_city_travels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_city_travels
    ADD CONSTRAINT claim_city_travels_pkey PRIMARY KEY (id);


--
-- Name: claim_cutoff_rules claim_cutoff_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_cutoff_rules
    ADD CONSTRAINT claim_cutoff_rules_pkey PRIMARY KEY (id);


--
-- Name: claim_daily_allowances claim_daily_allowances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_daily_allowances
    ADD CONSTRAINT claim_daily_allowances_pkey PRIMARY KEY (id);


--
-- Name: claim_incidentals claim_incidentals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_incidentals
    ADD CONSTRAINT claim_incidentals_pkey PRIMARY KEY (id);


--
-- Name: claim_local_travels claim_local_travels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_local_travels
    ADD CONSTRAINT claim_local_travels_pkey PRIMARY KEY (id);


--
-- Name: claim_lodgings claim_lodgings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_lodgings
    ADD CONSTRAINT claim_lodgings_pkey PRIMARY KEY (id);


--
-- Name: claim_queries claim_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_queries
    ADD CONSTRAINT claim_queries_pkey PRIMARY KEY (id);


--
-- Name: claim_visit_reports claim_visit_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_visit_reports
    ADD CONSTRAINT claim_visit_reports_pkey PRIMARY KEY (id);


--
-- Name: tours excl_tours_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT excl_tours_no_overlap EXCLUDE USING gist (user_id WITH =, daterange(from_date, to_date, '[]'::text) WITH &&) WHERE ((((tour_type)::text = 'tour'::text) AND ((status)::text = ANY (ARRAY[('submitted'::character varying)::text, ('l1_approved'::character varying)::text, ('l2_approved'::character varying)::text, ('approved'::character varying)::text])) AND (deleted_at IS NULL)));


--
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- Name: mileage_rates mileage_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mileage_rates
    ADD CONSTRAINT mileage_rates_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: project_budget_line_items project_budget_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_budget_line_items
    ADD CONSTRAINT project_budget_line_items_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tour_approval_steps tour_approval_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_approval_steps
    ADD CONSTRAINT tour_approval_steps_pkey PRIMARY KEY (id);


--
-- Name: tour_claims tour_claims_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT tour_claims_pkey PRIMARY KEY (id);


--
-- Name: tour_visits tour_visits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_visits
    ADD CONSTRAINT tour_visits_pkey PRIMARY KEY (id);


--
-- Name: tours tours_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT tours_pkey PRIMARY KEY (id);


--
-- Name: travel_mode_approvers travel_mode_approvers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travel_mode_approvers
    ADD CONSTRAINT travel_mode_approvers_pkey PRIMARY KEY (id);


--
-- Name: travel_modes travel_modes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travel_modes
    ADD CONSTRAINT travel_modes_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_activity_logs_actor_type_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activity_logs_actor_type_action ON public.activity_logs USING btree (actor_id, trackable_type, action, trackable_id);


--
-- Name: idx_activity_logs_trackable_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activity_logs_trackable_time ON public.activity_logs USING btree (trackable_type, trackable_id, created_at);


--
-- Name: idx_bank_accounts_user_live; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bank_accounts_user_live ON public.bank_accounts USING btree (user_id, active) WHERE (deleted_at IS NULL);


--
-- Name: idx_budget_line_item_codes_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_budget_line_item_codes_lower_name ON public.budget_line_item_codes USING btree (lower((name)::text));


--
-- Name: idx_budget_line_item_codes_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_budget_line_item_codes_name_trgm ON public.budget_line_item_codes USING gin (name public.gin_trgm_ops);


--
-- Name: idx_budget_line_items_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_budget_line_items_lower_name ON public.budget_line_items USING btree (lower((name)::text));


--
-- Name: idx_budget_line_items_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_budget_line_items_name_trgm ON public.budget_line_items USING gin (name public.gin_trgm_ops);


--
-- Name: idx_cities_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_cities_lower_name ON public.cities USING btree (lower((name)::text));


--
-- Name: idx_claim_cutoff_rules_single_global; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_claim_cutoff_rules_single_global ON public.claim_cutoff_rules USING btree (((user_id IS NULL))) WHERE (user_id IS NULL);


--
-- Name: idx_claim_queries_claim; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_claim_queries_claim ON public.claim_queries USING btree (tour_claim_id, created_at);


--
-- Name: idx_claim_queries_open_to; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_claim_queries_open_to ON public.claim_queries USING btree (asked_to_id) WHERE (answered_at IS NULL);


--
-- Name: idx_locations_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_locations_lower_name ON public.locations USING btree (lower((name)::text));


--
-- Name: idx_notifications_unread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_unread ON public.notifications USING btree (user_id) WHERE (read_at IS NULL);


--
-- Name: idx_project_budget_line_item_mapping; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_project_budget_line_item_mapping ON public.project_budget_line_items USING btree (project_id, budget_line_item_id, budget_line_item_code_id);


--
-- Name: idx_projects_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_projects_lower_name ON public.projects USING btree (lower((name)::text));


--
-- Name: idx_projects_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_projects_name_trgm ON public.projects USING gin (name public.gin_trgm_ops);


--
-- Name: idx_tour_claims_extra_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tour_claims_extra_queue ON public.tour_claims USING btree (extra_approver_id, status) WHERE (((status)::text = 'extra_pending'::text) AND (deleted_at IS NULL));


--
-- Name: idx_tour_visits_lower_place; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tour_visits_lower_place ON public.tour_visits USING btree (lower((place)::text));


--
-- Name: idx_tours_l3_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tours_l3_queue ON public.tours USING btree (l3_approver_id, status) WHERE (((status)::text = 'l2_approved'::text) AND (deleted_at IS NULL));


--
-- Name: idx_tours_one_live_local_claim_per_month; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_tours_one_live_local_claim_per_month ON public.tours USING btree (user_id, claim_month) WHERE (((tour_type)::text = 'local'::text) AND ((status)::text = ANY (ARRAY[('submitted'::character varying)::text, ('l1_approved'::character varying)::text, ('approved'::character varying)::text])) AND (deleted_at IS NULL));


--
-- Name: idx_tours_reference_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tours_reference_trgm ON public.tours USING gin (reference_no public.gin_trgm_ops);


--
-- Name: idx_travel_modes_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_travel_modes_lower_name ON public.travel_modes USING btree (lower((name)::text));


--
-- Name: idx_users_emp_code_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_emp_code_trgm ON public.users USING gin (emp_code public.gin_trgm_ops);


--
-- Name: idx_users_lower_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_users_lower_email ON public.users USING btree (lower((email)::text)) WHERE (email IS NOT NULL);


--
-- Name: idx_users_lower_emp_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_users_lower_emp_code ON public.users USING btree (lower((emp_code)::text));


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_activity_logs_on_action_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_logs_on_action_and_created_at ON public.activity_logs USING btree (action, created_at);


--
-- Name: index_activity_logs_on_actor_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_activity_logs_on_actor_id_and_created_at ON public.activity_logs USING btree (actor_id, created_at);


--
-- Name: index_app_settings_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_app_settings_on_key ON public.app_settings USING btree (key);


--
-- Name: index_budget_line_item_codes_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_budget_line_item_codes_on_created_by_id ON public.budget_line_item_codes USING btree (created_by_id);


--
-- Name: index_budget_line_items_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_budget_line_items_on_created_by_id ON public.budget_line_items USING btree (created_by_id);


--
-- Name: index_claim_approval_steps_on_acted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_approval_steps_on_acted_by_id ON public.claim_approval_steps USING btree (acted_by_id) WHERE (acted_by_id IS NOT NULL);


--
-- Name: index_claim_approval_steps_on_approver_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_approval_steps_on_approver_id ON public.claim_approval_steps USING btree (approver_id);


--
-- Name: index_claim_city_travels_on_tour_claim_id_and_travel_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_city_travels_on_tour_claim_id_and_travel_date ON public.claim_city_travels USING btree (tour_claim_id, travel_date);


--
-- Name: index_claim_city_travels_on_travel_mode_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_city_travels_on_travel_mode_id ON public.claim_city_travels USING btree (travel_mode_id);


--
-- Name: index_claim_cutoff_rules_on_updated_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_cutoff_rules_on_updated_by_id ON public.claim_cutoff_rules USING btree (updated_by_id);


--
-- Name: index_claim_cutoff_rules_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_claim_cutoff_rules_on_user_id ON public.claim_cutoff_rules USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: index_claim_daily_allowances_on_city_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_daily_allowances_on_city_id ON public.claim_daily_allowances USING btree (city_id);


--
-- Name: index_claim_daily_allowances_on_tour_claim_id_and_departure_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_daily_allowances_on_tour_claim_id_and_departure_at ON public.claim_daily_allowances USING btree (tour_claim_id, departure_at);


--
-- Name: index_claim_incidentals_on_tour_claim_id_and_expense_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_incidentals_on_tour_claim_id_and_expense_date ON public.claim_incidentals USING btree (tour_claim_id, expense_date);


--
-- Name: index_claim_local_travels_on_tour_claim_id_and_travel_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_local_travels_on_tour_claim_id_and_travel_date ON public.claim_local_travels USING btree (tour_claim_id, travel_date);


--
-- Name: index_claim_local_travels_on_travel_mode_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_local_travels_on_travel_mode_id ON public.claim_local_travels USING btree (travel_mode_id);


--
-- Name: index_claim_lodgings_on_city_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_lodgings_on_city_id ON public.claim_lodgings USING btree (city_id);


--
-- Name: index_claim_lodgings_on_tour_claim_id_and_from_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_lodgings_on_tour_claim_id_and_from_date ON public.claim_lodgings USING btree (tour_claim_id, from_date);


--
-- Name: index_claim_queries_on_asked_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_queries_on_asked_by_id ON public.claim_queries USING btree (asked_by_id);


--
-- Name: index_claim_queries_on_asked_to_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_queries_on_asked_to_id ON public.claim_queries USING btree (asked_to_id);


--
-- Name: index_claim_visit_reports_on_tour_claim_id_and_visit_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_visit_reports_on_tour_claim_id_and_visit_date ON public.claim_visit_reports USING btree (tour_claim_id, visit_date);


--
-- Name: index_claim_visit_reports_on_tour_visit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_claim_visit_reports_on_tour_visit_id ON public.claim_visit_reports USING btree (tour_visit_id);


--
-- Name: index_locations_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_locations_on_code ON public.locations USING btree (code) WHERE (code IS NOT NULL);


--
-- Name: index_mileage_rates_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mileage_rates_on_created_by_id ON public.mileage_rates USING btree (created_by_id);


--
-- Name: index_mileage_rates_on_travel_mode_id_and_effective_from; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_mileage_rates_on_travel_mode_id_and_effective_from ON public.mileage_rates USING btree (travel_mode_id, effective_from DESC);


--
-- Name: index_notifications_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_actor_id ON public.notifications USING btree (actor_id);


--
-- Name: index_notifications_on_notifiable_type_and_notifiable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_notifiable_type_and_notifiable_id ON public.notifications USING btree (notifiable_type, notifiable_id);


--
-- Name: index_notifications_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id_and_created_at ON public.notifications USING btree (user_id, created_at DESC);


--
-- Name: index_project_budget_line_items_on_budget_line_item_code_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_budget_line_items_on_budget_line_item_code_id ON public.project_budget_line_items USING btree (budget_line_item_code_id);


--
-- Name: index_project_budget_line_items_on_budget_line_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_budget_line_items_on_budget_line_item_id ON public.project_budget_line_items USING btree (budget_line_item_id);


--
-- Name: index_project_budget_line_items_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_budget_line_items_on_created_by_id ON public.project_budget_line_items USING btree (created_by_id);


--
-- Name: index_project_budget_line_items_on_project_id_and_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_budget_line_items_on_project_id_and_active ON public.project_budget_line_items USING btree (project_id, active);


--
-- Name: index_projects_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_created_by_id ON public.projects USING btree (created_by_id);


--
-- Name: index_tour_approval_steps_on_acted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_approval_steps_on_acted_by_id ON public.tour_approval_steps USING btree (acted_by_id) WHERE (acted_by_id IS NOT NULL);


--
-- Name: index_tour_approval_steps_on_approver_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_approval_steps_on_approver_id ON public.tour_approval_steps USING btree (approver_id);


--
-- Name: index_tour_claims_on_approved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_approved_by_id ON public.tour_claims USING btree (approved_by_id);


--
-- Name: index_tour_claims_on_bank_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_bank_account_id ON public.tour_claims USING btree (bank_account_id);


--
-- Name: index_tour_claims_on_budget_line_item_code_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_budget_line_item_code_id ON public.tour_claims USING btree (budget_line_item_code_id);


--
-- Name: index_tour_claims_on_budget_line_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_budget_line_item_id ON public.tour_claims USING btree (budget_line_item_id);


--
-- Name: index_tour_claims_on_claim_type_and_status_and_approved_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_claim_type_and_status_and_approved_at ON public.tour_claims USING btree (claim_type, status, approved_at);


--
-- Name: index_tour_claims_on_claim_type_and_status_and_submitted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_claim_type_and_status_and_submitted_at ON public.tour_claims USING btree (claim_type, status, submitted_at);


--
-- Name: index_tour_claims_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_deleted_at ON public.tour_claims USING btree (deleted_at) WHERE (deleted_at IS NOT NULL);


--
-- Name: index_tour_claims_on_deleted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_deleted_by_id ON public.tour_claims USING btree (deleted_by_id) WHERE (deleted_by_id IS NOT NULL);


--
-- Name: index_tour_claims_on_finance_approver_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_finance_approver_id_and_status ON public.tour_claims USING btree (finance_approver_id, status);


--
-- Name: index_tour_claims_on_l1_approved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_l1_approved_by_id ON public.tour_claims USING btree (l1_approved_by_id);


--
-- Name: index_tour_claims_on_l1_approver_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_l1_approver_id_and_status ON public.tour_claims USING btree (l1_approver_id, status);


--
-- Name: index_tour_claims_on_l2_approved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_l2_approved_by_id ON public.tour_claims USING btree (l2_approved_by_id);


--
-- Name: index_tour_claims_on_l2_approver_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_l2_approver_id_and_status ON public.tour_claims USING btree (l2_approver_id, status);


--
-- Name: index_tour_claims_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_project_id ON public.tour_claims USING btree (project_id);


--
-- Name: index_tour_claims_on_rejected_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_rejected_by_id ON public.tour_claims USING btree (rejected_by_id);


--
-- Name: index_tour_claims_on_returned_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_returned_by_id ON public.tour_claims USING btree (returned_by_id) WHERE (returned_by_id IS NOT NULL);


--
-- Name: index_tour_claims_on_status_and_submitted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_status_and_submitted_at ON public.tour_claims USING btree (status, submitted_at);


--
-- Name: index_tour_claims_on_tour_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tour_claims_on_tour_id ON public.tour_claims USING btree (tour_id) WHERE (deleted_at IS NULL);


--
-- Name: index_tour_claims_on_user_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_claims_on_user_id_and_status ON public.tour_claims USING btree (user_id, status);


--
-- Name: index_tour_visits_on_tour_id_and_visit_date_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_visits_on_tour_id_and_visit_date_and_position ON public.tour_visits USING btree (tour_id, visit_date, "position");


--
-- Name: index_tour_visits_on_travel_mode_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tour_visits_on_travel_mode_id ON public.tour_visits USING btree (travel_mode_id);


--
-- Name: index_tours_on_approver_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_approver_id_and_status ON public.tours USING btree (approver_id, status);


--
-- Name: index_tours_on_bank_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_bank_account_id ON public.tours USING btree (bank_account_id);


--
-- Name: index_tours_on_cancelled_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_cancelled_by_id ON public.tours USING btree (cancelled_by_id);


--
-- Name: index_tours_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_created_at ON public.tours USING btree (created_at DESC);


--
-- Name: index_tours_on_decided_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_decided_by_id ON public.tours USING btree (decided_by_id);


--
-- Name: index_tours_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_deleted_at ON public.tours USING btree (deleted_at) WHERE (deleted_at IS NOT NULL);


--
-- Name: index_tours_on_deleted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_deleted_by_id ON public.tours USING btree (deleted_by_id) WHERE (deleted_by_id IS NOT NULL);


--
-- Name: index_tours_on_l1_approved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_l1_approved_by_id ON public.tours USING btree (l1_approved_by_id) WHERE (l1_approved_by_id IS NOT NULL);


--
-- Name: index_tours_on_l2_approved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_l2_approved_by_id ON public.tours USING btree (l2_approved_by_id);


--
-- Name: index_tours_on_l2_approver_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_l2_approver_id_and_status ON public.tours USING btree (l2_approver_id, status);


--
-- Name: index_tours_on_l3_approver_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_l3_approver_id ON public.tours USING btree (l3_approver_id);


--
-- Name: index_tours_on_reference_no; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tours_on_reference_no ON public.tours USING btree (reference_no);


--
-- Name: index_tours_on_returned_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_returned_by_id ON public.tours USING btree (returned_by_id) WHERE (returned_by_id IS NOT NULL);


--
-- Name: index_tours_on_status_and_from_date_and_to_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_status_and_from_date_and_to_date ON public.tours USING btree (status, from_date, to_date);


--
-- Name: index_tours_on_user_id_and_from_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_user_id_and_from_date ON public.tours USING btree (user_id, from_date DESC);


--
-- Name: index_tours_on_user_id_and_tour_type_and_from_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_user_id_and_tour_type_and_from_date ON public.tours USING btree (user_id, tour_type, from_date DESC);


--
-- Name: index_tours_on_user_id_and_tour_type_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tours_on_user_id_and_tour_type_and_status ON public.tours USING btree (user_id, tour_type, status);


--
-- Name: index_travel_mode_approvers_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_travel_mode_approvers_on_user_id ON public.travel_mode_approvers USING btree (user_id);


--
-- Name: index_travel_modes_on_active_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_travel_modes_on_active_and_position ON public.travel_modes USING btree (active, "position");


--
-- Name: index_travel_modes_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_travel_modes_on_created_by_id ON public.travel_modes USING btree (created_by_id);


--
-- Name: index_travel_modes_on_extra_approver_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_travel_modes_on_extra_approver_id ON public.travel_modes USING btree (extra_approver_id);


--
-- Name: index_travel_modes_on_updated_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_travel_modes_on_updated_by_id ON public.travel_modes USING btree (updated_by_id);


--
-- Name: index_users_on_department; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_department ON public.users USING btree (department);


--
-- Name: index_users_on_finance_approver_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_finance_approver_id ON public.users USING btree (finance_approver_id);


--
-- Name: index_users_on_l2_manager_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_l2_manager_id ON public.users USING btree (l2_manager_id);


--
-- Name: index_users_on_location_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_location_id ON public.users USING btree (location_id);


--
-- Name: index_users_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_name ON public.users USING gin (name public.gin_trgm_ops);


--
-- Name: index_users_on_reporting_manager_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_reporting_manager_id ON public.users USING btree (reporting_manager_id);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_role_and_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_role_and_active ON public.users USING btree (role, active);


--
-- Name: uniq_bank_accounts_one_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_bank_accounts_one_primary ON public.bank_accounts USING btree (user_id) WHERE ("primary" AND (deleted_at IS NULL));


--
-- Name: uniq_bank_accounts_user_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_bank_accounts_user_number ON public.bank_accounts USING btree (user_id, account_number) WHERE (deleted_at IS NULL);


--
-- Name: uniq_claim_approval_steps; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_claim_approval_steps ON public.claim_approval_steps USING btree (tour_claim_id, "position");


--
-- Name: uniq_claim_queries_open; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_claim_queries_open ON public.claim_queries USING btree (tour_claim_id) WHERE (answered_at IS NULL);


--
-- Name: uniq_tour_approval_steps; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_tour_approval_steps ON public.tour_approval_steps USING btree (tour_id, "position");


--
-- Name: uniq_travel_mode_approvers; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_travel_mode_approvers ON public.travel_mode_approvers USING btree (travel_mode_id, kind, user_id);


--
-- Name: activity_logs trg_activity_logs_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_activity_logs_immutable BEFORE DELETE OR UPDATE ON public.activity_logs FOR EACH ROW EXECUTE FUNCTION public.activity_logs_immutable();


--
-- Name: tours fk_rails_01d84de789; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT fk_rails_01d84de789 FOREIGN KEY (approver_id) REFERENCES public.users(id);


--
-- Name: budget_line_item_codes fk_rails_02399bbc12; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_line_item_codes
    ADD CONSTRAINT fk_rails_02399bbc12 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: notifications fk_rails_06a39bb8cc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_06a39bb8cc FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: claim_approval_steps fk_rails_0a3067ad35; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_approval_steps
    ADD CONSTRAINT fk_rails_0a3067ad35 FOREIGN KEY (tour_claim_id) REFERENCES public.tour_claims(id);


--
-- Name: tour_claims fk_rails_0b7f8323ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_0b7f8323ff FOREIGN KEY (finance_approver_id) REFERENCES public.users(id);


--
-- Name: users fk_rails_0b9dadfe01; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_0b9dadfe01 FOREIGN KEY (l2_manager_id) REFERENCES public.users(id);


--
-- Name: claim_lodgings fk_rails_0d081f0637; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_lodgings
    ADD CONSTRAINT fk_rails_0d081f0637 FOREIGN KEY (tour_claim_id) REFERENCES public.tour_claims(id) ON DELETE CASCADE;


--
-- Name: tours fk_rails_1489ad0ecf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT fk_rails_1489ad0ecf FOREIGN KEY (l2_approver_id) REFERENCES public.users(id);


--
-- Name: claim_local_travels fk_rails_22bf69fc10; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_local_travels
    ADD CONSTRAINT fk_rails_22bf69fc10 FOREIGN KEY (tour_claim_id) REFERENCES public.tour_claims(id) ON DELETE CASCADE;


--
-- Name: mileage_rates fk_rails_2371d170a3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mileage_rates
    ADD CONSTRAINT fk_rails_2371d170a3 FOREIGN KEY (travel_mode_id) REFERENCES public.travel_modes(id);


--
-- Name: claim_approval_steps fk_rails_2478335162; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_approval_steps
    ADD CONSTRAINT fk_rails_2478335162 FOREIGN KEY (acted_by_id) REFERENCES public.users(id);


--
-- Name: tour_approval_steps fk_rails_284bdd4c6c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_approval_steps
    ADD CONSTRAINT fk_rails_284bdd4c6c FOREIGN KEY (tour_id) REFERENCES public.tours(id);


--
-- Name: budget_line_items fk_rails_2c4ced0236; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_line_items
    ADD CONSTRAINT fk_rails_2c4ced0236 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: tour_claims fk_rails_3105cdcfb3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_3105cdcfb3 FOREIGN KEY (tour_id) REFERENCES public.tours(id);


--
-- Name: tour_claims fk_rails_32b0d2a762; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_32b0d2a762 FOREIGN KEY (l1_approver_id) REFERENCES public.users(id);


--
-- Name: mileage_rates fk_rails_38f23686b7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mileage_rates
    ADD CONSTRAINT fk_rails_38f23686b7 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: project_budget_line_items fk_rails_41ac1e8e05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_budget_line_items
    ADD CONSTRAINT fk_rails_41ac1e8e05 FOREIGN KEY (budget_line_item_id) REFERENCES public.budget_line_items(id);


--
-- Name: tour_claims fk_rails_430bfd8c8e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_430bfd8c8e FOREIGN KEY (returned_by_id) REFERENCES public.users(id);


--
-- Name: project_budget_line_items fk_rails_438e3a1d7d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_budget_line_items
    ADD CONSTRAINT fk_rails_438e3a1d7d FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: project_budget_line_items fk_rails_4411b0c1c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_budget_line_items
    ADD CONSTRAINT fk_rails_4411b0c1c2 FOREIGN KEY (budget_line_item_code_id) REFERENCES public.budget_line_item_codes(id);


--
-- Name: claim_cutoff_rules fk_rails_464afbbb12; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_cutoff_rules
    ADD CONSTRAINT fk_rails_464afbbb12 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: tour_claims fk_rails_47835be345; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_47835be345 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: claim_daily_allowances fk_rails_4c5b86eaed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_daily_allowances
    ADD CONSTRAINT fk_rails_4c5b86eaed FOREIGN KEY (city_id) REFERENCES public.cities(id);


--
-- Name: travel_mode_approvers fk_rails_516f3b7ac4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travel_mode_approvers
    ADD CONSTRAINT fk_rails_516f3b7ac4 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: tours fk_rails_53df0d7133; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT fk_rails_53df0d7133 FOREIGN KEY (deleted_by_id) REFERENCES public.users(id);


--
-- Name: tours fk_rails_5587d80860; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT fk_rails_5587d80860 FOREIGN KEY (returned_by_id) REFERENCES public.users(id);


--
-- Name: tours fk_rails_5b2d55744e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT fk_rails_5b2d55744e FOREIGN KEY (l1_approved_by_id) REFERENCES public.users(id);


--
-- Name: users fk_rails_5d96f79c2b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_5d96f79c2b FOREIGN KEY (location_id) REFERENCES public.locations(id);


--
-- Name: tours fk_rails_644aa67ccf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT fk_rails_644aa67ccf FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: tour_claims fk_rails_65ee21bbf9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_65ee21bbf9 FOREIGN KEY (l2_approved_by_id) REFERENCES public.users(id);


--
-- Name: tour_claims fk_rails_661ff7f4ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_661ff7f4ad FOREIGN KEY (rejected_by_id) REFERENCES public.users(id);


--
-- Name: tour_claims fk_rails_6a2ab31bd5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_6a2ab31bd5 FOREIGN KEY (budget_line_item_code_id) REFERENCES public.budget_line_item_codes(id);


--
-- Name: tours fk_rails_6d5f346c9b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT fk_rails_6d5f346c9b FOREIGN KEY (l3_approver_id) REFERENCES public.users(id);


--
-- Name: tours fk_rails_7315db7678; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT fk_rails_7315db7678 FOREIGN KEY (cancelled_by_id) REFERENCES public.users(id);


--
-- Name: claim_queries fk_rails_7696706ba5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_queries
    ADD CONSTRAINT fk_rails_7696706ba5 FOREIGN KEY (asked_by_id) REFERENCES public.users(id);


--
-- Name: travel_modes fk_rails_7a374d2b59; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travel_modes
    ADD CONSTRAINT fk_rails_7a374d2b59 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: tour_visits fk_rails_7a91f848c4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_visits
    ADD CONSTRAINT fk_rails_7a91f848c4 FOREIGN KEY (travel_mode_id) REFERENCES public.travel_modes(id);


--
-- Name: claim_city_travels fk_rails_7ddb7af104; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_city_travels
    ADD CONSTRAINT fk_rails_7ddb7af104 FOREIGN KEY (travel_mode_id) REFERENCES public.travel_modes(id);


--
-- Name: users fk_rails_90903bbe9f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_90903bbe9f FOREIGN KEY (reporting_manager_id) REFERENCES public.users(id);


--
-- Name: travel_mode_approvers fk_rails_917c8a14eb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travel_mode_approvers
    ADD CONSTRAINT fk_rails_917c8a14eb FOREIGN KEY (travel_mode_id) REFERENCES public.travel_modes(id);


--
-- Name: bank_accounts fk_rails_92daa8a387; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_accounts
    ADD CONSTRAINT fk_rails_92daa8a387 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: tour_claims fk_rails_9636e48c64; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_9636e48c64 FOREIGN KEY (extra_approver_id) REFERENCES public.users(id);


--
-- Name: claim_daily_allowances fk_rails_9683c3338d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_daily_allowances
    ADD CONSTRAINT fk_rails_9683c3338d FOREIGN KEY (tour_claim_id) REFERENCES public.tour_claims(id) ON DELETE CASCADE;


--
-- Name: claim_visit_reports fk_rails_970d219e9e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_visit_reports
    ADD CONSTRAINT fk_rails_970d219e9e FOREIGN KEY (tour_claim_id) REFERENCES public.tour_claims(id) ON DELETE CASCADE;


--
-- Name: tour_claims fk_rails_97f9432ff6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_97f9432ff6 FOREIGN KEY (l2_approver_id) REFERENCES public.users(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: tour_claims fk_rails_a1078abac1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_a1078abac1 FOREIGN KEY (deleted_by_id) REFERENCES public.users(id);


--
-- Name: tour_claims fk_rails_a2d1371179; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_a2d1371179 FOREIGN KEY (l1_approved_by_id) REFERENCES public.users(id);


--
-- Name: tour_approval_steps fk_rails_a481235531; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_approval_steps
    ADD CONSTRAINT fk_rails_a481235531 FOREIGN KEY (approver_id) REFERENCES public.users(id);


--
-- Name: tour_claims fk_rails_a73f1aae51; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_a73f1aae51 FOREIGN KEY (bank_account_id) REFERENCES public.bank_accounts(id);


--
-- Name: tour_visits fk_rails_a8543dfc0a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_visits
    ADD CONSTRAINT fk_rails_a8543dfc0a FOREIGN KEY (tour_id) REFERENCES public.tours(id) ON DELETE CASCADE;


--
-- Name: notifications fk_rails_b080fb4855; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_b080fb4855 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: travel_modes fk_rails_b0be317ad0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travel_modes
    ADD CONSTRAINT fk_rails_b0be317ad0 FOREIGN KEY (updated_by_id) REFERENCES public.users(id);


--
-- Name: claim_lodgings fk_rails_b2657fadfd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_lodgings
    ADD CONSTRAINT fk_rails_b2657fadfd FOREIGN KEY (city_id) REFERENCES public.cities(id);


--
-- Name: claim_approval_steps fk_rails_bbde84c1f2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_approval_steps
    ADD CONSTRAINT fk_rails_bbde84c1f2 FOREIGN KEY (approver_id) REFERENCES public.users(id);


--
-- Name: claim_queries fk_rails_c1e3f86a5d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_queries
    ADD CONSTRAINT fk_rails_c1e3f86a5d FOREIGN KEY (asked_to_id) REFERENCES public.users(id);


--
-- Name: project_budget_line_items fk_rails_c2223076d8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_budget_line_items
    ADD CONSTRAINT fk_rails_c2223076d8 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: claim_visit_reports fk_rails_c482c19af6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_visit_reports
    ADD CONSTRAINT fk_rails_c482c19af6 FOREIGN KEY (tour_visit_id) REFERENCES public.tour_visits(id) ON DELETE SET NULL;


--
-- Name: tours fk_rails_ce97bbf2d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT fk_rails_ce97bbf2d2 FOREIGN KEY (decided_by_id) REFERENCES public.users(id);


--
-- Name: tours fk_rails_d0ac775716; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT fk_rails_d0ac775716 FOREIGN KEY (l2_approved_by_id) REFERENCES public.users(id);


--
-- Name: claim_city_travels fk_rails_d106476d68; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_city_travels
    ADD CONSTRAINT fk_rails_d106476d68 FOREIGN KEY (tour_claim_id) REFERENCES public.tour_claims(id) ON DELETE CASCADE;


--
-- Name: claim_queries fk_rails_d4de47f9f8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_queries
    ADD CONSTRAINT fk_rails_d4de47f9f8 FOREIGN KEY (tour_claim_id) REFERENCES public.tour_claims(id);


--
-- Name: travel_modes fk_rails_d5b82029ec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travel_modes
    ADD CONSTRAINT fk_rails_d5b82029ec FOREIGN KEY (extra_approver_id) REFERENCES public.users(id);


--
-- Name: tour_claims fk_rails_d8e14b967e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_d8e14b967e FOREIGN KEY (approved_by_id) REFERENCES public.users(id);


--
-- Name: tours fk_rails_dc8049dcc8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tours
    ADD CONSTRAINT fk_rails_dc8049dcc8 FOREIGN KEY (bank_account_id) REFERENCES public.bank_accounts(id);


--
-- Name: activity_logs fk_rails_e05e7e3481; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_logs
    ADD CONSTRAINT fk_rails_e05e7e3481 FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: users fk_rails_e87c082329; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_e87c082329 FOREIGN KEY (finance_approver_id) REFERENCES public.users(id);


--
-- Name: claim_cutoff_rules fk_rails_e9139c0a63; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_cutoff_rules
    ADD CONSTRAINT fk_rails_e9139c0a63 FOREIGN KEY (updated_by_id) REFERENCES public.users(id);


--
-- Name: claim_local_travels fk_rails_ed842838bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_local_travels
    ADD CONSTRAINT fk_rails_ed842838bf FOREIGN KEY (travel_mode_id) REFERENCES public.travel_modes(id);


--
-- Name: tour_approval_steps fk_rails_f0209ad7e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_approval_steps
    ADD CONSTRAINT fk_rails_f0209ad7e6 FOREIGN KEY (acted_by_id) REFERENCES public.users(id);


--
-- Name: claim_incidentals fk_rails_f1d093a8f4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_incidentals
    ADD CONSTRAINT fk_rails_f1d093a8f4 FOREIGN KEY (tour_claim_id) REFERENCES public.tour_claims(id) ON DELETE CASCADE;


--
-- Name: tour_claims fk_rails_f2b7ed43aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_f2b7ed43aa FOREIGN KEY (budget_line_item_id) REFERENCES public.budget_line_items(id);


--
-- Name: app_settings fk_rails_f31be33b10; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_settings
    ADD CONSTRAINT fk_rails_f31be33b10 FOREIGN KEY (updated_by_id) REFERENCES public.users(id);


--
-- Name: tour_claims fk_rails_fc59a6d7c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_claims
    ADD CONSTRAINT fk_rails_fc59a6d7c3 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: projects fk_rails_ff595c9009; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_ff595c9009 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261102100001'),
('20261030160001'),
('20261030120001'),
('20261030110001'),
('20261030100001'),
('20261029100001'),
('20261028160001'),
('20261028150001'),
('20261028140001'),
('20261028130001'),
('20261028120002'),
('20261028120001'),
('20261028110001'),
('20261028100001'),
('20261027130001'),
('20261027120002'),
('20261027120001'),
('20261027110301'),
('20261027110300'),
('20261027110200'),
('20261027110100'),
('20261027110000'),
('20261027100001'),
('20261026100005'),
('20261026100004'),
('20261026100003'),
('20261026100002'),
('20261026100001'),
('20261023100006'),
('20261023100005'),
('20261023100004'),
('20261023100003'),
('20261023100002'),
('20261023100001');

