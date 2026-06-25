CREATE SCHEMA app;

-- CREATE SEQUENCE IF NOT EXISTS app.customer_id_seq
-- 	INCREMENT BY 1
-- 	MINVALUE 1
-- 	MAXVALUE 9223372036854775807
-- 	START 1;

-- DROP TABLE app.customer;

CREATE TABLE IF NOT EXISTS app.customer (
	-- id integer NOT NULL DEFAULT nextval('app.customer_id_seq'),
	id integer NOT NULL,
	last_name varchar(100) NULL,
	first_name varchar(100) NULL,
	city varchar(100) NULL,
    active bool DEFAULT 't',
    category integer DEFAULT 1,
    hashtag bytea,
	gender varchar,
	country varchar(100),
	description text,
	created timestamp NULL,
    inserted timestamp NULL DEFAULT now(),
    lastUpdate timestamp NULL,
	CONSTRAINT customer_pkey PRIMARY KEY (id)
);
INSERT INTO app.customer (id, last_name, first_name, city, active, category, hashtag, gender, country, description, created, inserted, lastUpdate) VALUES
(1, 'Smith', 'John', 'New York', true, 1, '\\x6861736868617368', 'M', 'USA', 'A regular customer.', '2024-01-01 10:00:00', now(), '2024-01-01 10:00:00'),
(2, 'Doe', 'Jane', 'Los Angeles', false, 2, '\\x6861736868617368', 'F', 'USA', 'An inactive customer.', '2024-02-01 11:00:00', now(), '2024-02-01 11:00:00'),
(3, 'Brown', 'Charlie', 'Chicago', true, 1, '\\x6861736868617368', 'M', 'USA', 'A loyal customer.', '2024-03-01 12:00:00', now(), '2024-03-01 12:00:00');


CREATE TABLE IF NOT EXISTS app.personne (
  id int NOT NULL,
  LastName varchar(255) DEFAULT NULL,
  FirstName varchar(255) DEFAULT NULL,
  DOB date DEFAULT NULL,
  Sex varchar(10) DEFAULT NULL,
  PRIMARY KEY (id)
);

insert into app.personne values (1,'Hendrix','Jimi','1942-11-27','M');
insert into app.personne values (2,'Verdurin','Olivia','1954-09-15','F');

INSERT INTO app.personne (id, LastName, FirstName, DOB, Sex) VALUES
(3, 'Smith', 'John', '1980-01-01', 'M'),
(4, 'Doe', 'Jane', '1990-02-01', 'F'),
(5, 'Brown', 'Charlie', '1975-03-01', 'M');


CREATE TABLE IF NOT EXISTS app.patient (
    -- Logical identifier
    id varchar(64) NOT NULL,
    -- Identifiers
    identifier_system varchar(255),
    identifier_value varchar(255),
    identifier_use varchar(50),                -- usual | official | temp | secondary | old
    -- Active status
    active bool DEFAULT true,
    -- Name
    name_use varchar(50),                      -- usual | official | temp | nickname | anonymous | old | maiden
    name_family varchar(255),
    name_given varchar(255),
    name_prefix varchar(100),
    name_suffix varchar(100),
    name_text varchar(255),
    -- Telecom
    telecom_system varchar(50),                -- phone | fax | email | pager | url | sms | other
    telecom_value varchar(255),
    telecom_use varchar(50),                   -- home | work | temp | old | mobile
    telecom_rank integer,
    -- Gender
    gender varchar(10),                        -- male | female | other | unknown
    -- Birth Date
    birth_date date,
    -- Deceased
    deceased_boolean bool DEFAULT false,
    deceased_date_time timestamp,
    -- Address
    address_use varchar(50),                   -- home | work | temp | old | billing
    address_type varchar(50),                  -- postal | physical | both
    address_text varchar(255),
    address_line varchar(255),
    address_city varchar(100),
    address_district varchar(100),
    address_state varchar(100),
    address_postal_code varchar(20),
    address_country varchar(100),
    address_period_start timestamp,
    address_period_end timestamp,
    -- Marital Status
    marital_status_system varchar(255),
    marital_status_code varchar(50),           -- A | D | I | L | M | P | S | T | U | W | UNK
    marital_status_display varchar(100),
    -- Multiple Birth
    multiple_birth_boolean bool DEFAULT false,
    multiple_birth_integer integer,
    -- Photo
    photo_content_type varchar(100),
    photo_url varchar(255),
    photo_title varchar(255),
    -- Contact (next of kin / emergency contact)
    contact_relationship_system varchar(255),
    contact_relationship_code varchar(50),
    contact_relationship_display varchar(100),
    contact_name_family varchar(255),
    contact_name_given varchar(255),
    contact_telecom_system varchar(50),
    contact_telecom_value varchar(255),
    contact_address_line varchar(255),
    contact_address_city varchar(100),
    contact_address_country varchar(100),
    contact_gender varchar(10),
    contact_organization_reference varchar(64),
    contact_period_start timestamp,
    contact_period_end timestamp,
    -- Communication
    communication_language_system varchar(255),
    communication_language_code varchar(50),   -- BCP-47 language code e.g. en, fr, ja
    communication_language_display varchar(100),
    communication_preferred bool DEFAULT false,
    -- General Practitioner
    general_practitioner_reference varchar(64),
    general_practitioner_display varchar(255),
    -- Managing Organization
    managing_organization_reference varchar(64),
    managing_organization_display varchar(255),
    -- Link to other patient records
    link_other_reference varchar(64),
    link_type varchar(50),                     -- replaced-by | replaces | refer | seealso
    -- Metadata
    inserted timestamp DEFAULT now(),
    last_update timestamp,
    CONSTRAINT patient_pkey PRIMARY KEY (id)
);

INSERT INTO app.patient (
    id, active,
    identifier_system, identifier_value, identifier_use,
    name_use, name_family, name_given, name_text,
    telecom_system, telecom_value, telecom_use,
    gender, birth_date,
    address_use, address_line, address_city, address_postal_code, address_country,
    marital_status_code, marital_status_display,
    communication_language_code, communication_preferred,
    general_practitioner_display,
    managing_organization_display
) VALUES
('1', true, 'http://example.org/ids', 'P-001', 'official', 'official', 'Dupont', 'Marie', 'Marie Dupont', 'phone', '+33-1-23-45-67-89', 'home', 'female', '1985-06-15', 'home', '10 Rue de Rivoli', 'Paris', '75001', 'France', 'M', 'Married', 'fr', true, 'Dr. Leclerc', 'Hôpital de Paris'),
('2', true, 'http://example.org/ids', 'P-002', 'official', 'official', 'Yamamoto', 'Kenji', 'Kenji Yamamoto', 'phone', '+81-3-1234-5678', 'home', 'male', '1978-09-22', 'home', '1-1 Shinjuku', 'Tokyo', '160-0022', 'Japan', 'S', 'Single', 'ja', true, 'Dr. Tanaka', 'Tokyo General Hospital'),
('3', true, 'http://example.org/ids', 'P-003', 'official', 'official', 'Okafor', 'Amina', 'Amina Okafor', 'email', 'amina.okafor@email.com', 'home', 'female', '1992-03-10', 'home', '45 Victoria Island', 'Lagos', '101001', 'Nigeria', 'S', 'Single', 'en', true, 'Dr. Adeyemi', 'Lagos University Teaching Hospital');



CREATE TABLE IF NOT EXISTS app.medication_request (
    id varchar(64) NOT NULL,
    -- Identifiers
    identifier_system varchar(255),
    identifier_value varchar(255),
    -- Status & Intent
    status varchar(50) NOT NULL,               -- active | on-hold | cancelled | completed | entered-in-error | stopped | draft | unknown
    status_reason varchar(255),
    intent varchar(50) NOT NULL,               -- proposal | plan | order | original-order | reflex-order | filler-order | instance-order | option
    -- Category
    category varchar(100),                     -- inpatient | outpatient | community | discharge
    -- Priority
    priority varchar(50),                      -- routine | urgent | asap | stat
    -- Do Not Perform
    do_not_perform bool DEFAULT false,
    -- Medication
    medication_concept_system varchar(255),    -- e.g. http://www.nlm.nih.gov/research/umls/rxnorm
    medication_concept_code varchar(100),
    medication_concept_display varchar(255),
    -- Subject (Patient)
    subject_reference varchar(64),            -- reference to patient id
    subject_display varchar(255),
    -- Encounter
    encounter_reference varchar(64),
    -- Dates
    effective_date_time timestamp,
    effective_period_start timestamp,
    effective_period_end timestamp,
    authored_on timestamp,
    -- Requester
    requester_reference varchar(64),
    requester_display varchar(255),
    -- Recorder
    recorder_reference varchar(64),
    recorder_display varchar(255),
    -- Reason
    reason_concept_system varchar(255),
    reason_concept_code varchar(100),
    reason_concept_display varchar(255),
    reason_reference varchar(64),
    -- Course of Therapy
    course_of_therapy_type varchar(100),       -- continuous | acute | seasonal
    -- Dosage instructions
    dosage_text varchar(1024),
    dosage_timing_code varchar(100),           -- e.g. BID, TID, QID
    dosage_route_system varchar(255),
    dosage_route_code varchar(100),
    dosage_route_display varchar(255),
    dosage_dose_value numeric(10,3),
    dosage_dose_unit varchar(50),
    dosage_max_dose_per_period_numerator_value numeric(10,3),
    dosage_max_dose_per_period_numerator_unit varchar(50),
    -- Dispense Request
    dispense_initial_fill_quantity_value numeric(10,3),
    dispense_initial_fill_quantity_unit varchar(50),
    dispense_initial_fill_duration_value numeric(10,3),
    dispense_initial_fill_duration_unit varchar(50),
    dispense_dispense_interval_value numeric(10,3),
    dispense_dispense_interval_unit varchar(50),
    dispense_validity_period_start timestamp,
    dispense_validity_period_end timestamp,
    dispense_number_of_repeats_allowed integer,
    dispense_quantity_value numeric(10,3),
    dispense_quantity_unit varchar(50),
    dispense_expected_supply_duration_value numeric(10,3),
    dispense_expected_supply_duration_unit varchar(50),
    -- Substitution
    substitution_allowed bool DEFAULT true,
    substitution_reason varchar(255),
    -- Metadata
    inserted timestamp DEFAULT now(),
    last_update timestamp,
    CONSTRAINT medication_request_pkey PRIMARY KEY (id)
);

INSERT INTO app.medication_request (
    id, status, intent,
    medication_concept_system, medication_concept_code, medication_concept_display,
    subject_reference, subject_display,
    authored_on,
    requester_display,
    dosage_text, dosage_route_display,
    dosage_dose_value, dosage_dose_unit,
    dispense_quantity_value, dispense_quantity_unit,
    dispense_number_of_repeats_allowed
) VALUES
('mreq-001', 'active', 'order', 'http://www.nlm.nih.gov/research/umls/rxnorm', '1049502', 'Amoxicillin 500mg', '1', 'Dupont Marie', '2024-01-15 09:00:00', 'Dr. House', 'Take 1 capsule three times daily', 'Oral', 500, 'mg', 21, 'capsule', 0),
('mreq-002', 'active', 'order', 'http://www.nlm.nih.gov/research/umls/rxnorm', '313782', 'Acetaminophen 325mg', '2', 'Yamamoto Kenji', '2024-02-20 10:30:00', 'Dr. Strange', 'Take 2 tablets every 6 hours as needed', 'Oral', 650, 'mg', 30, 'tablet', 2),
('mreq-003', 'completed', 'order', 'http://www.nlm.nih.gov/research/umls/rxnorm', '429503', 'Ibuprofen 200mg', '3', 'Okafor Amina', '2024-03-05 14:00:00', 'Dr. Who', 'Take 1 tablet twice daily with food', 'Oral', 200, 'mg', 14, 'tablet', 1),
('mreq-004', 'active', 'order', 'http://www.nlm.nih.gov/research/umls/rxnorm', '308460', 'Lisinopril 10mg', '1', 'Dupont Marie', '2024-03-01 08:00:00', 'Dr. Leclerc', 'Take 1 tablet once daily', 'Oral', 10, 'mg', 30, 'tablet', 3),
('mreq-005', 'on-hold', 'order', 'http://www.nlm.nih.gov/research/umls/rxnorm', '310798', 'Metformin 500mg', '1', 'Dupont Marie', '2024-03-10 09:30:00', 'Dr. Leclerc', 'Take 1 tablet twice daily with meals', 'Oral', 500, 'mg', 60, 'tablet', 5),
('mreq-006', 'active', 'order', 'http://www.nlm.nih.gov/research/umls/rxnorm', '197361', 'Atorvastatin 20mg', '2', 'Yamamoto Kenji', '2024-03-12 11:00:00', 'Dr. Tanaka', 'Take 1 tablet once daily at bedtime', 'Oral', 20, 'mg', 30, 'tablet', 6),
('mreq-007', 'completed', 'order', 'http://www.nlm.nih.gov/research/umls/rxnorm', '309362', 'Cetirizine 10mg', '2', 'Yamamoto Kenji', '2024-02-01 14:00:00', 'Dr. Tanaka', 'Take 1 tablet once daily', 'Oral', 10, 'mg', 14, 'tablet', 0),
('mreq-008', 'active', 'order', 'http://www.nlm.nih.gov/research/umls/rxnorm', '308049', 'Azithromycin 250mg', '3', 'Okafor Amina', '2024-04-01 10:00:00', 'Dr. Adeyemi', 'Take 2 tablets on day 1, then 1 tablet daily for 4 days', 'Oral', 250, 'mg', 6, 'tablet', 0),
('mreq-009', 'active', 'order', 'http://www.nlm.nih.gov/research/umls/rxnorm', '310429', 'Omeprazole 20mg', '3', 'Okafor Amina', '2024-04-05 09:00:00', 'Dr. Adeyemi', 'Take 1 capsule once daily before breakfast', 'Oral', 20, 'mg', 30, 'capsule', 2);
