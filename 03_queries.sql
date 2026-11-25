-- =====================================================================
--  BLOOD NETWORK - File 3 of 3: demo queries
--  Run AFTER 01_schema.sql and 02_seed.sql, one block at a time.
--  Sections:  A. the app screens   B. analytics queries
--             C. rules in action   D. concurrency demo   E. EXPLAIN demo
-- =====================================================================
USE blood_network;

-- =====================================================================
--  A. THE APP SCREENS (the flow: group -> location -> banks -> donors)
-- =====================================================================

-- A1. Home screen counters
SELECT * FROM v_home_stats;

-- A2. Who can give blood to a patient with a given group? (join on the lookup table)
SELECT c.donor_group AS can_donate_to_AplusPatient
  FROM Compatibility c WHERE c.recipient_group = 'A+' ORDER BY c.donor_group;

-- A3. Nearby blood banks with compatible, unexpired stock.
--     Patient is an A+ at Aravali City Hospital (org #9); search radius 25 km.
--     (If the user denies GPS, use the district centre instead: see A3b.)
CALL sp_find_banks('A+',
     (SELECT latitude  FROM Organization WHERE org_id = 9),
     (SELECT longitude FROM Organization WHERE org_id = 9), 25);

-- A3b. Same search when GPS is denied: fall back to the district centre
CALL sp_find_banks('A+',
     (SELECT latitude  FROM District WHERE name = 'Jaipur'),
     (SELECT longitude FROM District WHERE name = 'Jaipur'), 50);

-- A4. "Unable to travel to the banks?"  -> donors nearby (no phone numbers shown).
--     Only donors who are active, phone-verified, compatible and past their cooldown appear.
CALL sp_find_donors('A+',
     (SELECT latitude  FROM Organization WHERE org_id = 9),
     (SELECT longitude FROM Organization WHERE org_id = 9), 25);

-- A5. Rare group, no stock anywhere? The "dead end" check: AB- in Jaipur district
CALL sp_find_banks('AB-',
     (SELECT latitude FROM District WHERE name = 'Jaipur'),
     (SELECT longitude FROM District WHERE name = 'Jaipur'), 100);

-- A6. Camps near me: upcoming, with seats left
SELECT camp_id, title, camp_date, venue, conducted_by, seats_left
  FROM v_upcoming_camps WHERE district = 'Jaipur' ORDER BY camp_date;

-- =====================================================================
--  B. ANALYTICS QUERIES
-- =====================================================================

-- B1. Stock matrix: one row per bank, one column per group (conditional aggregation)
SELECT bank,
       SUM(CASE WHEN blood_group = 'A+'  THEN units ELSE 0 END) AS `A+`,
       SUM(CASE WHEN blood_group = 'A-'  THEN units ELSE 0 END) AS `A-`,
       SUM(CASE WHEN blood_group = 'B+'  THEN units ELSE 0 END) AS `B+`,
       SUM(CASE WHEN blood_group = 'B-'  THEN units ELSE 0 END) AS `B-`,
       SUM(CASE WHEN blood_group = 'O+'  THEN units ELSE 0 END) AS `O+`,
       SUM(CASE WHEN blood_group = 'O-'  THEN units ELSE 0 END) AS `O-`,
       SUM(CASE WHEN blood_group = 'AB+' THEN units ELSE 0 END) AS `AB+`,
       SUM(CASE WHEN blood_group = 'AB-' THEN units ELSE 0 END) AS `AB-`
  FROM v_stock_by_bank_group
 WHERE district = 'Jaipur'
 GROUP BY bank ORDER BY bank;

-- B2. Shortage report: groups with ZERO units across all Jaipur banks
--     (LEFT JOIN from the reference table + NOT EXISTS subquery)
SELECT bg.group_code AS out_of_stock_in_jaipur
  FROM Blood_Group bg
 WHERE NOT EXISTS (SELECT 1 FROM v_stock_by_bank_group s
                    WHERE s.district = 'Jaipur' AND s.blood_group = bg.group_code);

-- B3. Units that expire within 7 days, per bank (GROUP BY + HAVING)
SELECT o.name AS bank, COUNT(*) AS units_expiring, MIN(u.expires_on) AS first_expiry
  FROM Blood_Unit u JOIN Organization o ON o.org_id = u.org_id
 WHERE u.status = 'Available' AND u.expires_on BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY
 GROUP BY o.org_id, o.name
HAVING COUNT(*) >= 1
 ORDER BY first_expiry;

-- B4. Donor leaderboard with tiers (window function: RANK)
SELECT RANK() OVER (ORDER BY donations DESC, points DESC) AS position,
       name, blood_group, donations, points, tier
  FROM v_donor_tiers
 WHERE donations > 0
 ORDER BY position, name
 LIMIT 10;

-- B5. Reminder list: donors who become eligible again in the next 14 days
SELECT name, blood_group, last_donation_date, next_eligible_date,
       DATEDIFF(next_eligible_date, CURDATE()) AS days_to_go
  FROM Donor
 WHERE next_eligible_date BETWEEN CURDATE() AND CURDATE() + INTERVAL 14 DAY
 ORDER BY next_eligible_date;

-- B6. Request funnel: how many donors were asked / accepted / declined / silent
SELECT r.request_id, r.patient_blood_grp, r.units_needed, r.status AS request_status,
       COUNT(rc.contact_id)                               AS asked,
       SUM(rc.status = 'Accepted')                        AS accepted,
       SUM(rc.status = 'Declined')                        AS declined,
       SUM(rc.status IN ('Sent','No Response'))           AS no_answer
  FROM Blood_Request r LEFT JOIN Request_Contact rc ON rc.request_id = r.request_id
 GROUP BY r.request_id, r.patient_blood_grp, r.units_needed, r.status
 ORDER BY r.request_id;

-- B7. Privacy check: phone numbers appear ONLY for donors who accepted
SELECT * FROM v_accepted_contacts;

-- B8. Camp fill rate and a running total of donations per month (window function)
SELECT camp_id, title, camp_date, capacity, capacity - seats_left AS booked,
       ROUND(100 * (capacity - seats_left) / capacity) AS fill_pct
  FROM v_upcoming_camps ORDER BY fill_pct DESC;

SELECT DATE_FORMAT(donation_date, '%Y-%m') AS month,
       COUNT(*) AS donations,
       SUM(COUNT(*)) OVER (ORDER BY DATE_FORMAT(donation_date, '%Y-%m')) AS running_total
  FROM Donation
 GROUP BY DATE_FORMAT(donation_date, '%Y-%m')
 ORDER BY month;

-- B9. Donors in the system but unreachable (phone never verified) - they are skipped by every search
SELECT donor_id, name, blood_group, phone_verified FROM Donor WHERE phone_verified = FALSE;

-- B10. Which blood bank collected the most (join + aggregate + subquery for the share)
SELECT o.name AS bank, COUNT(*) AS donations,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM Donation), 1) AS share_pct
  FROM Donation dn JOIN Organization o ON o.org_id = dn.org_id
 GROUP BY o.org_id, o.name ORDER BY donations DESC;

-- B11. Audit trail: every approval / request status change, recorded by triggers
SELECT * FROM Audit_Log ORDER BY audit_id;

-- B12. Pending organisations never show up in searches (approval workflow)
SELECT org_id, name, status FROM Organization WHERE status <> 'Approved';

-- =====================================================================
--  C. RULES IN ACTION (these statements are EXPECTED to fail where noted)
-- =====================================================================

-- C1. Under-age donor is rejected by trigger  ->  ERROR: Donor age must be between 18 and 65
INSERT INTO Donor (name, dob, gender, blood_group, phone, district_id, latitude, longitude)
VALUES ('Too Young', CURDATE() - INTERVAL 16 YEAR, 'Male', 'O+', '9222222201', 1, 26.9, 75.8);

-- C2. Bad phone number is rejected by CHECK  ->  ERROR: constraint failed
INSERT INTO Donor (name, dob, gender, blood_group, phone, district_id, latitude, longitude)
VALUES ('Bad Phone', CURDATE() - INTERVAL 30 YEAR, 'Male', 'O+', '12345', 1, 26.9, 75.8);

-- C3. Donating inside the cooldown is rejected by trigger.
--     Donor #17 donated 12 days ago.  ->  ERROR: still inside the minimum gap
INSERT INTO Donation (donor_id, org_id, donation_date, volume_ml)
VALUES (17, 1, CURDATE(), 450);

-- C4. A valid donation: the trigger creates a unit, moves the donor's dates, writes reward rows.
--     Donor #31 has never donated.
SELECT donor_id, last_donation_date, next_eligible_date FROM Donor WHERE donor_id = 31;
INSERT INTO Donation (donor_id, org_id, donation_date, volume_ml) VALUES (31, 1, CURDATE(), 450);
SELECT donor_id, last_donation_date, next_eligible_date FROM Donor WHERE donor_id = 31;
SELECT * FROM Blood_Unit WHERE donation_id = LAST_INSERT_ID();
SELECT * FROM Reward_Event WHERE donation_id = LAST_INSERT_ID();

-- C5. Mock OTP flow, then create a request
CALL sp_send_otp('9333333301', 'Blood Request', @code);
SELECT @code AS otp_you_would_receive_by_sms;
-- creating a request BEFORE verifying fails  ->  ERROR: Verify your mobile number with OTP first
CALL sp_create_request('Test Requester', '9333333301', 'O+', 2, 9, 'Urgent', 24, @rid);
CALL sp_verify_otp('9333333301', 'Blood Request', @code);
CALL sp_create_request('Test Requester', '9333333301', 'O+', 2, 9, 'Urgent', 24, @rid);
SELECT @rid AS new_request_id;

-- C6. Notify donors, widening the radius until at least 4 have been asked
CALL sp_expand_search(@rid, 4);
SELECT rc.contact_id, d.blood_group, rc.radius_km, rc.status
  FROM Request_Contact rc JOIN Donor d ON d.donor_id = rc.donor_id
 WHERE rc.request_id = @rid ORDER BY rc.contact_id;

-- C7. Two donors accept; 2 units were needed, so the request flips to 'Matched'
SELECT MIN(contact_id) INTO @c1 FROM Request_Contact WHERE request_id = @rid;
SELECT MIN(contact_id) INTO @c2 FROM Request_Contact WHERE request_id = @rid AND contact_id > @c1;
CALL sp_respond_to_request(@c1, 'Accepted');
SELECT status FROM Blood_Request WHERE request_id = @rid;        -- still Open
CALL sp_respond_to_request(@c2, 'Accepted');
SELECT status FROM Blood_Request WHERE request_id = @rid;        -- now Matched
SELECT * FROM v_accepted_contacts WHERE request_id = @rid;       -- phones revealed only now
-- answering again fails  ->  ERROR: Contact not found or already answered
CALL sp_respond_to_request(@c1, 'Declined');

-- C8. Eligibility self-check: a donor with a recent tattoo is deferred
INSERT INTO Eligibility_Check (donor_id) VALUES (25);
SET @chk = LAST_INSERT_ID();
INSERT INTO Eligibility_Answer (check_id, question_id, answer) VALUES
 (@chk,1,'No'),(@chk,2,'No'),(@chk,3,'No'),(@chk,4,'Yes'),(@chk,5,'No'),
 (@chk,6,'No'),(@chk,7,'No'),(@chk,8,'No'),(@chk,9,'No');
CALL sp_evaluate_eligibility(@chk);
SELECT donor_id, status, next_eligible_date FROM Donor WHERE donor_id = 25;

-- C9. Camp booking: camp #4 has 5 seats and 4 are taken
CALL sp_book_camp(4, 32);          -- takes the last seat
CALL sp_book_camp(4, 33);          -- ERROR: Camp is full
CALL sp_book_camp(4, 17);          -- ERROR: Donor will not be eligible by the camp date (donated 12 days ago)
SELECT camp_id, title, seats_left FROM v_upcoming_camps WHERE camp_id = 4;

-- =====================================================================
--  D. CONCURRENCY DEMO  (this is the "why not Excel?" answer)
--  Use TWO terminal windows, both connected:  mysql -u root -p blood_network
--  Window 1 performs the booking steps BY HAND in one open transaction, which
--  is exactly what sp_book_camp does internally.  (Do not CALL the procedure
--  from inside an open transaction: its own START TRANSACTION would end yours.)
--
--  Setup (either window): shrink camp #5 so only 1 seat is left (3 are booked):
--      UPDATE Camp SET capacity = 4 WHERE camp_id = 5;
--
--  WINDOW 1                                       WINDOW 2
--  START TRANSACTION;
--  SELECT capacity FROM Camp
--    WHERE camp_id = 5 FOR UPDATE;   -- locks the camp row
--  INSERT INTO Camp_Booking (camp_id, donor_id)
--    VALUES (5, 35);                 -- takes the last seat (not yet committed)
--                                                 CALL sp_book_camp(5, 34);
--                                                 -- ...WAITS here, blocked by Window 1
--  COMMIT;                           -- releases the lock
--                                                 -- Window 2 now continues and gets:
--                                                 -- ERROR: Camp is full
--
--  Result: exactly one donor gets the last seat (tested: Window 2 waited about
--  2.5 s, then was refused).  With a shared Excel sheet, both people would see
--  "1 seat left" and both would write their name in.
--
--  Cleanup:  DELETE FROM Camp_Booking WHERE camp_id = 5 AND donor_id = 35;
--            UPDATE Camp SET capacity = 40 WHERE camp_id = 5;
--  (or simply re-run 01_schema.sql and 02_seed.sql)

-- =====================================================================
--  E. INDEXES: before / after with EXPLAIN
-- =====================================================================
EXPLAIN SELECT donor_id FROM Donor
 WHERE status = 'Active' AND blood_group = 'O+' AND (next_eligible_date IS NULL OR next_eligible_date <= CURDATE());

ALTER TABLE Donor DROP INDEX idx_donor_search;
EXPLAIN SELECT donor_id FROM Donor
 WHERE status = 'Active' AND blood_group = 'O+' AND (next_eligible_date IS NULL OR next_eligible_date <= CURDATE());
CREATE INDEX idx_donor_search ON Donor (status, blood_group, next_eligible_date);
-- On the seed data: with the index the query is a RANGE scan reading ~7 rows;
-- without it, a full table scan (type = ALL) reading all 42.  The gap grows with data size.
