import os
from docx_builder import DocxWriter

IMG_DIR = "/home/gaurav/Desktop/RAKTKHOJ/doc_images"

# Image mappings
IMG_NAV_HEADER    = os.path.join(IMG_DIR, "media_1794411944975_98cf9045.png") # Header & KPIs
IMG_EMERGENCY_REQ = os.path.join(IMG_DIR, "media_1794411870760_0cb42f48.png") # Emergency Flow
IMG_DONOR_REG     = os.path.join(IMG_DIR, "media_1794411877454_ce7046d2.png") # Donor Registration
IMG_ELIGIBILITY   = os.path.join(IMG_DIR, "media_1794411884001_b85d087f.png") # Eligibility Self-Check
IMG_FIND_BANKS    = os.path.join(IMG_DIR, "media_1794411889348_363f3645.png") # Find Blood Banks
IMG_FIND_DONORS   = os.path.join(IMG_DIR, "media_1794411897168_baaaacf1.png") # Find Donors
IMG_STOCK_MATRIX  = os.path.join(IMG_DIR, "media_1794411918884_d4c7c099.png") # Stock Matrix
IMG_CAMPS         = os.path.join(IMG_DIR, "media_1794411925739_e83920c0.png") # Camps & Booking
IMG_SQL_CONSOLE   = os.path.join(IMG_DIR, "media_1794411937430_1e390811.png") # SQL Console

doc = DocxWriter("RaktSutra_Project_Documentation.docx")

# Title & Subtitle
doc.add_title("RaktSutra — Blood Network Management System", "Complete Architectural & Illustrated Visual Guide")
doc.add_paragraph("An enterprise-grade relational database and web management platform for emergency blood discovery, donor dispatch, real-time stock matrix tracking, and camp logistics.", italic=True)

# 1. Executive Summary & Top Navigation
doc.add_heading_1("1. System Architecture & Live Overview")
doc.add_paragraph("RaktSutra is engineered around a database-first philosophy. Rather than trusting application-level JavaScript or Python for critical health decisions, all life-critical constraints—donor cooldown periods, minimum ages, component shelf life, and geographic proximity—are enforced directly by MySQL 8.0 stored procedures and triggers.", bold_prefix="Architecture Principle:")

doc.add_paragraph("When a user accesses the dashboard, the system immediately presents real-time key performance indicators (KPIs) sourced directly from relational views:")
doc.add_image(IMG_NAV_HEADER, caption="Figure 1: RaktSutra Live Navigation Header with Database Connection and System KPIs", width_inches=6.0)

doc.add_bullet("Displays total voluntary blood donors active in the database (initially 42 seeded across districts).", "Registered Donors KPI:")
doc.add_bullet("Displays approved blood banks and storage centers with licensed cold storage (11 centers).", "Blood Centres KPI:")
doc.add_bullet("Active community donation camps scheduled with remaining seat capacities.", "Active Camps KPI:")
doc.add_bullet("Dynamic district shortage monitor. Automatically flashes red when any blood group has 0 units across all district centers (e.g. AB- in Jaipur).", "Critical Shortage Alert:")

# Table: Baseline metrics
headers = ["Component", "Database Table / View", "Current Baseline", "Role in System"]
rows = [
    ["Donors", "Donor", "42 Active Donors", "Maintains voluntary donor demographics, coordinates, & verification"],
    ["Blood Banks", "Organization", "11 Blood Centres, 6 Hospitals", "Certified storage facilities and emergency hospital hubs"],
    ["Units in Stock", "Blood_Unit", "180+ Inventory Units", "Individual barcodes, component types, collection & expiration dates"],
    ["Blood Camps", "Camp & Camp_Booking", "7 Scheduled Camps", "Mobile donation drives with real-time seat locks (FOR UPDATE)"],
    ["Medical Rules", "Eligibility_Question", "9 Screening Questions", "Disqualifications and 14 to 180 day medical deferrals"]
]
doc.add_table(headers, rows)

# 2. Detailed Page-by-Page Breakdown with Screenshots
doc.add_heading_1("2. Detailed Visual & Feature Walkthrough")

# Page 1: Emergency Blood Request Flow
doc.add_heading_2("Page / Tab 1: Emergency Blood Request & Donor Matching (Core Flow)")
doc.add_paragraph("This is the central operational interface of RaktSutra, connecting emergency patients with eligible donors in minutes while strictly protecting donor privacy.")
doc.add_image(IMG_EMERGENCY_REQ, caption="Figure 2: Emergency Blood Request Builder, Search Expander, and Contacted Queue", width_inches=6.0)

doc.add_paragraph("How this page works step-by-step:", bold_prefix="Step-by-Step Flow:")
doc.add_bullet("The requester inputs their 10-digit mobile number and clicks 'Send OTP'. Stored procedure sp_send_otp automatically invalidates any stale codes and issues a 6-digit verification code. The user confirms via 'Verify OTP' (calling sp_verify_otp).", "1. Requester Mobile & OTP Verification:")
doc.add_bullet("The requester selects patient blood group (e.g., O+), units needed (1-10), hospital, urgency level, and hours valid. When submitted, sp_create_request checks that the mobile number was verified within the last 15 minutes before creating an 'Open' request.", "2. Request Creation:")
doc.add_bullet("Clicking 'Notify Donors (Expand Radius)' triggers sp_expand_search. It evaluates nearby eligible donors at 25 km; if fewer than the target count are reached, it automatically widens to 50 km and 100 km.", "3. Widening Proximity Search:")
doc.add_bullet("Every contacted donor appears in the Contacted Donors Queue with distance and status ('Sent'). In this demonstration view, volunteer coordinators can simulate 'Accept' or 'Decline' actions via sp_respond_to_request.", "4. Real-time Response Queue:")
doc.add_bullet("To eliminate harassment and comply with medical privacy standards, donor phone numbers are encrypted/hidden during search. Only when the required units are accepted and the request status flips to 'Matched' does the database reveal phone numbers via the v_accepted_contacts view.", "5. Privacy-Protected Reveal:")

# Page 2: Donor Registration
doc.add_heading_2("Page / Tab 2: Donor Registration with Age Validation Triggers")
doc.add_paragraph("Enables new voluntary donors to sign up with demographic and contact details.")
doc.add_image(IMG_DONOR_REG, caption="Figure 3: Donor Registration Form enforcing database trigger trg_donor_age_check", width_inches=6.0)

doc.add_paragraph("How this page works:", bold_prefix="Mechanism & Database Enforcement:")
doc.add_bullet("Full name, DOB, gender, blood group, district, 10-digit Indian phone (validated via regex ^[6-9][0-9]{9}$), and latitude/longitude coordinates.", "Form Fields:")
doc.add_bullet("Before inserting, MySQL fires trigger trg_donor_age_check. It computes donor age as TIMESTAMPDIFF(YEAR, dob, CURDATE()). If under 18 or over 65, the database rolls back with 'Donor age must be between 18 and 65'. This prevents underage registration directly in the database.", "Medical Age Validation Trigger:")
doc.add_bullet("Upon valid insertion, sp_send_otp dispatches an activation code to confirm mobile ownership. Once verified, phone_verified flips to TRUE, permitting the donor to appear in emergency searches.", "Post-Registration Verification:")

# Page 3: Eligibility Self-Check
doc.add_heading_2("Page / Tab 3: Medical Eligibility Self-Check Questionnaire")
doc.add_paragraph("A 9-question pre-donation screening system preventing contaminated units and safeguarding donor health.")
doc.add_image(IMG_ELIGIBILITY, caption="Figure 4: Medical Eligibility Questionnaire evaluated by sp_evaluate_eligibility", width_inches=6.0)

doc.add_paragraph("How this page works:", bold_prefix="Screening Logic & Deferral Calculation:")
doc.add_bullet("Select any donor from the dropdown and answer the 9 questions (fever, recent donations within 3 months, body weight under 45kg, tattoos/piercings within 6 months, antibiotics, major surgery, pregnancy, hepatitis/HIV, and chronic heart disease/cancer).", "Questionnaire:")
doc.add_bullet("The backend checks that all 9 questions are answered; partial submissions are rejected.", "Integrity Validation:")
doc.add_bullet("Answers are stored in Eligibility_Answer and evaluated by sp_evaluate_eligibility. Permanent disqualifiers set donor status to 'Ineligible'. Temporary conditions (e.g. tattoos) compute a deferred_until date (180 days) and update next_eligible_date.", "Automated Deferral Engine:")

# Page 4: Find Blood Banks
doc.add_heading_2("Page / Tab 4: Find Compatible Blood Banks (Proximity Stock Search)")
doc.add_paragraph("Enables medical coordinators to search for nearby blood banks with available, unexpired compatible blood units.")
doc.add_image(IMG_FIND_BANKS, caption="Figure 5: Blood Bank Proximity Search using Haversine Geolocation Calculation", width_inches=6.0)

doc.add_paragraph("How this page works:", bold_prefix="Spatial Query Execution:")
doc.add_bullet("Select patient blood group, reference coordinates (hospital or district center), and radius slider (5 to 100 km).", "Input Controls:")
doc.add_bullet("Calls stored procedure sp_find_banks. It joins the Compatibility matrix table, filters for status='Available' and expires_on >= CURDATE(), and calculates real-world distance using the Haversine formula.", "Haversine Distance Matching:")
doc.add_bullet("Returns blood bank name, ownership type (Govt, Charitable, Private), contact phone number, calculated distance in km, and count of compatible units.", "Results Grid:")

# Page 5: Find Donors
doc.add_heading_2("Page / Tab 5: Find Compatible Donors (Privacy-Preserving Locator)")
doc.add_paragraph("Locates eligible voluntary donors for direct donation when hospital or blood bank stocks are depleted.")
doc.add_image(IMG_FIND_DONORS, caption="Figure 6: Compatible Donor Search with Anonymized Display", width_inches=6.0)

doc.add_paragraph("How this page works:", bold_prefix="Donor Eligibility & Privacy Rules:")
doc.add_bullet("Select required blood group, location coordinates, and search radius.", "Search Criteria:")
doc.add_bullet("The query filters for status='Active', phone_verified=TRUE, and enforces cooldown rules (90 days for men, 120 days for women) using next_eligible_date <= CURDATE().", "Eligibility Filtering:")
doc.add_bullet("Displays Donor ID, first name only (using SUBSTRING_INDEX(name, ' ', 1)), blood group, and distance. Phone numbers and home addresses are omitted to preserve donor privacy.", "Privacy Safeguard:")

# Page 6: Stock Matrix
doc.add_heading_2("Page / Tab 6: Blood Stock Inventory Matrix & Shortage Monitoring")
doc.add_paragraph("Provides regional health authorities with an aggregated overview of blood inventory across all centers.")
doc.add_image(IMG_STOCK_MATRIX, caption="Figure 7: 8-Column Blood Stock Pivot Matrix with Critical Shortage Notification", width_inches=6.0)

doc.add_paragraph("How this page works:", bold_prefix="Conditional Aggregation Matrix:")
doc.add_bullet("Pivots relational rows from Blood_Unit using SQL SUM(CASE WHEN blood_group = 'X' THEN units ELSE 0 END) for all 8 blood groups.", "8-Column Matrix:")
doc.add_bullet("Any cell with 0 units is highlighted in bold red.", "Zero-Stock Warning:")
doc.add_bullet("Identifies blood groups where total units across all banks in the district equal 0, generating a critical shortage banner (e.g. 'CRITICAL SHORTAGE in Jaipur: Zero units for AB-').", "District Shortage Alert:")

# Page 7: Camps & Booking
doc.add_heading_2("Page / Tab 7: Upcoming Donation Camps & Live Seat Reservation")
doc.add_paragraph("Coordinates community blood donation drives and prevents overbooking.")
doc.add_image(IMG_CAMPS, caption="Figure 8: Scheduled Camps Directory and Reservation Engine with Row Locks", width_inches=6.0)

doc.add_paragraph("How this page works:", bold_prefix="Concurrency-Safe Reservation:")
doc.add_bullet("Lists upcoming camps with dates, venues, organizers, total capacities, and seats left.", "Camp Directory:")
doc.add_bullet("Select a camp and enter a Donor ID to test sp_book_camp.", "Booking Form:")
doc.add_bullet("The procedure uses SELECT capacity FROM Camp WHERE camp_id = X FOR UPDATE. This row-level lock serializes concurrent bookings. If capacity is exhausted, the second user receives 'Camp is full'.", "Concurrency Protection:")
doc.add_bullet("Checks that the donor's next_eligible_date falls on or before the camp date. Donors within a cooldown period are rejected with 'Donor will not be eligible by camp date'.", "Pre-Camp Cooldown Check:")

# Page 8: Interactive SQL Console
doc.add_heading_2("Page / Tab 8: Interactive SQL Console & Database Security Guardrails")
doc.add_paragraph("A command terminal for testing database features, running benchmarks, and examining query plans.")
doc.add_image(IMG_SQL_CONSOLE, caption="Figure 9: SQL Console with Preset Queries and Safety Guardrails", width_inches=6.0)

doc.add_paragraph("How this page works:", bold_prefix="Benchmarking & Security Controls:")
doc.add_bullet("Includes 12 pre-configured queries from 03_queries.sql demonstrating triggers, views, and analytics.", "Preset Library:")
doc.add_bullet("Measures execution latency in milliseconds and formats tabular results dynamically.", "Execution Latency:")
doc.add_bullet("A regex filter blocks destructive operations (DROP DATABASE, DROP TABLE, TRUNCATE, ALTER TABLE) with HTTP 403 Forbidden to protect database integrity.", "Security Guardrail:")

# 3. Summary of Technical Architecture
doc.add_heading_1("3. Summary of Technical Architecture")
doc.add_paragraph("By coupling a relational database engine (MySQL 8.0) with an asynchronous web dashboard, RaktSutra ensures data integrity, auditability, and rapid emergency dispatch.")
doc.add_bullet("Medical rules (cooldowns, age bounds, compatibility) remain enforced at the database level regardless of client or interface.", "Integrity Guarantee:")
doc.add_bullet("ACID transactions with row-level locks prevent race conditions during camp bookings and request fulfillment.", "Concurrency Control:")
doc.add_bullet("Contact details remain hidden until both medical eligibility and emergency matching are fulfilled.", "Privacy Enforcement:")

doc.save()
print("Illustrated RaktSutra_Project_Documentation.docx generated successfully with all 9 screenshots embedded!")
