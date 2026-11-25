-- =====================================================================
--  BLOOD NETWORK - DBMS course project
--  File 1 of 3: schema, constraints, indexes, function, triggers,
--               stored procedures, views, scheduled event.
--
--  Run order:  01_schema.sql  ->  02_seed.sql  ->  03_queries.sql
--  Target:     MySQL 8.0.16+ (CHECK constraints are enforced from 8.0.16).
--              Also tested on MariaDB 10.11.
--  CLI tip:    mysql -u root -p < 01_schema.sql
--              (GUI tools may need the DELIMITER lines handled by their own
--               "run script" feature.)
--
--  WARNING: the next line drops the database so the script can be re-run.
-- =====================================================================
DROP DATABASE IF EXISTS blood_network;
CREATE DATABASE blood_network CHARACTER SET utf8mb4;
USE blood_network;

-- ---------------------------------------------------------------------
--  1. REFERENCE / LOOKUP TABLES
--     Rules live in tables, not in application code, so they can be
--     queried, joined and changed without redeploying anything.
-- ---------------------------------------------------------------------
CREATE TABLE State (
    state_id   INT PRIMARY KEY AUTO_INCREMENT,
    name       VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE District (
    district_id INT PRIMARY KEY AUTO_INCREMENT,
    state_id    INT NOT NULL,
    name        VARCHAR(60) NOT NULL,
    latitude    DECIMAL(9,6) NOT NULL,   -- district centre: used when a user denies GPS
    longitude   DECIMAL(9,6) NOT NULL,
    UNIQUE (state_id, name),
    FOREIGN KEY (state_id) REFERENCES State(state_id),
    CHECK (latitude  BETWEEN -90  AND 90),
    CHECK (longitude BETWEEN -180 AND 180)
);

CREATE TABLE Blood_Group (
    group_code VARCHAR(3) PRIMARY KEY,   -- 'A+', 'O-', ...
    abo        VARCHAR(2) NOT NULL,
    rh         CHAR(1)    NOT NULL,
    CHECK (group_code IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
    CHECK (rh IN ('+','-'))
);

-- Which donor group can give red cells to which recipient group.
-- (Plasma follows different rules and is out of scope for this project.)
CREATE TABLE Compatibility (
    donor_group     VARCHAR(3) NOT NULL,
    recipient_group VARCHAR(3) NOT NULL,
    PRIMARY KEY (donor_group, recipient_group),
    FOREIGN KEY (donor_group)     REFERENCES Blood_Group(group_code),
    FOREIGN KEY (recipient_group) REFERENCES Blood_Group(group_code)
);

-- Shelf life differs by component, so expiry is derived from this table.
-- NOTE: verify these day-counts against your blood bank / NBTC guidelines
-- before quoting them in the report.
CREATE TABLE Component (
    component_id    INT PRIMARY KEY AUTO_INCREMENT,
    name            VARCHAR(40) NOT NULL UNIQUE,
    shelf_life_days INT NOT NULL,
    CHECK (shelf_life_days > 0)
);

-- Minimum gap between two donations, by gender.
-- NOTE: placeholder values (90 / 120 days). Confirm against NBTC criteria.
CREATE TABLE Cooldown_Rule (
    gender        VARCHAR(10) PRIMARY KEY,
    min_gap_days  INT NOT NULL,
    CHECK (gender IN ('Male','Female','Other')),
    CHECK (min_gap_days > 0)
);

-- Recognition tiers (certificates / badges). Tiers NEVER affect who receives blood.
CREATE TABLE Tier (
    tier_name         VARCHAR(20) PRIMARY KEY,
    min_donations     INT NOT NULL UNIQUE,
    CHECK (min_donations >= 0)
);

-- ---------------------------------------------------------------------
--  2. CORE ENTITIES
-- ---------------------------------------------------------------------
CREATE TABLE Organization (
    org_id        INT PRIMARY KEY AUTO_INCREMENT,
    name          VARCHAR(120) NOT NULL,
    org_type      VARCHAR(12)  NOT NULL,              -- Blood Bank | Hospital
    ownership     VARCHAR(12)  NOT NULL,              -- Govt | Charitable | Private
    district_id   INT NOT NULL,
    address       VARCHAR(255),
    phone         VARCHAR(15),
    email         VARCHAR(120),
    latitude      DECIMAL(9,6) NOT NULL,
    longitude     DECIMAL(9,6) NOT NULL,
    status        VARCHAR(10)  NOT NULL DEFAULT 'Pending',   -- admin approval workflow
    registered_on DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (name, district_id),
    FOREIGN KEY (district_id) REFERENCES District(district_id),
    CHECK (org_type  IN ('Blood Bank','Hospital')),
    CHECK (ownership IN ('Govt','Charitable','Private')),
    CHECK (status    IN ('Pending','Approved','Rejected')),
    CHECK (latitude  BETWEEN -90  AND 90),
    CHECK (longitude BETWEEN -180 AND 180)
);

CREATE TABLE Donor (
    donor_id           INT PRIMARY KEY AUTO_INCREMENT,
    name               VARCHAR(100) NOT NULL,
    dob                DATE         NOT NULL,           -- age is derived, never stored
    gender             VARCHAR(10)  NOT NULL,
    blood_group        VARCHAR(3)   NOT NULL,
    phone              VARCHAR(10)  NOT NULL UNIQUE,    -- Indian 10-digit mobile
    phone_verified     BOOLEAN      NOT NULL DEFAULT FALSE,
    district_id        INT          NOT NULL,
    latitude           DECIMAL(9,6) NOT NULL,
    longitude          DECIMAL(9,6) NOT NULL,
    last_donation_date DATE NULL,                       -- maintained by trigger
    next_eligible_date DATE NULL,                       -- maintained by trigger / eligibility check
    status             VARCHAR(10)  NOT NULL DEFAULT 'Active',
    registered_on      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (blood_group) REFERENCES Blood_Group(group_code),
    FOREIGN KEY (district_id) REFERENCES District(district_id),
    FOREIGN KEY (gender)      REFERENCES Cooldown_Rule(gender),
    CHECK (phone REGEXP '^[6-9][0-9]{9}$'),
    CHECK (status IN ('Active','Inactive','Ineligible')),
    CHECK (latitude  BETWEEN -90  AND 90),
    CHECK (longitude BETWEEN -180 AND 180)
);

CREATE TABLE Camp (
    camp_id          INT PRIMARY KEY AUTO_INCREMENT,
    title            VARCHAR(150) NOT NULL,
    conducted_by_org INT NOT NULL,                       -- the blood bank running it
    organised_by     VARCHAR(100),                       -- society / company / college
    district_id      INT NOT NULL,
    venue            VARCHAR(255) NOT NULL,
    camp_date        DATE NOT NULL,
    start_time       TIME NOT NULL,
    end_time         TIME NOT NULL,
    contact_phone    VARCHAR(15),
    capacity         INT NOT NULL,                       -- donor slots
    status           VARCHAR(10) NOT NULL DEFAULT 'Pending',
    FOREIGN KEY (conducted_by_org) REFERENCES Organization(org_id),
    FOREIGN KEY (district_id)      REFERENCES District(district_id),
    CHECK (end_time > start_time),
    CHECK (capacity > 0),
    CHECK (status IN ('Pending','Approved','Cancelled','Completed'))
);

CREATE TABLE Camp_Booking (
    booking_id INT PRIMARY KEY AUTO_INCREMENT,
    camp_id    INT NOT NULL,
    donor_id   INT NOT NULL,
    booked_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status     VARCHAR(10) NOT NULL DEFAULT 'Booked',
    UNIQUE (camp_id, donor_id),                          -- a donor books a camp once
    FOREIGN KEY (camp_id)  REFERENCES Camp(camp_id)   ON DELETE CASCADE,
    FOREIGN KEY (donor_id) REFERENCES Donor(donor_id),
    CHECK (status IN ('Booked','Attended','No-show','Cancelled'))
);

CREATE TABLE Blood_Request (
    request_id        INT PRIMARY KEY AUTO_INCREMENT,
    requester_name    VARCHAR(100) NOT NULL,
    requester_phone   VARCHAR(10)  NOT NULL,
    patient_blood_grp VARCHAR(3)   NOT NULL,
    units_needed      INT          NOT NULL,
    hospital_org_id   INT          NOT NULL,             -- district comes from the hospital
    urgency           VARCHAR(10)  NOT NULL DEFAULT 'Urgent',
    status            VARCHAR(10)  NOT NULL DEFAULT 'Open',
    created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at        DATETIME     NOT NULL,
    FOREIGN KEY (patient_blood_grp) REFERENCES Blood_Group(group_code),
    FOREIGN KEY (hospital_org_id)   REFERENCES Organization(org_id),
    CHECK (requester_phone REGEXP '^[6-9][0-9]{9}$'),
    CHECK (units_needed BETWEEN 1 AND 10),
    CHECK (urgency IN ('Critical','Urgent','Planned')),
    CHECK (status  IN ('Open','Matched','Expired','Cancelled')),
    CHECK (expires_at > created_at)
);

-- One row per donor we ask for one request. Phone numbers are shown to the
-- requester only for rows with status = 'Accepted' (see view v_accepted_contacts).
CREATE TABLE Request_Contact (
    contact_id   INT PRIMARY KEY AUTO_INCREMENT,
    request_id   INT NOT NULL,
    donor_id     INT NOT NULL,
    radius_km    INT NOT NULL,                           -- search radius at which they were reached
    contacted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status       VARCHAR(12) NOT NULL DEFAULT 'Sent',
    responded_at DATETIME NULL,
    UNIQUE (request_id, donor_id),                       -- never spam the same donor twice
    FOREIGN KEY (request_id) REFERENCES Blood_Request(request_id) ON DELETE CASCADE,
    FOREIGN KEY (donor_id)   REFERENCES Donor(donor_id),
    CHECK (radius_km > 0),
    CHECK (status IN ('Sent','Accepted','Declined','No Response'))
);

CREATE TABLE Donation (
    donation_id   INT PRIMARY KEY AUTO_INCREMENT,
    donor_id      INT NOT NULL,
    org_id        INT NOT NULL,                          -- where blood was collected
    camp_id       INT NULL,
    request_id    INT NULL,                              -- set if donated for a specific request
    donation_date DATE NOT NULL,
    volume_ml     INT  NOT NULL,
    FOREIGN KEY (donor_id)   REFERENCES Donor(donor_id),
    FOREIGN KEY (org_id)     REFERENCES Organization(org_id),
    FOREIGN KEY (camp_id)    REFERENCES Camp(camp_id),
    FOREIGN KEY (request_id) REFERENCES Blood_Request(request_id),
    CHECK (volume_ml BETWEEN 100 AND 500)
);

CREATE TABLE Blood_Unit (
    unit_id      INT PRIMARY KEY AUTO_INCREMENT,
    org_id       INT NOT NULL,
    blood_group  VARCHAR(3) NOT NULL,
    component_id INT NOT NULL,
    volume_ml    INT NOT NULL,
    collected_on DATE NOT NULL,
    expires_on   DATE NULL,                              -- filled by trigger from Component
    status       VARCHAR(10) NOT NULL DEFAULT 'Available',
    donation_id  INT NULL,                               -- NULL = opening stock
    FOREIGN KEY (org_id)       REFERENCES Organization(org_id),
    FOREIGN KEY (blood_group)  REFERENCES Blood_Group(group_code),
    FOREIGN KEY (component_id) REFERENCES Component(component_id),
    FOREIGN KEY (donation_id)  REFERENCES Donation(donation_id),
    CHECK (volume_ml > 0),
    CHECK (status IN ('Available','Reserved','Issued','Expired'))
);

-- ---------------------------------------------------------------------
--  3. ELIGIBILITY SELF-CHECK (questions + rules stored as data)
-- ---------------------------------------------------------------------
-- NOTE: the questions below are a generic starting set. Check them against
-- the official NBTC donor-selection criteria before relying on them.
CREATE TABLE Eligibility_Question (
    question_id         INT PRIMARY KEY AUTO_INCREMENT,
    question_text       VARCHAR(255) NOT NULL,
    disqualifying_answer VARCHAR(3)  NOT NULL DEFAULT 'Yes',
    outcome             VARCHAR(10)  NOT NULL,           -- Deferred | Ineligible
    deferral_days       INT NULL,                        -- only for Deferred
    CHECK (disqualifying_answer IN ('Yes','No')),
    CHECK (outcome IN ('Deferred','Ineligible')),
    CHECK ((outcome = 'Deferred' AND deferral_days > 0)
        OR (outcome = 'Ineligible' AND deferral_days IS NULL))
);

CREATE TABLE Eligibility_Check (
    check_id       INT PRIMARY KEY AUTO_INCREMENT,
    donor_id       INT NOT NULL,
    checked_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    result         VARCHAR(10) NULL,                     -- set by sp_evaluate_eligibility
    deferred_until DATE NULL,
    FOREIGN KEY (donor_id) REFERENCES Donor(donor_id),
    CHECK (result IN ('Eligible','Deferred','Ineligible'))
);

CREATE TABLE Eligibility_Answer (
    check_id    INT NOT NULL,
    question_id INT NOT NULL,
    answer      VARCHAR(3) NOT NULL,
    PRIMARY KEY (check_id, question_id),
    FOREIGN KEY (check_id)    REFERENCES Eligibility_Check(check_id) ON DELETE CASCADE,
    FOREIGN KEY (question_id) REFERENCES Eligibility_Question(question_id),
    CHECK (answer IN ('Yes','No'))
);

-- ---------------------------------------------------------------------
--  4. REWARDS, OTP, AUDIT
-- ---------------------------------------------------------------------
-- Points are a LEDGER (append-only), not a counter you overwrite.
-- Totals are computed with SUM(), so they can never drift out of sync.
CREATE TABLE Reward_Event (
    event_id    INT PRIMARY KEY AUTO_INCREMENT,
    donor_id    INT NOT NULL,
    event_type  VARCHAR(12) NOT NULL,
    points      INT NOT NULL,
    donation_id INT NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (donor_id)    REFERENCES Donor(donor_id),
    FOREIGN KEY (donation_id) REFERENCES Donation(donation_id),
    CHECK (event_type IN ('Donation','Camp Bonus')),
    CHECK (points > 0)
);

-- Mock OTP. In a real deployment the code would be hashed and sent by SMS.
CREATE TABLE Otp_Log (
    otp_id     INT PRIMARY KEY AUTO_INCREMENT,
    phone      VARCHAR(10) NOT NULL,
    purpose    VARCHAR(20) NOT NULL,
    otp_code   CHAR(6)     NOT NULL,
    created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME    NOT NULL,
    used       BOOLEAN     NOT NULL DEFAULT FALSE,
    CHECK (purpose IN ('Donor Registration','Blood Request'))
);

CREATE TABLE Audit_Log (
    audit_id   INT PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(40) NOT NULL,
    record_id  INT NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
--  5. INDEXES (chosen for the two hot searches: nearby banks, nearby donors)
-- ---------------------------------------------------------------------
CREATE INDEX idx_org_search      ON Organization (district_id, status, org_type);
CREATE INDEX idx_donor_search    ON Donor (status, blood_group, next_eligible_date);
CREATE INDEX idx_donor_district  ON Donor (district_id);
CREATE INDEX idx_unit_stock      ON Blood_Unit (org_id, blood_group, status, expires_on);
CREATE INDEX idx_unit_expiry     ON Blood_Unit (status, expires_on);
CREATE INDEX idx_request_status  ON Blood_Request (status, expires_at);
CREATE INDEX idx_contact_request ON Request_Contact (request_id, status);
CREATE INDEX idx_camp_search     ON Camp (district_id, camp_date, status);
CREATE INDEX idx_donation_donor  ON Donation (donor_id, donation_date);
CREATE INDEX idx_reward_donor    ON Reward_Event (donor_id);
CREATE INDEX idx_otp_lookup      ON Otp_Log (phone, purpose, used);

-- ---------------------------------------------------------------------
--  6. FUNCTION: great-circle (haversine) distance in km
-- ---------------------------------------------------------------------
DELIMITER $$

CREATE FUNCTION fn_distance_km(lat1 DOUBLE, lon1 DOUBLE, lat2 DOUBLE, lon2 DOUBLE)
RETURNS DOUBLE
DETERMINISTIC
BEGIN
    RETURN 6371 * 2 * ASIN(SQRT(
        POW(SIN(RADIANS(lat2 - lat1) / 2), 2) +
        COS(RADIANS(lat1)) * COS(RADIANS(lat2)) *
        POW(SIN(RADIANS(lon2 - lon1) / 2), 2)));
END$$

-- ---------------------------------------------------------------------
--  7. TRIGGERS
-- ---------------------------------------------------------------------

-- 7.1 Donor must be 18-65 (CHECK cannot use CURDATE(), so a trigger does it)
CREATE TRIGGER trg_donor_bi BEFORE INSERT ON Donor
FOR EACH ROW
BEGIN
    DECLARE v_age INT;
    SET v_age = TIMESTAMPDIFF(YEAR, NEW.dob, CURDATE());
    IF v_age < 18 OR v_age > 65 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donor age must be between 18 and 65';
    END IF;
END$$

-- 7.2 Expiry date and status of a unit are derived, not typed in by hand
CREATE TRIGGER trg_unit_bi BEFORE INSERT ON Blood_Unit
FOR EACH ROW
BEGIN
    DECLARE v_shelf INT;
    IF NEW.expires_on IS NULL THEN
        SELECT shelf_life_days INTO v_shelf FROM Component WHERE component_id = NEW.component_id;
        SET NEW.expires_on = DATE_ADD(NEW.collected_on, INTERVAL v_shelf DAY);
    END IF;
    IF NEW.expires_on < CURDATE() THEN
        SET NEW.status = 'Expired';
    END IF;
END$$

-- 7.3 Block a donation that breaks the donor's cooldown
CREATE TRIGGER trg_donation_bi BEFORE INSERT ON Donation
FOR EACH ROW
BEGIN
    DECLARE v_last DATE;
    DECLARE v_gap  INT;
    DECLARE v_status VARCHAR(10);

    IF NEW.donation_date > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donation date cannot be in the future';
    END IF;

    SELECT d.last_donation_date, c.min_gap_days, d.status
      INTO v_last, v_gap, v_status
      FROM Donor d JOIN Cooldown_Rule c ON c.gender = d.gender
     WHERE d.donor_id = NEW.donor_id;

    IF v_status = 'Ineligible' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donor is marked ineligible';
    END IF;
    IF v_last IS NOT NULL AND NEW.donation_date < DATE_ADD(v_last, INTERVAL v_gap DAY) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donor is still inside the minimum gap between donations';
    END IF;
END$$

-- 7.4 After a donation: create the unit, move the donor's dates,
--     write reward ledger rows, mark the camp booking as attended
CREATE TRIGGER trg_donation_ai AFTER INSERT ON Donation
FOR EACH ROW
BEGIN
    DECLARE v_group VARCHAR(3);
    DECLARE v_gap   INT;
    DECLARE v_whole INT;

    SELECT d.blood_group, c.min_gap_days INTO v_group, v_gap
      FROM Donor d JOIN Cooldown_Rule c ON c.gender = d.gender
     WHERE d.donor_id = NEW.donor_id;
    SELECT component_id INTO v_whole FROM Component WHERE name = 'Whole Blood';

    INSERT INTO Blood_Unit (org_id, blood_group, component_id, volume_ml, collected_on, donation_id)
    VALUES (NEW.org_id, v_group, v_whole, NEW.volume_ml, NEW.donation_date, NEW.donation_id);

    UPDATE Donor
       SET last_donation_date = NEW.donation_date,
           next_eligible_date = DATE_ADD(NEW.donation_date, INTERVAL v_gap DAY)
     WHERE donor_id = NEW.donor_id;

    INSERT INTO Reward_Event (donor_id, event_type, points, donation_id)
    VALUES (NEW.donor_id, 'Donation', 10, NEW.donation_id);

    IF NEW.camp_id IS NOT NULL THEN
        INSERT INTO Reward_Event (donor_id, event_type, points, donation_id)
        VALUES (NEW.donor_id, 'Camp Bonus', 5, NEW.donation_id);
        UPDATE Camp_Booking SET status = 'Attended'
         WHERE camp_id = NEW.camp_id AND donor_id = NEW.donor_id;
    END IF;
END$$

-- 7.5 Audit trail for approval and request status changes
CREATE TRIGGER trg_org_au AFTER UPDATE ON Organization
FOR EACH ROW
BEGIN
    IF NOT (OLD.status <=> NEW.status) THEN
        INSERT INTO Audit_Log (table_name, record_id, old_status, new_status)
        VALUES ('Organization', NEW.org_id, OLD.status, NEW.status);
    END IF;
END$$

CREATE TRIGGER trg_request_au AFTER UPDATE ON Blood_Request
FOR EACH ROW
BEGIN
    IF NOT (OLD.status <=> NEW.status) THEN
        INSERT INTO Audit_Log (table_name, record_id, old_status, new_status)
        VALUES ('Blood_Request', NEW.request_id, OLD.status, NEW.status);
    END IF;
END$$

-- ---------------------------------------------------------------------
--  8. STORED PROCEDURES
-- ---------------------------------------------------------------------

-- 8.1 Mock OTP: generate a code (returned so you can "receive" it in the demo)
CREATE PROCEDURE sp_send_otp(IN p_phone VARCHAR(10), IN p_purpose VARCHAR(20), OUT p_code CHAR(6))
BEGIN
    UPDATE Otp_Log SET used = TRUE
     WHERE phone = p_phone AND purpose = p_purpose AND used = FALSE;

    SET p_code = LPAD(FLOOR(RAND() * 1000000), 6, '0');
    INSERT INTO Otp_Log (phone, purpose, otp_code, expires_at)
    VALUES (p_phone, p_purpose, p_code, DATE_ADD(NOW(), INTERVAL 10 MINUTE));
END$$

CREATE PROCEDURE sp_verify_otp(IN p_phone VARCHAR(10), IN p_purpose VARCHAR(20), IN p_code CHAR(6))
BEGIN
    DECLARE v_id INT DEFAULT NULL;
    SELECT otp_id INTO v_id FROM Otp_Log
     WHERE phone = p_phone AND purpose = p_purpose AND otp_code = p_code
       AND used = FALSE AND expires_at > NOW()
     ORDER BY otp_id DESC LIMIT 1;
    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid or expired OTP';
    END IF;
    UPDATE Otp_Log SET used = TRUE WHERE otp_id = v_id;
    IF p_purpose = 'Donor Registration' THEN
        UPDATE Donor SET phone_verified = TRUE WHERE phone = p_phone;
    END IF;
END$$

-- 8.2 Screen "nearby blood banks": compatible, unexpired stock within radius
CREATE PROCEDURE sp_find_banks(IN p_patient_group VARCHAR(3), IN p_lat DOUBLE, IN p_lng DOUBLE, IN p_radius_km INT)
BEGIN
    SELECT o.org_id, o.name, o.ownership, o.phone,
           ROUND(fn_distance_km(p_lat, p_lng, o.latitude, o.longitude), 1) AS distance_km,
           COUNT(u.unit_id) AS compatible_units
      FROM Organization o
      JOIN Blood_Unit u     ON u.org_id = o.org_id
                           AND u.status = 'Available' AND u.expires_on >= CURDATE()
      JOIN Compatibility c  ON c.donor_group = u.blood_group
                           AND c.recipient_group = p_patient_group
     WHERE o.status = 'Approved' AND o.org_type = 'Blood Bank'
     GROUP BY o.org_id, o.name, o.ownership, o.phone, o.latitude, o.longitude
    HAVING distance_km <= p_radius_km
     ORDER BY distance_km;
END$$

-- 8.3 Screen "search donors near you": no phone numbers are returned here
CREATE PROCEDURE sp_find_donors(IN p_patient_group VARCHAR(3), IN p_lat DOUBLE, IN p_lng DOUBLE, IN p_radius_km INT)
BEGIN
    SELECT d.donor_id,
           SUBSTRING_INDEX(d.name, ' ', 1) AS first_name,
           d.blood_group,
           ROUND(fn_distance_km(p_lat, p_lng, d.latitude, d.longitude), 1) AS distance_km
      FROM Donor d
      JOIN Compatibility c ON c.donor_group = d.blood_group
                          AND c.recipient_group = p_patient_group
     WHERE d.status = 'Active'
       AND d.phone_verified = TRUE
       AND (d.next_eligible_date IS NULL OR d.next_eligible_date <= CURDATE())
       AND fn_distance_km(p_lat, p_lng, d.latitude, d.longitude) <= p_radius_km
     ORDER BY distance_km;
END$$

-- 8.4 Create a request (requester must have passed OTP in the last 15 minutes)
CREATE PROCEDURE sp_create_request(
    IN p_name VARCHAR(100), IN p_phone VARCHAR(10), IN p_group VARCHAR(3),
    IN p_units INT, IN p_hospital INT, IN p_urgency VARCHAR(10), IN p_valid_hours INT,
    OUT p_request_id INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Otp_Log
                    WHERE phone = p_phone AND purpose = 'Blood Request' AND used = TRUE
                      AND created_at > DATE_SUB(NOW(), INTERVAL 15 MINUTE)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Verify your mobile number with OTP first';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Organization WHERE org_id = p_hospital AND status = 'Approved') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hospital not found or not approved';
    END IF;
    INSERT INTO Blood_Request (requester_name, requester_phone, patient_blood_grp, units_needed,
                               hospital_org_id, urgency, expires_at)
    VALUES (p_name, p_phone, p_group, p_units, p_hospital, p_urgency,
            DATE_ADD(NOW(), INTERVAL p_valid_hours HOUR));
    SET p_request_id = LAST_INSERT_ID();
END$$

-- 8.5 Ask every eligible, compatible donor inside the radius (skips anyone already asked)
CREATE PROCEDURE sp_notify_donors(IN p_request_id INT, IN p_radius_km INT)
BEGIN
    DECLARE v_group VARCHAR(3) DEFAULT NULL;
    DECLARE v_lat DECIMAL(9,6);
    DECLARE v_lng DECIMAL(9,6);

    SELECT r.patient_blood_grp, o.latitude, o.longitude INTO v_group, v_lat, v_lng
      FROM Blood_Request r JOIN Organization o ON o.org_id = r.hospital_org_id
     WHERE r.request_id = p_request_id AND r.status = 'Open';
    IF v_group IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request not found or not open';
    END IF;

    INSERT INTO Request_Contact (request_id, donor_id, radius_km)
    SELECT p_request_id, d.donor_id, p_radius_km
      FROM Donor d
      JOIN Compatibility c ON c.donor_group = d.blood_group AND c.recipient_group = v_group
     WHERE d.status = 'Active' AND d.phone_verified = TRUE
       AND (d.next_eligible_date IS NULL OR d.next_eligible_date <= CURDATE())
       AND fn_distance_km(v_lat, v_lng, d.latitude, d.longitude) <= p_radius_km
       AND NOT EXISTS (SELECT 1 FROM Request_Contact rc
                        WHERE rc.request_id = p_request_id AND rc.donor_id = d.donor_id);
END$$

-- 8.6 Keep widening the radius (25 -> 50 -> 100 km) until enough donors have been asked
CREATE PROCEDURE sp_expand_search(IN p_request_id INT, IN p_min_contacts INT)
BEGIN
    DECLARE v_radius INT DEFAULT 25;
    DECLARE v_count  INT DEFAULT 0;
    WHILE v_radius <= 100 AND v_count < p_min_contacts DO
        CALL sp_notify_donors(p_request_id, v_radius);
        SELECT COUNT(*) INTO v_count FROM Request_Contact WHERE request_id = p_request_id;
        SET v_radius = v_radius * 2;
    END WHILE;
    SELECT v_count AS donors_contacted, v_radius DIV 2 AS radius_reached_km;
END$$

-- 8.7 Donor answers a request. Transaction + row locks so two answers
--     arriving together cannot both "complete" the same request.
CREATE PROCEDURE sp_respond_to_request(IN p_contact_id INT, IN p_response VARCHAR(10))
BEGIN
    DECLARE v_req INT DEFAULT NULL;
    DECLARE v_needed INT DEFAULT NULL;
    DECLARE v_accepted INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_response NOT IN ('Accepted','Declined') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Response must be Accepted or Declined';
    END IF;

    START TRANSACTION;
    SELECT request_id INTO v_req FROM Request_Contact
     WHERE contact_id = p_contact_id AND status = 'Sent' FOR UPDATE;
    IF v_req IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Contact not found or already answered';
    END IF;

    SELECT units_needed INTO v_needed FROM Blood_Request
     WHERE request_id = v_req AND status = 'Open' FOR UPDATE;
    IF v_needed IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request is no longer open';
    END IF;

    UPDATE Request_Contact SET status = p_response, responded_at = NOW()
     WHERE contact_id = p_contact_id;

    IF p_response = 'Accepted' THEN
        -- one accepted donor = one unit
        SELECT COUNT(*) INTO v_accepted FROM Request_Contact
         WHERE request_id = v_req AND status = 'Accepted';
        IF v_accepted >= v_needed THEN
            UPDATE Blood_Request SET status = 'Matched' WHERE request_id = v_req;
        END IF;
    END IF;
    COMMIT;
END$$

-- 8.8 Book a donor into a camp. Locks the camp row, so the last seat
--     cannot be sold twice even if two donors click at the same moment.
CREATE PROCEDURE sp_book_camp(IN p_camp_id INT, IN p_donor_id INT)
BEGIN
    DECLARE v_cap INT DEFAULT NULL;
    DECLARE v_date DATE;
    DECLARE v_status VARCHAR(10);
    DECLARE v_taken INT;
    DECLARE v_next DATE;
    DECLARE v_dstatus VARCHAR(10) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT capacity, camp_date, status INTO v_cap, v_date, v_status
      FROM Camp WHERE camp_id = p_camp_id FOR UPDATE;
    IF v_cap IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Camp not found';
    END IF;
    IF v_status <> 'Approved' OR v_date < CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Camp is not open for booking';
    END IF;

    SELECT status, next_eligible_date INTO v_dstatus, v_next FROM Donor WHERE donor_id = p_donor_id;
    IF v_dstatus IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donor not found';
    END IF;
    IF v_dstatus <> 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donor is not active';
    END IF;
    IF v_next IS NOT NULL AND v_next > v_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donor will not be eligible by the camp date';
    END IF;

    SELECT COUNT(*) INTO v_taken FROM Camp_Booking
     WHERE camp_id = p_camp_id AND status IN ('Booked','Attended');
    IF v_taken >= v_cap THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Camp is full';
    END IF;

    INSERT INTO Camp_Booking (camp_id, donor_id) VALUES (p_camp_id, p_donor_id);
    COMMIT;
END$$

-- 8.9 Score an eligibility self-check from its stored answers
CREATE PROCEDURE sp_evaluate_eligibility(IN p_check_id INT)
BEGIN
    DECLARE v_donor INT DEFAULT NULL;
    DECLARE v_inelig INT;
    DECLARE v_defer_days INT;
    DECLARE v_result VARCHAR(10);
    DECLARE v_until DATE DEFAULT NULL;

    SELECT donor_id INTO v_donor FROM Eligibility_Check WHERE check_id = p_check_id;
    IF v_donor IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Eligibility check not found';
    END IF;

    SELECT COUNT(*) INTO v_inelig
      FROM Eligibility_Answer a JOIN Eligibility_Question q ON q.question_id = a.question_id
     WHERE a.check_id = p_check_id AND a.answer = q.disqualifying_answer AND q.outcome = 'Ineligible';

    SELECT MAX(q.deferral_days) INTO v_defer_days
      FROM Eligibility_Answer a JOIN Eligibility_Question q ON q.question_id = a.question_id
     WHERE a.check_id = p_check_id AND a.answer = q.disqualifying_answer AND q.outcome = 'Deferred';

    IF v_inelig > 0 THEN
        SET v_result = 'Ineligible';
    ELSEIF v_defer_days IS NOT NULL THEN
        SET v_result = 'Deferred';
        SET v_until = DATE_ADD(CURDATE(), INTERVAL v_defer_days DAY);
    ELSE
        SET v_result = 'Eligible';
    END IF;

    UPDATE Eligibility_Check SET result = v_result, deferred_until = v_until WHERE check_id = p_check_id;

    IF v_result = 'Ineligible' THEN
        UPDATE Donor SET status = 'Ineligible' WHERE donor_id = v_donor;
    ELSEIF v_result = 'Deferred' THEN
        UPDATE Donor SET next_eligible_date = GREATEST(COALESCE(next_eligible_date, v_until), v_until)
         WHERE donor_id = v_donor;
    END IF;

    SELECT v_result AS result, v_until AS deferred_until;
END$$

-- 8.10 Housekeeping: expire old units/requests, close finished camps.
--      Called by the daily event below, and once by the seed script.
CREATE PROCEDURE sp_housekeeping()
BEGIN
    UPDATE Blood_Unit SET status = 'Expired'
     WHERE status = 'Available' AND expires_on < CURDATE();

    UPDATE Request_Contact rc JOIN Blood_Request r ON r.request_id = rc.request_id
       SET rc.status = 'No Response'
     WHERE rc.status = 'Sent' AND r.status = 'Open' AND r.expires_at < NOW();

    UPDATE Blood_Request SET status = 'Expired'
     WHERE status = 'Open' AND expires_at < NOW();

    UPDATE Camp SET status = 'Completed'
     WHERE status = 'Approved' AND camp_date < CURDATE();
END$$

-- ---------------------------------------------------------------------
--  9. SCHEDULED EVENT (needs:  SET GLOBAL event_scheduler = ON;)
-- ---------------------------------------------------------------------
CREATE EVENT ev_daily_housekeeping
ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY)
DO CALL sp_housekeeping()$$

DELIMITER ;

-- ---------------------------------------------------------------------
--  10. VIEWS
-- ---------------------------------------------------------------------

-- Home-screen counters
CREATE VIEW v_home_stats AS
SELECT (SELECT COUNT(*) FROM Donor WHERE status = 'Active')                              AS registered_donors,
       (SELECT COUNT(*) FROM Organization WHERE org_type = 'Blood Bank' AND status = 'Approved') AS blood_centres,
       (SELECT COUNT(*) FROM Camp WHERE status IN ('Approved','Completed'))               AS camps;

-- Available stock per bank and group
CREATE VIEW v_stock_by_bank_group AS
SELECT o.org_id, o.name AS bank, d.name AS district, u.blood_group,
       COUNT(*) AS units, SUM(u.volume_ml) AS total_ml, MIN(u.expires_on) AS earliest_expiry
  FROM Blood_Unit u
  JOIN Organization o ON o.org_id = u.org_id
  JOIN District d     ON d.district_id = o.district_id
 WHERE u.status = 'Available' AND u.expires_on >= CURDATE()
 GROUP BY o.org_id, o.name, d.name, u.blood_group;

-- Requests with hospital and district
CREATE VIEW v_open_requests AS
SELECT r.request_id, r.patient_blood_grp, r.units_needed, r.urgency, r.created_at, r.expires_at,
       o.name AS hospital, d.name AS district
  FROM Blood_Request r
  JOIN Organization o ON o.org_id = r.hospital_org_id
  JOIN District d     ON d.district_id = o.district_id
 WHERE r.status = 'Open';

-- The ONLY place a donor's phone is joined to a request, and only after they accepted
CREATE VIEW v_accepted_contacts AS
SELECT rc.request_id, d.donor_id, d.name AS donor_name, d.phone AS donor_phone, rc.responded_at
  FROM Request_Contact rc JOIN Donor d ON d.donor_id = rc.donor_id
 WHERE rc.status = 'Accepted';

-- Upcoming camps with seats left
CREATE VIEW v_upcoming_camps AS
SELECT c.camp_id, c.title, c.camp_date, c.start_time, c.end_time, c.venue, d.name AS district,
       o.name AS conducted_by, c.organised_by, c.capacity,
       c.capacity - COUNT(b.booking_id) AS seats_left
  FROM Camp c
  JOIN District d     ON d.district_id = c.district_id
  JOIN Organization o ON o.org_id = c.conducted_by_org
  LEFT JOIN Camp_Booking b ON b.camp_id = c.camp_id AND b.status IN ('Booked','Attended')
 WHERE c.status = 'Approved' AND c.camp_date >= CURDATE()
 GROUP BY c.camp_id, c.title, c.camp_date, c.start_time, c.end_time, c.venue, d.name,
          o.name, c.organised_by, c.capacity;

-- Donation count, points and tier per donor (recognition only)
CREATE VIEW v_donor_tiers AS
SELECT d.donor_id, d.name, d.blood_group,
       COUNT(DISTINCT dn.donation_id) AS donations,
       COALESCE((SELECT SUM(points) FROM Reward_Event re WHERE re.donor_id = d.donor_id), 0) AS points,
       (SELECT t.tier_name FROM Tier t
         WHERE t.min_donations <= COUNT(DISTINCT dn.donation_id)
         ORDER BY t.min_donations DESC LIMIT 1) AS tier
  FROM Donor d LEFT JOIN Donation dn ON dn.donor_id = d.donor_id
 GROUP BY d.donor_id, d.name, d.blood_group;
