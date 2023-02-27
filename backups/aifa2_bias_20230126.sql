--
-- PostgreSQL database dump
--

-- Dumped from database version 14.5 (Ubuntu 14.5-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 14.5 (Ubuntu 14.5-0ubuntu0.22.04.1)

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
-- Name: basins; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA basins;


ALTER SCHEMA basins OWNER TO postgres;

--
-- Name: biascorrection; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA biascorrection;


ALTER SCHEMA biascorrection OWNER TO postgres;

--
-- Name: bz; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA bz;


ALTER SCHEMA bz OWNER TO postgres;

--
-- Name: icon; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA icon;


ALTER SCHEMA icon OWNER TO postgres;

--
-- Name: ml; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA ml;


ALTER SCHEMA ml OWNER TO postgres;

--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: basins; Type: TABLE; Schema: basins; Owner: postgres
--

CREATE TABLE basins.basins (
    name text,
    geom public.geometry(Polygon,4326),
    id text NOT NULL,
    notes text,
    sub_id text NOT NULL,
    sub_name text,
    ml_training_date date,
    ml_training_datetime timestamp without time zone,
    gaia_uesid integer,
    gaia_name text,
    ml_streamflow_source text,
    alperia_market_name text,
    CONSTRAINT ml_streamflow_source_check CHECK ((ml_streamflow_source = ANY (ARRAY['bz'::text, 'gaia'::text])))
);


ALTER TABLE basins.basins OWNER TO postgres;

--
-- Name: COLUMN basins.sub_id; Type: COMMENT; Schema: basins; Owner: postgres
--

COMMENT ON COLUMN basins.basins.sub_id IS 'Subbasin ID';


--
-- Name: COLUMN basins.gaia_uesid; Type: COMMENT; Schema: basins; Owner: postgres
--

COMMENT ON COLUMN basins.basins.gaia_uesid IS 'Nome GAIA';


--
-- Name: COLUMN basins.gaia_name; Type: COMMENT; Schema: basins; Owner: postgres
--

COMMENT ON COLUMN basins.basins.gaia_name IS 'Nome GAIA ("Bacino" nelle API)';


--
-- Name: COLUMN basins.ml_streamflow_source; Type: COMMENT; Schema: basins; Owner: postgres
--

COMMENT ON COLUMN basins.basins.ml_streamflow_source IS 'Fonte delle portate per ML';


--
-- Name: basins_pts; Type: VIEW; Schema: basins; Owner: postgres
--

CREATE VIEW basins.basins_pts AS
 WITH pts AS (
         SELECT DISTINCT basins.id,
            basins.sub_id,
            ((public.st_dumppoints((public.st_squaregrid((0.02)::double precision, basins.geom)).geom)).geom)::public.geometry(Point,4326) AS geom
           FROM basins.basins
        )
 SELECT pts.id,
    pts.sub_id,
    (public.st_collect(pts.geom))::public.geometry(MultiPoint,4326) AS geom
   FROM (pts pts
     JOIN basins.basins bas ON (public.st_intersects(pts.geom, bas.geom)))
  WHERE ((pts.id = bas.id) AND (pts.sub_id = bas.sub_id))
  GROUP BY pts.id, pts.sub_id;


ALTER TABLE basins.basins_pts OWNER TO postgres;

--
-- Name: corrected; Type: TABLE; Schema: biascorrection; Owner: postgres
--

CREATE TABLE biascorrection.corrected (
    basin_id text NOT NULL,
    subbasin_id text NOT NULL,
    event text NOT NULL,
    variable text NOT NULL,
    sim_date date NOT NULL,
    sim_datetime timestamp without time zone NOT NULL,
    mean double precision,
    ensemble double precision[],
    CONSTRAINT event_check CHECK ((event = ANY (ARRAY['00'::text, '03'::text, '06'::text, '09'::text, '12'::text, '15'::text, '18'::text, '21'::text])))
);


ALTER TABLE biascorrection.corrected OWNER TO postgres;

--
-- Name: docker_images; Type: TABLE; Schema: biascorrection; Owner: postgres
--

CREATE TABLE biascorrection.docker_images (
    tag text NOT NULL,
    created_on timestamp without time zone,
    notes text
);


ALTER TABLE biascorrection.docker_images OWNER TO postgres;

--
-- Name: basins_stations; Type: TABLE; Schema: bz; Owner: postgres
--

CREATE TABLE bz.basins_stations (
    basin_id text NOT NULL,
    subbasin_id text NOT NULL,
    station_id bigint NOT NULL,
    station_scode text NOT NULL,
    sensor_type text NOT NULL
);


ALTER TABLE bz.basins_stations OWNER TO postgres;

--
-- Name: sensors; Type: TABLE; Schema: bz; Owner: postgres
--

CREATE TABLE bz.sensors (
    type text NOT NULL,
    desc_it text,
    desc_de text,
    units text
);


ALTER TABLE bz.sensors OWNER TO postgres;

--
-- Name: stations; Type: TABLE; Schema: bz; Owner: postgres
--

CREATE TABLE bz.stations (
    ogc_fid integer NOT NULL,
    geom public.geometry(Point,25832),
    scode character varying,
    name_d character varying,
    name_i character varying,
    name_l character varying,
    name_e character varying,
    alt double precision,
    long double precision,
    lat double precision,
    id_hist bigint
);


ALTER TABLE bz.stations OWNER TO postgres;

--
-- Name: COLUMN stations.id_hist; Type: COMMENT; Schema: bz; Owner: postgres
--

COMMENT ON COLUMN bz.stations.id_hist IS 'ID stazioni storiche (ID dato da Daniele)';


--
-- Name: stations_hist; Type: TABLE; Schema: bz; Owner: postgres
--

CREATE TABLE bz.stations_hist (
    id bigint NOT NULL,
    x double precision,
    y double precision,
    z double precision,
    station text,
    id_ui text,
    flag_t integer,
    flag_p integer,
    flag_q integer
);


ALTER TABLE bz.stations_hist OWNER TO postgres;

--
-- Name: COLUMN stations_hist.id_ui; Type: COMMENT; Schema: bz; Owner: postgres
--

COMMENT ON COLUMN bz.stations_hist.id_ui IS 'Corrisponde a "scode" di dati online';


--
-- Name: time_series; Type: TABLE; Schema: bz; Owner: postgres
--

CREATE TABLE bz.time_series (
    scode text NOT NULL,
    recorded_on timestamp without time zone NOT NULL,
    value double precision,
    type text NOT NULL,
    station_id bigint
);


ALTER TABLE bz.time_series OWNER TO postgres;

--
-- Name: COLUMN time_series.type; Type: COMMENT; Schema: bz; Owner: postgres
--

COMMENT ON COLUMN bz.time_series.type IS 'LT = Lufttemperatur (Temperatura dell´aria)
N = Niederschlag (Precipitazioni)
Q = Durchfluss (Portata) m3/s';


--
-- Name: COLUMN time_series.station_id; Type: COMMENT; Schema: bz; Owner: postgres
--

COMMENT ON COLUMN bz.time_series.station_id IS 'ID da csv storici';


--
-- Name: icon_grib2_files; Type: TABLE; Schema: icon; Owner: postgres
--

CREATE TABLE icon.icon_grib2_files (
    file_name text NOT NULL,
    file_date date,
    sim_hour character(3),
    downloaded boolean,
    uncompressed boolean,
    resorted boolean,
    remapped boolean,
    cropped boolean,
    var_name text,
    event text,
    data_extracted boolean,
    instant_rainfall boolean
);


ALTER TABLE icon.icon_grib2_files OWNER TO postgres;

--
-- Name: COLUMN icon_grib2_files.var_name; Type: COMMENT; Schema: icon; Owner: postgres
--

COMMENT ON COLUMN icon.icon_grib2_files.var_name IS 't_2m, tot_prec...';


--
-- Name: processed_data; Type: TABLE; Schema: icon; Owner: postgres
--

CREATE TABLE icon.processed_data (
    basin_id text NOT NULL,
    var_name text NOT NULL,
    "values" double precision[],
    event text NOT NULL,
    file_date date NOT NULL,
    sim_hour text NOT NULL,
    subbasin_id text NOT NULL,
    sim_datetime timestamp without time zone,
    instant_rainfall boolean
);


ALTER TABLE icon.processed_data OWNER TO postgres;

--
-- Name: COLUMN processed_data.instant_rainfall; Type: COMMENT; Schema: icon; Owner: postgres
--

COMMENT ON COLUMN icon.processed_data.instant_rainfall IS 'Tells whether rainfall has been converter from cumulative to instant';


--
-- Name: forecasts; Type: TABLE; Schema: ml; Owner: postgres
--

CREATE TABLE ml.forecasts (
    basin_id text NOT NULL,
    subbasin_id text NOT NULL,
    sim_date date NOT NULL,
    event text NOT NULL,
    "values" double precision[]
);


ALTER TABLE ml.forecasts OWNER TO postgres;

--
-- Name: authorities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.authorities (
    username text NOT NULL,
    authority text NOT NULL
);


ALTER TABLE public.authorities OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    username text NOT NULL,
    password text NOT NULL,
    email text,
    enabled boolean DEFAULT true NOT NULL
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.users ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: basins basins_pkey; Type: CONSTRAINT; Schema: basins; Owner: postgres
--

ALTER TABLE ONLY basins.basins
    ADD CONSTRAINT basins_pkey PRIMARY KEY (id, sub_id);


--
-- Name: corrected corrected_pkey; Type: CONSTRAINT; Schema: biascorrection; Owner: postgres
--

ALTER TABLE ONLY biascorrection.corrected
    ADD CONSTRAINT corrected_pkey PRIMARY KEY (basin_id, subbasin_id, event, variable, sim_date, sim_datetime);


--
-- Name: docker_images docker_images_pkey; Type: CONSTRAINT; Schema: biascorrection; Owner: postgres
--

ALTER TABLE ONLY biascorrection.docker_images
    ADD CONSTRAINT docker_images_pkey PRIMARY KEY (tag);


--
-- Name: basins_stations basins_stations_pkey; Type: CONSTRAINT; Schema: bz; Owner: postgres
--

ALTER TABLE ONLY bz.basins_stations
    ADD CONSTRAINT basins_stations_pkey PRIMARY KEY (basin_id, subbasin_id, station_scode, sensor_type);


--
-- Name: sensors sensors_pkey; Type: CONSTRAINT; Schema: bz; Owner: postgres
--

ALTER TABLE ONLY bz.sensors
    ADD CONSTRAINT sensors_pkey PRIMARY KEY (type);


--
-- Name: stations_hist stations_hist_pkey; Type: CONSTRAINT; Schema: bz; Owner: postgres
--

ALTER TABLE ONLY bz.stations_hist
    ADD CONSTRAINT stations_hist_pkey PRIMARY KEY (id);


--
-- Name: stations stations_id_hist_key; Type: CONSTRAINT; Schema: bz; Owner: postgres
--

ALTER TABLE ONLY bz.stations
    ADD CONSTRAINT stations_id_hist_key UNIQUE (id_hist);


--
-- Name: stations stations_pkey; Type: CONSTRAINT; Schema: bz; Owner: postgres
--

ALTER TABLE ONLY bz.stations
    ADD CONSTRAINT stations_pkey PRIMARY KEY (ogc_fid);


--
-- Name: stations stations_scode_key; Type: CONSTRAINT; Schema: bz; Owner: postgres
--

ALTER TABLE ONLY bz.stations
    ADD CONSTRAINT stations_scode_key UNIQUE (scode);


--
-- Name: time_series time_series_pkey; Type: CONSTRAINT; Schema: bz; Owner: postgres
--

ALTER TABLE ONLY bz.time_series
    ADD CONSTRAINT time_series_pkey PRIMARY KEY (scode, type, recorded_on);


--
-- Name: icon_grib2_files icon_grib2_files_pkey; Type: CONSTRAINT; Schema: icon; Owner: postgres
--

ALTER TABLE ONLY icon.icon_grib2_files
    ADD CONSTRAINT icon_grib2_files_pkey PRIMARY KEY (file_name);


--
-- Name: processed_data processed_data_pkey; Type: CONSTRAINT; Schema: icon; Owner: postgres
--

ALTER TABLE ONLY icon.processed_data
    ADD CONSTRAINT processed_data_pkey PRIMARY KEY (basin_id, subbasin_id, var_name, event, file_date, sim_hour);


--
-- Name: forecasts forecasts_pkey; Type: CONSTRAINT; Schema: ml; Owner: postgres
--

ALTER TABLE ONLY ml.forecasts
    ADD CONSTRAINT forecasts_pkey PRIMARY KEY (basin_id, subbasin_id, sim_date, event);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: fki_basin_subbasin_fkey; Type: INDEX; Schema: bz; Owner: postgres
--

CREATE INDEX fki_basin_subbasin_fkey ON bz.basins_stations USING btree (subbasin_id, subbasin_id);


--
-- Name: fki_sensor_fkey; Type: INDEX; Schema: bz; Owner: postgres
--

CREATE INDEX fki_sensor_fkey ON bz.basins_stations USING btree (sensor_type);


--
-- Name: fki_station_id; Type: INDEX; Schema: bz; Owner: postgres
--

CREATE INDEX fki_station_id ON bz.basins_stations USING btree (station_id);


--
-- Name: fki_station_id_fkey; Type: INDEX; Schema: bz; Owner: postgres
--

CREATE INDEX fki_station_id_fkey ON bz.basins_stations USING btree (station_id);


--
-- Name: fki_station_scode_fkey; Type: INDEX; Schema: bz; Owner: postgres
--

CREATE INDEX fki_station_scode_fkey ON bz.basins_stations USING btree (station_scode);


--
-- Name: fki_type_fk; Type: INDEX; Schema: bz; Owner: postgres
--

CREATE INDEX fki_type_fk ON bz.time_series USING btree (type);


--
-- Name: stations_geom_gist; Type: INDEX; Schema: bz; Owner: postgres
--

CREATE INDEX stations_geom_gist ON bz.stations USING gist (geom);


--
-- Name: time_series_recorded_on_btree; Type: INDEX; Schema: bz; Owner: postgres
--

CREATE INDEX time_series_recorded_on_btree ON bz.time_series USING btree (recorded_on);


--
-- Name: time_series_scode_btree; Type: INDEX; Schema: bz; Owner: postgres
--

CREATE INDEX time_series_scode_btree ON bz.time_series USING btree (scode);


--
-- Name: time_series_type_btree; Type: INDEX; Schema: bz; Owner: postgres
--

CREATE INDEX time_series_type_btree ON bz.time_series USING btree (type);


--
-- Name: fki_fk_username; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_fk_username ON public.authorities USING btree (username);


--
-- Name: basins_stations basin_subbasin_fkey; Type: FK CONSTRAINT; Schema: bz; Owner: postgres
--

ALTER TABLE ONLY bz.basins_stations
    ADD CONSTRAINT basin_subbasin_fkey FOREIGN KEY (basin_id, subbasin_id) REFERENCES basins.basins(id, sub_id) NOT VALID;


--
-- Name: basins_stations sensor_fkey; Type: FK CONSTRAINT; Schema: bz; Owner: postgres
--

ALTER TABLE ONLY bz.basins_stations
    ADD CONSTRAINT sensor_fkey FOREIGN KEY (sensor_type) REFERENCES bz.sensors(type) NOT VALID;


--
-- Name: basins_stations station_id_fkey; Type: FK CONSTRAINT; Schema: bz; Owner: postgres
--

ALTER TABLE ONLY bz.basins_stations
    ADD CONSTRAINT station_id_fkey FOREIGN KEY (station_id) REFERENCES bz.stations(id_hist) NOT VALID;


--
-- Name: basins_stations station_scode_fkey; Type: FK CONSTRAINT; Schema: bz; Owner: postgres
--

ALTER TABLE ONLY bz.basins_stations
    ADD CONSTRAINT station_scode_fkey FOREIGN KEY (station_scode) REFERENCES bz.stations(scode) NOT VALID;


--
-- Name: time_series type_fk; Type: FK CONSTRAINT; Schema: bz; Owner: postgres
--

ALTER TABLE ONLY bz.time_series
    ADD CONSTRAINT type_fk FOREIGN KEY (type) REFERENCES bz.sensors(type) NOT VALID;


--
-- Name: authorities fk_username; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.authorities
    ADD CONSTRAINT fk_username FOREIGN KEY (username) REFERENCES public.users(username) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

