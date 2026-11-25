-- =====================================================================
--  BLOOD NETWORK - File 2 of 3: sample data
--  Run AFTER 01_schema.sql.   mysql -u root -p < 02_seed.sql
--
--  All people, phone numbers and organisations below are FICTIONAL.
--  Dates are relative to today (CURDATE()), so the demo stays realistic
--  whenever you load it.  Donations are inserted oldest-first on purpose:
--  the cooldown trigger checks each donor's previous donation.
-- =====================================================================
USE blood_network;
START TRANSACTION;

-- Reference data
INSERT INTO State (state_id, name) VALUES (1,'Rajasthan'),(2,'Maharashtra');
INSERT INTO District (district_id, state_id, name, latitude, longitude) VALUES
(1,1,'Jaipur',26.912400,75.787300),(2,1,'Kota',25.213800,75.864700),
(3,1,'Ajmer',26.449900,74.639900),(4,2,'Mumbai',19.076000,72.877700),
(5,2,'Pune',18.520400,73.856700);

INSERT INTO Blood_Group VALUES ('A+','A','+'),('A-','A','-'),('B+','B','+'),('B-','B','-'),
('AB+','AB','+'),('AB-','AB','-'),('O+','O','+'),('O-','O','-');

-- Red-cell compatibility: donor group -> recipient groups
INSERT INTO Compatibility (donor_group, recipient_group) VALUES
('O-','O-'),('O-','O+'),('O-','A-'),('O-','A+'),('O-','B-'),('O-','B+'),('O-','AB-'),('O-','AB+'),
('O+','O+'),('O+','A+'),('O+','B+'),('O+','AB+'),
('A-','A-'),('A-','A+'),('A-','AB-'),('A-','AB+'),
('A+','A+'),('A+','AB+'),
('B-','B-'),('B-','B+'),('B-','AB-'),('B-','AB+'),
('B+','B+'),('B+','AB+'),
('AB-','AB-'),('AB-','AB+'),
('AB+','AB+');

INSERT INTO Component (component_id, name, shelf_life_days) VALUES (1,'Whole Blood',35),(2,'Packed Red Cells',42);
INSERT INTO Cooldown_Rule (gender, min_gap_days) VALUES ('Male',90),('Female',120),('Other',120);
INSERT INTO Tier (tier_name, min_donations) VALUES ('Starter',0),('Bronze',1),('Silver',3),('Gold',5),('Platinum',10);

INSERT INTO Eligibility_Question (question_id, question_text, disqualifying_answer, outcome, deferral_days) VALUES
(1,'Do you currently have a fever, cold, cough or infection?','Yes','Deferred',14),
(2,'Have you donated blood in the last 3 months?','Yes','Deferred',90),
(3,'Do you weigh less than 45 kg?','Yes','Ineligible',NULL),
(4,'Have you had a tattoo or piercing in the last 6 months?','Yes','Deferred',180),
(5,'Are you currently taking antibiotics?','Yes','Deferred',14),
(6,'Have you had major surgery in the last 6 months?','Yes','Deferred',180),
(7,'Are you pregnant, or have you delivered or breastfed in the last 6 months?','Yes','Deferred',180),
(8,'Have you ever tested positive for HIV, hepatitis B or hepatitis C?','Yes','Ineligible',NULL),
(9,'Do you have heart disease, epilepsy or cancer?','Yes','Ineligible',NULL);

-- Organisations (#17 is still Pending: it must NOT appear in any search)
INSERT INTO Organization (org_id,name,org_type,ownership,district_id,address,phone,latitude,longitude,status) VALUES
(1,'Pink City Blood Centre','Blood Bank','Charitable',1,'Malviya Nagar, Jaipur','1410000001',26.855300,75.810500,'Approved'),
(2,'Lifeline Blood Bank','Blood Bank','Private',1,'Vaishali Nagar, Jaipur','1410000002',26.912000,75.743000,'Approved'),
(3,'Sanjeevani Blood Centre','Blood Bank','Govt',1,'C-Scheme, Jaipur','1410000003',26.910000,75.800000,'Approved'),
(4,'Mansarovar Voluntary Blood Bank','Blood Bank','Charitable',1,'Mansarovar, Jaipur','1410000004',26.849000,75.764000,'Approved'),
(5,'Sitapura Community Blood Bank','Blood Bank','Charitable',1,'Sitapura, Jaipur','1410000005',26.774000,75.830000,'Approved'),
(6,'Jagatpura Care Blood Centre','Blood Bank','Private',1,'Jagatpura, Jaipur','1410000006',26.842000,75.864000,'Approved'),
(7,'Tonk Road Blood Storage Unit','Blood Bank','Govt',1,'Tonk Road, Jaipur','1410000007',26.870000,75.795000,'Approved'),
(8,'Sanganer Red Drop Blood Bank','Blood Bank','Charitable',1,'Sanganer, Jaipur','1410000008',26.820000,75.790000,'Approved'),
(9,'Aravali City Hospital','Hospital','Private',1,'Malviya Nagar, Jaipur','1410000009',26.860000,75.815000,'Approved'),
(10,'Rajputana Medical College Hospital','Hospital','Govt',1,'Sawai Man Singh Rd, Jaipur','1410000010',26.905000,75.810000,'Approved'),
(11,'Heritage Heart Institute','Hospital','Private',1,'Vaishali Nagar, Jaipur','1410000011',26.918000,75.738000,'Approved'),
(12,'Mansarovar General Hospital','Hospital','Private',1,'Mansarovar, Jaipur','1410000012',26.851000,75.758000,'Approved'),
(13,'Chambal Valley Blood Bank','Blood Bank','Govt',2,'Kota City','1410000013',25.213800,75.864700,'Approved'),
(14,'Ana Sagar Blood Centre','Blood Bank','Charitable',3,'Ajmer City','1410000014',26.449900,74.639900,'Approved'),
(15,'Harbour City Blood Bank','Blood Bank','Charitable',4,'Andheri East, Mumbai','1410000015',19.113600,72.869700,'Approved'),
(16,'Marine Drive Hospital','Hospital','Private',4,'Marine Lines, Mumbai','1410000016',18.944000,72.823000,'Approved'),
(17,'Gulmohar Blood Bank (new application)','Blood Bank','Private',1,'Jhotwara, Jaipur','1410000017',26.950000,75.740000,'Pending');

-- Donors (fictional; phones are 90000xxxxx).  #7, #19, #31 have NOT verified their phone.
INSERT INTO Donor (donor_id,name,dob,gender,blood_group,phone,phone_verified,district_id,latitude,longitude) VALUES
(1,'Yash Agarwal',CURDATE() - INTERVAL 35 YEAR - INTERVAL 239 DAY,'Male','O+','9000000001',1,1,26.860814,75.811369),
(2,'Harsh Mehta',CURDATE() - INTERVAL 54 YEAR - INTERVAL 166 DAY,'Male','O+','9000000002',1,1,26.781906,75.832844),
(3,'Tanvi Khan',CURDATE() - INTERVAL 23 YEAR - INTERVAL 42 DAY,'Female','A+','9000000003',1,1,26.859170,75.817054),
(4,'Vikram Nair',CURDATE() - INTERVAL 25 YEAR - INTERVAL 9 DAY,'Male','B-','9000000004',1,1,26.864671,75.798256),
(5,'Yash Joshi',CURDATE() - INTERVAL 42 YEAR - INTERVAL 239 DAY,'Male','B+','9000000005',1,1,26.835028,75.858407),
(6,'Ananya Joshi',CURDATE() - INTERVAL 53 YEAR - INTERVAL 293 DAY,'Female','B+','9000000006',1,1,26.840922,75.761107),
(7,'Dev Nair',CURDATE() - INTERVAL 39 YEAR - INTERVAL 56 DAY,'Male','O-','9000000007',0,1,26.848797,75.799270),
(8,'Nikhil Saini',CURDATE() - INTERVAL 36 YEAR - INTERVAL 42 DAY,'Male','A+','9000000008',1,1,26.905064,75.753630),
(9,'Divya Khan',CURDATE() - INTERVAL 50 YEAR - INTERVAL 280 DAY,'Female','O+','9000000009',1,1,26.879232,75.798428),
(10,'Arjun Reddy',CURDATE() - INTERVAL 27 YEAR - INTERVAL 114 DAY,'Male','A-','9000000010',1,1,26.854880,75.764935),
(11,'Mohit Saini',CURDATE() - INTERVAL 42 YEAR - INTERVAL 264 DAY,'Male','B+','9000000011',1,1,26.860936,75.755320),
(12,'Shreya Mehta',CURDATE() - INTERVAL 22 YEAR - INTERVAL 140 DAY,'Female','AB+','9000000012',1,1,26.903668,75.734840),
(13,'Mohit Mehta',CURDATE() - INTERVAL 43 YEAR - INTERVAL 72 DAY,'Male','B+','9000000013',1,1,26.872301,75.794233),
(14,'Manish Sharma',CURDATE() - INTERVAL 26 YEAR - INTERVAL 183 DAY,'Male','B+','9000000014',1,1,26.809235,75.756021),
(15,'Divya Singh',CURDATE() - INTERVAL 37 YEAR - INTERVAL 40 DAY,'Female','A+','9000000015',1,1,26.861796,75.783078),
(16,'Manish Joshi',CURDATE() - INTERVAL 51 YEAR - INTERVAL 130 DAY,'Male','A-','9000000016',1,1,26.920892,75.738163),
(17,'Kabir Khan',CURDATE() - INTERVAL 28 YEAR - INTERVAL 194 DAY,'Male','B-','9000000017',1,1,26.848300,75.864945),
(18,'Priya Jain',CURDATE() - INTERVAL 50 YEAR - INTERVAL 150 DAY,'Female','AB+','9000000018',1,1,26.845985,75.807212),
(19,'Deepak Nair',CURDATE() - INTERVAL 22 YEAR - INTERVAL 85 DAY,'Male','A+','9000000019',0,1,26.858072,75.774727),
(20,'Vikram Choudhary',CURDATE() - INTERVAL 23 YEAR - INTERVAL 229 DAY,'Male','B+','9000000020',1,1,26.956380,75.731081),
(21,'Shreya Joshi',CURDATE() - INTERVAL 35 YEAR - INTERVAL 283 DAY,'Female','B+','9000000021',1,1,26.958938,75.738155),
(22,'Amit Khan',CURDATE() - INTERVAL 38 YEAR - INTERVAL 159 DAY,'Male','O-','9000000022',1,1,26.881884,75.798597),
(23,'Gaurav Rathore',CURDATE() - INTERVAL 26 YEAR - INTERVAL 275 DAY,'Male','B-','9000000023',1,1,26.842393,75.760114),
(24,'Pooja Nair',CURDATE() - INTERVAL 19 YEAR - INTERVAL 9 DAY,'Female','O-','9000000024',1,1,26.916988,75.732413),
(25,'Vikram Verma',CURDATE() - INTERVAL 40 YEAR - INTERVAL 288 DAY,'Male','B+','9000000025',1,1,26.912340,75.737683),
(26,'Pranav Khan',CURDATE() - INTERVAL 53 YEAR - INTERVAL 158 DAY,'Male','A+','9000000026',1,1,26.915360,75.809177),
(27,'Shreya Nair',CURDATE() - INTERVAL 49 YEAR - INTERVAL 58 DAY,'Female','AB-','9000000027',1,1,26.862570,75.785326),
(28,'Mohit Agarwal',CURDATE() - INTERVAL 46 YEAR - INTERVAL 73 DAY,'Male','A-','9000000028',1,1,26.869209,75.800498),
(29,'Karan Verma',CURDATE() - INTERVAL 44 YEAR - INTERVAL 140 DAY,'Male','O+','9000000029',1,1,26.849214,75.854622),
(30,'Neha Khan',CURDATE() - INTERVAL 53 YEAR - INTERVAL 64 DAY,'Female','O+','9000000030',1,1,26.811364,75.782404),
(31,'Gaurav Nair',CURDATE() - INTERVAL 23 YEAR - INTERVAL 59 DAY,'Male','AB-','9000000031',0,1,26.827393,75.798543),
(32,'Karan Verma',CURDATE() - INTERVAL 53 YEAR - INTERVAL 288 DAY,'Male','AB+','9000000032',1,1,26.866556,75.820733),
(33,'Pooja Joshi',CURDATE() - INTERVAL 45 YEAR - INTERVAL 84 DAY,'Female','O+','9000000033',1,1,26.819553,75.798752),
(34,'Rohan Joshi',CURDATE() - INTERVAL 43 YEAR - INTERVAL 144 DAY,'Male','O+','9000000034',1,1,26.866947,75.804865),
(35,'Gaurav Das',CURDATE() - INTERVAL 46 YEAR - INTERVAL 149 DAY,'Male','O+','9000000035',1,1,26.953885,75.739680),
(36,'Neha Das',CURDATE() - INTERVAL 32 YEAR - INTERVAL 112 DAY,'Female','A+','9000000036',1,1,26.857200,75.811513),
(37,'Nikhil Verma',CURDATE() - INTERVAL 22 YEAR - INTERVAL 180 DAY,'Male','A+','9000000037',1,2,25.215484,75.864757),
(38,'Kabir Joshi',CURDATE() - INTERVAL 22 YEAR - INTERVAL 109 DAY,'Male','A+','9000000038',1,2,25.223016,75.856302),
(39,'Fatima Mehta',CURDATE() - INTERVAL 23 YEAR - INTERVAL 140 DAY,'Female','O+','9000000039',1,2,25.217304,75.859404),
(40,'Karan Nair',CURDATE() - INTERVAL 21 YEAR - INTERVAL 263 DAY,'Male','O+','9000000040',1,4,19.080775,72.874469),
(41,'Kabir Jain',CURDATE() - INTERVAL 35 YEAR - INTERVAL 255 DAY,'Male','O+','9000000041',1,4,19.064170,72.886348),
(42,'Pooja Reddy',CURDATE() - INTERVAL 44 YEAR - INTERVAL 133 DAY,'Female','O+','9000000042',1,4,19.061235,72.883520);

-- Opening stock at the eight Jaipur banks, Kota, Ajmer and Mumbai (expiry filled by trigger)
INSERT INTO Blood_Unit (org_id,blood_group,component_id,volume_ml,collected_on) VALUES
(1,'B+',2,450,CURDATE() - INTERVAL 1 DAY),
(1,'B+',1,450,CURDATE() - INTERVAL 24 DAY),
(1,'B+',1,450,CURDATE() - INTERVAL 8 DAY),
(1,'B+',1,450,CURDATE() - INTERVAL 14 DAY),
(1,'B+',2,450,CURDATE() - INTERVAL 13 DAY),
(1,'B-',1,350,CURDATE() - INTERVAL 2 DAY),
(1,'B-',2,350,CURDATE() - INTERVAL 17 DAY),
(1,'O-',2,450,CURDATE() - INTERVAL 4 DAY),
(1,'AB+',1,350,CURDATE() - INTERVAL 9 DAY),
(1,'AB+',2,350,CURDATE() - INTERVAL 28 DAY),
(1,'AB+',2,350,CURDATE() - INTERVAL 21 DAY),
(2,'A+',1,450,CURDATE() - INTERVAL 24 DAY),
(2,'A+',2,450,CURDATE() - INTERVAL 19 DAY),
(2,'A+',2,350,CURDATE() - INTERVAL 29 DAY),
(2,'A+',1,350,CURDATE() - INTERVAL 25 DAY),
(2,'A+',1,450,CURDATE() - INTERVAL 0 DAY),
(2,'B+',2,450,CURDATE() - INTERVAL 25 DAY),
(2,'B+',2,450,CURDATE() - INTERVAL 25 DAY),
(2,'B+',1,450,CURDATE() - INTERVAL 5 DAY),
(2,'B+',2,350,CURDATE() - INTERVAL 12 DAY),
(2,'B+',1,450,CURDATE() - INTERVAL 7 DAY),
(2,'O+',2,450,CURDATE() - INTERVAL 9 DAY),
(2,'O+',1,350,CURDATE() - INTERVAL 0 DAY),
(2,'O+',2,350,CURDATE() - INTERVAL 12 DAY),
(2,'O+',2,450,CURDATE() - INTERVAL 27 DAY),
(2,'O+',1,450,CURDATE() - INTERVAL 11 DAY),
(2,'O+',2,450,CURDATE() - INTERVAL 12 DAY),
(2,'O-',2,450,CURDATE() - INTERVAL 30 DAY),
(2,'O-',1,350,CURDATE() - INTERVAL 28 DAY),
(2,'AB+',1,450,CURDATE() - INTERVAL 30 DAY),
(2,'AB+',2,350,CURDATE() - INTERVAL 3 DAY),
(2,'AB-',2,450,CURDATE() - INTERVAL 25 DAY),
(3,'A+',2,450,CURDATE() - INTERVAL 16 DAY),
(3,'A+',1,450,CURDATE() - INTERVAL 28 DAY),
(3,'A-',1,450,CURDATE() - INTERVAL 1 DAY),
(3,'A-',2,450,CURDATE() - INTERVAL 0 DAY),
(3,'B+',2,450,CURDATE() - INTERVAL 23 DAY),
(3,'B+',2,450,CURDATE() - INTERVAL 21 DAY),
(3,'B+',1,450,CURDATE() - INTERVAL 13 DAY),
(3,'B+',1,450,CURDATE() - INTERVAL 29 DAY),
(3,'B-',2,450,CURDATE() - INTERVAL 21 DAY),
(3,'O+',1,450,CURDATE() - INTERVAL 28 DAY),
(3,'O+',2,450,CURDATE() - INTERVAL 9 DAY),
(3,'O+',2,450,CURDATE() - INTERVAL 10 DAY),
(3,'O+',2,450,CURDATE() - INTERVAL 9 DAY),
(3,'O+',2,350,CURDATE() - INTERVAL 6 DAY),
(3,'O+',2,450,CURDATE() - INTERVAL 30 DAY),
(3,'O-',2,450,CURDATE() - INTERVAL 28 DAY),
(3,'AB+',2,450,CURDATE() - INTERVAL 9 DAY),
(3,'AB-',2,350,CURDATE() - INTERVAL 9 DAY),
(4,'A+',1,450,CURDATE() - INTERVAL 25 DAY),
(4,'A+',2,450,CURDATE() - INTERVAL 20 DAY),
(4,'A-',2,450,CURDATE() - INTERVAL 14 DAY),
(4,'B+',1,450,CURDATE() - INTERVAL 15 DAY),
(4,'B+',2,350,CURDATE() - INTERVAL 21 DAY),
(4,'B+',1,450,CURDATE() - INTERVAL 16 DAY),
(4,'B+',2,450,CURDATE() - INTERVAL 19 DAY),
(4,'B+',2,350,CURDATE() - INTERVAL 26 DAY),
(4,'O+',2,350,CURDATE() - INTERVAL 25 DAY),
(4,'O+',1,350,CURDATE() - INTERVAL 0 DAY),
(4,'O+',1,350,CURDATE() - INTERVAL 15 DAY),
(4,'O+',2,350,CURDATE() - INTERVAL 14 DAY),
(4,'O+',2,450,CURDATE() - INTERVAL 18 DAY),
(4,'AB+',2,450,CURDATE() - INTERVAL 7 DAY),
(4,'AB+',1,450,CURDATE() - INTERVAL 22 DAY),
(4,'AB+',1,350,CURDATE() - INTERVAL 24 DAY),
(4,'AB-',1,350,CURDATE() - INTERVAL 25 DAY),
(5,'A+',2,450,CURDATE() - INTERVAL 1 DAY),
(5,'A+',2,350,CURDATE() - INTERVAL 29 DAY),
(5,'A+',1,450,CURDATE() - INTERVAL 4 DAY),
(5,'A+',2,450,CURDATE() - INTERVAL 16 DAY),
(5,'A-',2,450,CURDATE() - INTERVAL 30 DAY),
(5,'B+',2,450,CURDATE() - INTERVAL 28 DAY),
(5,'B+',2,450,CURDATE() - INTERVAL 26 DAY),
(5,'B-',2,350,CURDATE() - INTERVAL 23 DAY),
(5,'O+',2,450,CURDATE() - INTERVAL 8 DAY),
(5,'O+',1,450,CURDATE() - INTERVAL 8 DAY),
(5,'O+',2,450,CURDATE() - INTERVAL 20 DAY),
(5,'O+',1,450,CURDATE() - INTERVAL 14 DAY),
(5,'O+',1,450,CURDATE() - INTERVAL 9 DAY),
(5,'AB+',2,450,CURDATE() - INTERVAL 28 DAY),
(6,'A+',1,350,CURDATE() - INTERVAL 12 DAY),
(6,'A-',1,450,CURDATE() - INTERVAL 6 DAY),
(6,'A-',1,450,CURDATE() - INTERVAL 13 DAY),
(6,'B+',2,450,CURDATE() - INTERVAL 13 DAY),
(6,'B+',1,350,CURDATE() - INTERVAL 26 DAY),
(6,'B-',2,450,CURDATE() - INTERVAL 30 DAY),
(6,'O+',1,450,CURDATE() - INTERVAL 12 DAY),
(6,'O+',2,350,CURDATE() - INTERVAL 30 DAY),
(6,'O+',2,450,CURDATE() - INTERVAL 24 DAY),
(6,'O+',2,450,CURDATE() - INTERVAL 17 DAY),
(6,'O+',2,450,CURDATE() - INTERVAL 17 DAY),
(6,'O-',1,450,CURDATE() - INTERVAL 7 DAY),
(6,'O-',2,450,CURDATE() - INTERVAL 15 DAY),
(6,'AB-',2,450,CURDATE() - INTERVAL 21 DAY),
(7,'A+',2,350,CURDATE() - INTERVAL 26 DAY),
(7,'A+',2,350,CURDATE() - INTERVAL 19 DAY),
(7,'A+',2,350,CURDATE() - INTERVAL 29 DAY),
(7,'A-',2,450,CURDATE() - INTERVAL 21 DAY),
(7,'O+',2,350,CURDATE() - INTERVAL 27 DAY),
(7,'O+',2,350,CURDATE() - INTERVAL 1 DAY),
(7,'O+',2,450,CURDATE() - INTERVAL 10 DAY),
(7,'O+',1,450,CURDATE() - INTERVAL 10 DAY),
(7,'O+',2,450,CURDATE() - INTERVAL 8 DAY),
(7,'O-',2,350,CURDATE() - INTERVAL 15 DAY),
(8,'A+',1,450,CURDATE() - INTERVAL 2 DAY),
(8,'A-',1,350,CURDATE() - INTERVAL 30 DAY),
(8,'O+',1,450,CURDATE() - INTERVAL 4 DAY),
(8,'O+',1,350,CURDATE() - INTERVAL 15 DAY),
(8,'O+',2,350,CURDATE() - INTERVAL 18 DAY),
(8,'O+',1,450,CURDATE() - INTERVAL 22 DAY),
(8,'O+',2,450,CURDATE() - INTERVAL 5 DAY),
(8,'O-',2,450,CURDATE() - INTERVAL 22 DAY),
(13,'A+',1,450,CURDATE() - INTERVAL 0 DAY),
(13,'A+',2,450,CURDATE() - INTERVAL 21 DAY),
(13,'A-',2,450,CURDATE() - INTERVAL 6 DAY),
(13,'B-',2,450,CURDATE() - INTERVAL 7 DAY),
(13,'B-',1,450,CURDATE() - INTERVAL 24 DAY),
(13,'O+',2,450,CURDATE() - INTERVAL 25 DAY),
(13,'O+',1,450,CURDATE() - INTERVAL 25 DAY),
(13,'AB+',2,450,CURDATE() - INTERVAL 21 DAY),
(13,'AB+',2,350,CURDATE() - INTERVAL 16 DAY),
(13,'AB-',1,450,CURDATE() - INTERVAL 26 DAY),
(14,'A+',1,450,CURDATE() - INTERVAL 30 DAY),
(14,'A+',2,450,CURDATE() - INTERVAL 28 DAY),
(14,'A+',2,450,CURDATE() - INTERVAL 4 DAY),
(14,'A-',1,450,CURDATE() - INTERVAL 16 DAY),
(14,'B+',2,450,CURDATE() - INTERVAL 25 DAY),
(14,'B+',2,450,CURDATE() - INTERVAL 14 DAY),
(14,'B+',2,450,CURDATE() - INTERVAL 18 DAY),
(14,'B+',2,450,CURDATE() - INTERVAL 27 DAY),
(14,'B+',1,350,CURDATE() - INTERVAL 8 DAY),
(14,'B-',1,450,CURDATE() - INTERVAL 18 DAY),
(14,'O+',2,450,CURDATE() - INTERVAL 10 DAY),
(14,'O+',1,450,CURDATE() - INTERVAL 27 DAY),
(14,'O+',2,350,CURDATE() - INTERVAL 15 DAY),
(14,'O+',1,450,CURDATE() - INTERVAL 25 DAY),
(14,'O-',2,450,CURDATE() - INTERVAL 28 DAY),
(14,'AB+',2,350,CURDATE() - INTERVAL 16 DAY),
(14,'AB+',1,350,CURDATE() - INTERVAL 7 DAY),
(14,'AB-',2,450,CURDATE() - INTERVAL 24 DAY),
(15,'A+',2,450,CURDATE() - INTERVAL 20 DAY),
(15,'A-',2,450,CURDATE() - INTERVAL 25 DAY),
(15,'A-',1,350,CURDATE() - INTERVAL 9 DAY),
(15,'B+',2,450,CURDATE() - INTERVAL 7 DAY),
(15,'B-',2,450,CURDATE() - INTERVAL 11 DAY),
(15,'O+',2,450,CURDATE() - INTERVAL 11 DAY),
(15,'O+',2,450,CURDATE() - INTERVAL 17 DAY),
(15,'O+',2,450,CURDATE() - INTERVAL 22 DAY),
(15,'O-',2,450,CURDATE() - INTERVAL 8 DAY),
(15,'AB+',1,450,CURDATE() - INTERVAL 6 DAY),
(15,'AB-',1,450,CURDATE() - INTERVAL 17 DAY);

INSERT INTO Blood_Unit (org_id,blood_group,component_id,volume_ml,collected_on) VALUES (2,'O-',1,450,CURDATE() - INTERVAL 33 DAY);
DELETE FROM Blood_Unit WHERE blood_group='AB-' AND org_id IN (1,2,3,4,5,6,7,8);

-- Camps: 3 completed in the past, 4 approved upcoming, 1 pending.  Camp #4 has only 5 seats (used in the booking demo).
INSERT INTO Camp (camp_id,title,conducted_by_org,organised_by,district_id,venue,camp_date,start_time,end_time,capacity,status) VALUES
(1,'Aravali Society Annual Blood Donation Drive',1,'Aravali Residents Welfare Society',1,'Community Hall, Malviya Nagar',CURDATE() - INTERVAL 120 DAY,'09:00','14:00',60,'Completed'),
(2,'College Fest Blood Camp',3,'Rajputana Engineering College',1,'Main Auditorium, Jaipur',CURDATE() - INTERVAL 75 DAY,'10:00','16:00',80,'Completed'),
(3,'Harbour Corporate Camp',15,'Harbour Tech Park Employees',4,'Tech Park Atrium, Andheri',CURDATE() - INTERVAL 40 DAY,'09:30','15:30',50,'Completed'),
(4,'Mansarovar Youth Club Camp',4,'Mansarovar Youth Club',1,'Club House, Mansarovar',CURDATE() + INTERVAL 5 DAY,'09:00','13:00',5,'Approved'),
(5,'Vaishali Nagar Temple Trust Camp',2,'Shri Temple Trust',1,'Temple Complex, Vaishali Nagar',CURDATE() + INTERVAL 12 DAY,'08:00','13:00',40,'Approved'),
(6,'Sitapura Industrial Area Camp',5,'Sitapura Manufacturers Association',1,'Association Office, Sitapura',CURDATE() + INTERVAL 20 DAY,'10:00','16:00',60,'Approved'),
(7,'Marine Lines Community Camp',15,'Marine Lines Residents Group',4,'Community Centre, Marine Lines',CURDATE() + INTERVAL 9 DAY,'09:00','14:00',30,'Approved'),
(8,'Jagatpura Neighbourhood Camp (awaiting approval)',6,'Jagatpura Residents',1,'Park Pavilion, Jagatpura',CURDATE() + INTERVAL 30 DAY,'09:00','13:00',25,'Pending');

-- Bookings for the three completed camps (the donation trigger flips them to 'Attended')
INSERT INTO Camp_Booking (camp_id,donor_id,status) VALUES
(1,1,'Booked'),
(1,2,'Booked'),
(1,4,'Booked'),
(1,5,'Booked'),
(1,8,'Booked'),
(1,9,'Booked'),
(1,10,'Booked'),
(1,11,'Booked'),
(2,3,'Booked'),
(2,6,'Booked'),
(2,12,'Booked'),
(2,13,'Booked'),
(2,14,'Booked'),
(2,15,'Booked'),
(2,16,'Booked'),
(3,40,'Booked'),
(3,41,'Booked'),
(3,42,'Booked');

-- Donations, oldest first.  Each insert fires: cooldown check -> unit created -> donor dates moved -> reward rows written.
INSERT INTO Donation (donor_id,org_id,camp_id,donation_date,volume_ml) VALUES
(24,1,NULL,CURDATE() - INTERVAL 399 DAY,450),
(30,1,NULL,CURDATE() - INTERVAL 360 DAY,450),
(25,2,NULL,CURDATE() - INTERVAL 328 DAY,450),
(27,4,NULL,CURDATE() - INTERVAL 270 DAY,450),
(28,2,NULL,CURDATE() - INTERVAL 237 DAY,350),
(29,4,NULL,CURDATE() - INTERVAL 214 DAY,350),
(26,1,NULL,CURDATE() - INTERVAL 176 DAY,450),
(1,1,1,CURDATE() - INTERVAL 120 DAY,450),
(2,1,1,CURDATE() - INTERVAL 120 DAY,450),
(4,1,1,CURDATE() - INTERVAL 120 DAY,450),
(5,1,1,CURDATE() - INTERVAL 120 DAY,450),
(8,1,1,CURDATE() - INTERVAL 120 DAY,450),
(9,1,1,CURDATE() - INTERVAL 120 DAY,450),
(10,1,1,CURDATE() - INTERVAL 120 DAY,450),
(11,1,1,CURDATE() - INTERVAL 120 DAY,450),
(23,3,NULL,CURDATE() - INTERVAL 85 DAY,350),
(3,3,2,CURDATE() - INTERVAL 75 DAY,450),
(6,3,2,CURDATE() - INTERVAL 75 DAY,450),
(12,3,2,CURDATE() - INTERVAL 75 DAY,450),
(13,3,2,CURDATE() - INTERVAL 75 DAY,450),
(14,3,2,CURDATE() - INTERVAL 75 DAY,450),
(15,3,2,CURDATE() - INTERVAL 75 DAY,450),
(16,3,2,CURDATE() - INTERVAL 75 DAY,450),
(21,3,NULL,CURDATE() - INTERVAL 60 DAY,350),
(20,3,NULL,CURDATE() - INTERVAL 48 DAY,350),
(40,15,3,CURDATE() - INTERVAL 40 DAY,350),
(41,15,3,CURDATE() - INTERVAL 40 DAY,350),
(42,15,3,CURDATE() - INTERVAL 40 DAY,350),
(18,3,NULL,CURDATE() - INTERVAL 30 DAY,350),
(4,4,NULL,CURDATE() - INTERVAL 28 DAY,450),
(1,2,NULL,CURDATE() - INTERVAL 27 DAY,450),
(22,5,NULL,CURDATE() - INTERVAL 25 DAY,350),
(5,3,NULL,CURDATE() - INTERVAL 13 DAY,450),
(17,1,NULL,CURDATE() - INTERVAL 12 DAY,350),
(2,2,NULL,CURDATE() - INTERVAL 11 DAY,450);

-- A few bookings for upcoming camps (camp #4: 4 of 5 seats gone)
INSERT INTO Camp_Booking (camp_id,donor_id) VALUES (4,24),(4,25),(4,26),(4,27),(5,28),(5,29),(5,30),(7,40);

-- Requests.  #1-#3 open, #4 will be matched, #5 is already past its deadline (housekeeping expires it).
INSERT INTO Blood_Request (request_id,requester_name,requester_phone,patient_blood_grp,units_needed,hospital_org_id,urgency,status,created_at,expires_at) VALUES
(1,'Ramesh Kumar','9111111101','O+',3,9,'Urgent','Open',NOW() - INTERVAL 2 HOUR, NOW() + INTERVAL 46 HOUR),
(2,'Sunita Devi','9111111102','A+',2,10,'Critical','Open',NOW() - INTERVAL 1 HOUR, NOW() + INTERVAL 23 HOUR),
(3,'Ajay Patil','9111111103','B-',1,16,'Planned','Open',NOW() - INTERVAL 5 HOUR, NOW() + INTERVAL 67 HOUR),
(4,'Mohan Lal','9111111104','O+',1,12,'Urgent','Open',NOW() - INTERVAL 30 HOUR, NOW() + INTERVAL 18 HOUR),
(5,'Geeta Rani','9111111105','AB+',1,11,'Urgent','Open',NOW() - INTERVAL 4 DAY, NOW() - INTERVAL 2 DAY);

-- Ask donors for requests 1-4 (radius widens automatically until at least 5 donors are asked)
CALL sp_expand_search(1, 5);
CALL sp_expand_search(2, 5);
CALL sp_expand_search(3, 2);
CALL sp_notify_donors(4, 25);

-- Some donors answer
UPDATE Request_Contact SET status='Accepted', responded_at=NOW() - INTERVAL 20 MINUTE
 WHERE request_id=1 AND contact_id = (SELECT MIN(c) FROM (SELECT contact_id AS c FROM Request_Contact WHERE request_id=1) t);
UPDATE Request_Contact SET status='Declined', responded_at=NOW() - INTERVAL 40 MINUTE
 WHERE request_id=2 AND contact_id = (SELECT MIN(c) FROM (SELECT contact_id AS c FROM Request_Contact WHERE request_id=2) t);
UPDATE Request_Contact SET status='Accepted', responded_at=NOW() - INTERVAL 10 MINUTE
 WHERE request_id=4 AND contact_id = (SELECT MIN(c) FROM (SELECT contact_id AS c FROM Request_Contact WHERE request_id=4) t);
UPDATE Blood_Request SET status='Matched' WHERE request_id=4;

-- Two eligibility self-checks, scored by the stored procedure
INSERT INTO Eligibility_Check (donor_id) VALUES (24);
INSERT INTO Eligibility_Answer (check_id,question_id,answer) VALUES
(LAST_INSERT_ID(),1,'No'),(LAST_INSERT_ID(),2,'No'),(LAST_INSERT_ID(),3,'No'),(LAST_INSERT_ID(),4,'No'),(LAST_INSERT_ID(),5,'No'),
(LAST_INSERT_ID(),6,'No'),(LAST_INSERT_ID(),7,'No'),(LAST_INSERT_ID(),8,'No'),(LAST_INSERT_ID(),9,'No');
CALL sp_evaluate_eligibility(LAST_INSERT_ID());

-- Approval workflow history (fires the audit trigger)
UPDATE Organization SET status='Rejected' WHERE org_id=17;
UPDATE Organization SET status='Pending'  WHERE org_id=17;

COMMIT;
CALL sp_housekeeping();
